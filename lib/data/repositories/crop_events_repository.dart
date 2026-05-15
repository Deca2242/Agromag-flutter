import 'dart:math';

import '../../core/errors/error_handling.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/crop_event.dart';
import '../services/crop_events_api.dart';
import '../services/crop_events_local_dao.dart';
import '../services/sync_api.dart';

class CropEventsRepository {
  const CropEventsRepository({
    required CropEventsApi api,
    required CropEventsLocalDao dao,
    required SyncApi syncApi,
  }) : _api = api,
       _dao = dao,
       _syncApi = syncApi;

  final CropEventsApi _api;
  final CropEventsLocalDao _dao;
  final SyncApi _syncApi;

  /// Returns events from SQLite and refreshes from server in background.
  Future<List<CropEvent>> getEvents(String cropId) async {
    final local = await _dao.listByCrop(cropId);
    _refreshFromServer(cropId).ignore();
    return local;
  }

  Future<CropEvent> createEvent({
    required String cropId,
    required EventType eventType,
    String? notes,
    double? quantity,
    String? unit,
  }) async {
    final event = CropEvent(
      id: _uuid(),
      cropId: cropId,
      eventType: eventType,
      occurredAt: DateTime.now(),
      notes: notes,
      quantity: quantity,
      unit: unit,
      synced: false,
    );
    await _dao.upsert(event);
    try {
      final serverEvent = await _api.create(event);
      await _dao.upsert(serverEvent);
      return serverEvent;
    } catch (_) {
      return event;
    }
  }

  Future<void> deleteEvent(String id) async {
    final localEvent = await _dao.findById(id);
    if (localEvent == null) return;
    try {
      await _api.delete(localEvent.cropId, id);
      await _dao.deleteLocal(id);
    } on NetworkException {
      await _dao.markDeletePending(id);
    }
  }

  Future<void> _refreshFromServer(String cropId) async {
    try {
      final remote = await _api.list(cropId);
      await _dao.upsertAll(remote);
    } on NotFoundException {
      await _dao.markCropDeletedPending(cropId);
    } catch (error, stackTrace) {
      AppErrorHandling.report(
        'crop_events_refresh_failed cropId=$cropId',
        error,
        stackTrace,
      );
    }
  }

  /// Descarga eventos de todos los cultivos indicados desde el servidor.
  /// Si un cultivo fue eliminado en el servidor (404), lo marca para borrado local.
  Future<bool> refreshAllFromServer(Iterable<String> cropIds) async {
    var allOk = true;
    for (final cropId in cropIds) {
      try {
        final remote = await _api.list(cropId);
        await _dao.upsertAll(remote);
      } on NotFoundException {
        await _dao.markCropDeletedPending(cropId);
      } catch (error, stackTrace) {
        allOk = false;
        AppErrorHandling.report(
          'crop_events_refresh_failed cropId=$cropId',
          error,
          stackTrace,
        );
      }
    }
    return allOk;
  }

  /// Sube eventos guardados offline vía `POST /api/sync/batch` (después de cultivos).
  ///
  /// Retorna `false` si había pendientes y falló el envío.
  Future<bool> syncPendingViaBatch() async {
    final unsynced = await _dao.listUnsynced();
    if (unsynced.isEmpty) return true;
    final payload = unsynced.map((e) => e.toJson()).toList();
    final sentIds = unsynced.map((e) => e.id).toList();
    try {
      final result = await _syncApi.postBatch(crops: const [], events: payload);
      final confirmedIds = result.syncedEventIds.toSet();
      final syncedIds = sentIds.where(confirmedIds.contains).toList();
      if (syncedIds.isNotEmpty) {
        await _dao.markEventsSynced(syncedIds);
      }
      final failedIds = result.failedEventIds;
      final toMarkError = sentIds
          .where((id) => !confirmedIds.contains(id) || failedIds.contains(id))
          .toList();
      if (toMarkError.isNotEmpty) {
        await _dao.markEventsError(toMarkError);
      }
      return true;
    } catch (error, stackTrace) {
      AppErrorHandling.report(
        'crop_events_batch_sync_failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  /// Sincroniza eliminaciones pendientes de eventos.
  Future<bool> syncPendingDeletes() async {
    final pendingDeletes = await _dao.listPendingDeletes();
    if (pendingDeletes.isEmpty) return true;

    var allOk = true;
    for (final event in pendingDeletes) {
      try {
        await _api.delete(event.cropId, event.id);
        await _dao.deleteLocal(event.id);
      } catch (error, stackTrace) {
        allOk = false;
        AppErrorHandling.report(
          'crop_event_delete_sync_failed eventId=${event.id}',
          error,
          stackTrace,
        );
      }
    }
    return allOk;
  }

  Future<int> countUnsyncedEvents() => _dao.countUnsynced();

  Future<int> countPendingDeletes() => _dao.countPendingDeletes();

  static String _uuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
