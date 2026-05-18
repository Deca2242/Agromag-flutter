import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/error_handling.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/utils/uuid_generator.dart';
import '../services/crop_sync_conflict.dart';
import '../services/crops_api.dart';
import '../services/crops_local_dao.dart';
import '../services/pending_decisions_local_dao.dart';
import '../services/recommendations_local_dao.dart';
import '../services/sync_api.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/crop_type.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/sync_status.dart';

@immutable
class SyncReport {
  const SyncReport({required this.synced, required this.failed});
  final int synced;
  final int failed;
}

@immutable
class PullCropsResult {
  const PullCropsResult({required this.success, required this.conflicts});
  final bool success;
  final List<CropSyncConflict> conflicts;
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
    required RecommendationsLocalDao recommendationsDao,
    required PendingDecisionsLocalDao decisionsDao,
  }) : _dao = dao,
       _api = api,
       _syncApi = syncApi,
       _recommendationsDao = recommendationsDao,
       _decisionsDao = decisionsDao;

  final CropsLocalDao _dao;
  final CropsApi _api;
  final SyncApi _syncApi;
  final RecommendationsLocalDao _recommendationsDao;
  final PendingDecisionsLocalDao _decisionsDao;

  /// Persiste el cultivo localmente con PENDING y dispara sync en background.
  Future<Crop> createCropOffline({
    required String profileId,
    required CropType cropType,
    required double areaHectares,
    required Municipality municipality,
    required DateTime sownDate,
  }) async {
    final id = generateUuid();
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
    await _dao.markDeletedPending(id);
    try {
      await _api.delete(id);
      await _deleteCropLocalDataCascade(id);
    } on NotFoundException {
      await _deleteCropLocalDataCascade(id);
    } on NetworkException {
      // Se mantiene oculto localmente y se reintentará al reconectar.
    } catch (_) {
      await _dao.markError([id]);
    }
  }

  // Elimina todos los datos locales asociados a un cultivo:
  // decisiones pendientes, cache de recomendaciones y la fila del cultivo.
  Future<void> _deleteCropLocalDataCascade(String cropId) async {
    final recs = await _recommendationsDao.listByCrop(cropId);
    final recIds = recs.map((r) => r.id).toList();
    await _decisionsDao.deleteByRecommendationIds(recIds);
    await _recommendationsDao.deleteByCrop(cropId);
    await _dao.deleteLocal(cropId);
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
    unawaited(refreshFromServer(profileId: profileId));
    return local;
  }

  /// Descarga los cultivos del servidor y los upserta en SQLite.
  ///
  /// Retorna [PullCropsResult] con éxito y lista de conflictos detectados.
  Future<PullCropsResult> pullCropsFromServer({
    required String profileId,
  }) async {
    try {
      final remote = await _api.list();
      final conflicts = await _dao.upsertFromServer(
        remote,
        profileId: profileId,
      );
      return PullCropsResult(success: true, conflicts: conflicts);
    } catch (error, stackTrace) {
      AppErrorHandling.report(
        'crops_refresh_from_server_failed profileId=$profileId',
        error,
        stackTrace,
      );
      return PullCropsResult(success: false, conflicts: const []);
    }
  }

  /// Igual que [pullCropsFromServer] pero ignora el resultado (refresh en background).
  Future<void> refreshFromServer({required String profileId}) async {
    await pullCropsFromServer(profileId: profileId);
  }

  /// IDs de cultivos locales no marcados para borrar (para pull de eventos).
  Future<List<String>> listLocalCropIds({required String profileId}) async {
    final crops = await _dao.listByProfile(profileId);
    return crops.map((c) => c.id).toList();
  }

  /// Envía nuevos cultivos (is_new_local=1) al backend mediante sync/batch,
  /// y sube ediciones pendientes (is_new_local=0) vía PUT individual.
  ///
  /// Incluye cultivos en `ERROR` para reintentar subidas fallidas.
  Future<SyncReport> syncPending({required String profileId}) async {
    int synced = 0;
    int failed = 0;

    // 1. Nuevos cultivos (PENDING + ERROR) → batch
    final newCrops = _unionCropsById(
      await _dao.newLocalPendingByProfile(profileId),
      await _dao.newLocalErrorByProfile(profileId),
    );
    if (newCrops.isNotEmpty) {
      try {
        final result = await _syncApi.postBatch(crops: newCrops);
        final confirmedIds = result.syncedCropIds;
        if (confirmedIds.isNotEmpty) {
          await _dao.markSynced(confirmedIds);
          synced += confirmedIds.length;
        }
        final serverFailedIds = result.failedCropIds;
        final unconfirmed = newCrops
            .where((c) => !confirmedIds.contains(c.id))
            .map((c) => c.id)
            .toList();
        final toMarkError = {...unconfirmed, ...serverFailedIds}.toList();
        if (toMarkError.isNotEmpty) {
          await _dao.markError(toMarkError);
          failed += toMarkError.length;
        }
      } catch (_) {
        await _dao.markError(newCrops.map((c) => c.id).toList());
        failed += newCrops.length;
      }
    }

    // 2. Ediciones pendientes (PENDING + ERROR) → PUT individual
    final edited = _unionCropsById(
      await _dao.editedPendingByProfile(profileId),
      await _dao.editedErrorByProfile(profileId),
    );
    final editedFailedIds = <String>[];
    for (final crop in edited) {
      try {
        final serverCrop = await _api.update(crop);
        await _dao.markSynced([serverCrop.id]);
        synced++;
      } catch (_) {
        failed++;
        editedFailedIds.add(crop.id);
      }
    }
    if (editedFailedIds.isNotEmpty) {
      await _dao.markError(editedFailedIds);
    }

    // 3. Pending deletes → DELETE individual
    final toDelete = await _dao.pendingDeletesByProfile(profileId);
    for (final crop in toDelete) {
      try {
        await _api.delete(crop.id);
        await _deleteCropLocalDataCascade(crop.id);
        synced++;
      } on NotFoundException {
        await _deleteCropLocalDataCascade(crop.id);
        synced++;
      } on NetworkException {
        failed++;
      } catch (_) {
        await _dao.markError([crop.id]);
        failed++;
      }
    }

    return SyncReport(synced: synced, failed: failed);
  }

  /// Reintenta cultivos en estado ERROR (y el resto de pendientes).
  Future<SyncReport> retryErrors({required String profileId}) async {
    return syncPending(profileId: profileId);
  }

  Future<Crop?> getById(String id) => _dao.findById(id);

  /// Cultivos PENDING + ERROR sin borrado pendiente, más borrados pendientes (badge).
  Future<int> pendingCount({required String profileId}) async {
    final pending = await _dao.pendingByProfile(profileId);
    final errors = await _dao.countErrorByProfile(profileId);
    final deletes = await _dao.pendingDeletesByProfile(profileId);
    return pending.length + errors + deletes.length;
  }

  /// Une listas por `id` sin duplicados (prioriza el orden del primer iterable).
  static List<Crop> _unionCropsById(
    Iterable<Crop> first,
    Iterable<Crop> second,
  ) {
    final seen = <String>{};
    final out = <Crop>[];
    for (final c in first) {
      if (seen.add(c.id)) out.add(c);
    }
    for (final c in second) {
      if (seen.add(c.id)) out.add(c);
    }
    return out;
  }
}
