import 'dart:math';

import '../../core/network/api_exceptions.dart';
import '../services/crops_api.dart';
import '../services/crops_local_dao.dart';
import '../services/sync_api.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/crop_type.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/sync_status.dart';

class SyncReport {
  const SyncReport({required this.synced, required this.failed});
  final int synced;
  final int failed;
}

/// Orquesta cultivos entre SQLite local y el backend Spring.
///
/// Estrategia offline-first:
///   - Crear  → SQLite con PENDING + is_new_local=1, luego intenta sync batch.
///   - Editar → SQLite con PENDING + is_new_local=0, luego PUT individual.
///   - Borrar → pending_delete=1 en local, DELETE individual al reconectar.
///   - Leer   → SQLite siempre; refresca desde API si hay red.
class CropsRepository {
  const CropsRepository({
    required CropsLocalDao dao,
    required CropsApi api,
    required SyncApi syncApi,
  })  : _dao = dao,
        _api = api,
        _syncApi = syncApi;

  final CropsLocalDao _dao;
  final CropsApi _api;
  final SyncApi _syncApi;

  /// Persiste el cultivo localmente con PENDING y dispara sync en background.
  Future<Crop> createCropOffline({
    required String profileId,
    required CropType cropType,
    required double areaHectares,
    required Municipality municipality,
    required DateTime sownDate,
  }) async {
    final id = _generateUuid();
    final now = DateTime.now();
    final crop = Crop(
      id: id,
      cropType: cropType,
      areaHectares: areaHectares,
      municipality: municipality,
      sownDate: sownDate,
      syncStatus: SyncStatus.PENDING,
      createdAt: now,
    );
    await _dao.insert(crop, profileId: profileId);
    return crop;
  }

  /// Edita un cultivo: persiste localmente con PENDING y sube al servidor.
  Future<Crop> updateCrop(Crop crop, {required String profileId}) async {
    final updated = crop.copyWith(syncStatus: SyncStatus.PENDING);
    await _dao.updateCrop(updated);
    try {
      final serverCrop = await _api.update(crop);
      await _dao.markSynced([serverCrop.id]);
      return serverCrop.copyWith(syncStatus: SyncStatus.SYNCED);
    } on NetworkException {
      return updated;
    }
  }

  /// Elimina un cultivo. Online: DELETE en servidor + local. Offline: pending_delete.
  Future<void> deleteCrop(String id) async {
    try {
      await _api.delete(id);
      await _dao.deleteLocal(id);
    } on NetworkException {
      await _dao.markDeletedPending(id);
    }
  }

  /// Retorna cultivos desde SQLite; si hay red también hace refresh en background.
  ///
  /// Si el caché local está vacío, espera un primer [refreshFromServer] para que
  /// los cultivos del servidor aparezcan al iniciar sesión sin otra acción.
  Future<List<Crop>> getCrops({required String profileId}) async {
    final local = await _dao.listByProfile(profileId);
    if (local.isEmpty) {
      await refreshFromServer(profileId: profileId);
      return _dao.listByProfile(profileId);
    }
    refreshFromServer(profileId: profileId).ignore();
    return local;
  }

  /// Descarga los cultivos del servidor y los upserta en SQLite.
  Future<void> refreshFromServer({required String profileId}) async {
    try {
      final remote = await _api.list();
      await _dao.upsertFromServer(remote, profileId: profileId);
    } catch (_) {
      // Sin red: silencioso, los datos locales siguen siendo válidos.
    }
  }

  /// Envía nuevos cultivos (is_new_local=1) al backend mediante sync/batch,
  /// y sube ediciones pendientes (is_new_local=0) vía PUT individual.
  Future<SyncReport> syncPending({required String profileId}) async {
    int synced = 0;
    int failed = 0;

    // 1. Nuevos cultivos → batch
    final newCrops = await _dao.newLocalPendingByProfile(profileId);
    if (newCrops.isNotEmpty) {
      try {
        final result = await _syncApi.postBatch(crops: newCrops);
        final syncedIds = result.syncedCropIds;
        final allIds = newCrops.map((c) => c.id).toList();
        final toMark = {...syncedIds, ...allIds}.toList();
        await _dao.markSynced(toMark);
        synced += toMark.length;
      } catch (_) {
        await _dao.markError(newCrops.map((c) => c.id).toList());
        failed += newCrops.length;
      }
    }

    // 2. Ediciones pendientes → PUT individual
    final edited = await _dao.editedPendingByProfile(profileId);
    for (final crop in edited) {
      try {
        final serverCrop = await _api.update(crop);
        await _dao.markSynced([serverCrop.id]);
        synced++;
      } catch (_) {
        failed++;
      }
    }

    // 3. Pending deletes → DELETE individual
    final toDelete = await _dao.pendingDeletesByProfile(profileId);
    for (final crop in toDelete) {
      try {
        await _api.delete(crop.id);
        await _dao.deleteLocal(crop.id);
        synced++;
      } catch (_) {
        failed++;
      }
    }

    return SyncReport(synced: synced, failed: failed);
  }

  /// Reintenta cultivos en estado ERROR.
  Future<SyncReport> retryErrors({required String profileId}) async {
    final errors = await _dao.pendingByProfile(profileId);
    if (errors.isEmpty) return const SyncReport(synced: 0, failed: 0);
    return syncPending(profileId: profileId);
  }

  Future<Crop?> getById(String id) => _dao.findById(id);

  /// Counts crops with PENDING status (for badge).
  Future<int> pendingCount({required String profileId}) async {
    final pending = await _dao.pendingByProfile(profileId);
    final deletes = await _dao.pendingDeletesByProfile(profileId);
    return pending.length + deletes.length;
  }

  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
