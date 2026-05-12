import 'dart:math';

import '../../domain/models/crop_event.dart';
import '../services/crop_events_api.dart';
import '../services/crop_events_local_dao.dart';
import '../services/sync_api.dart';

class CropEventsRepository {
  const CropEventsRepository({
    required CropEventsApi api,
    required CropEventsLocalDao dao,
    required SyncApi syncApi,
  })  : _api = api,
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
  }) async {
    final event = CropEvent(
      id: _uuid(),
      cropId: cropId,
      eventType: eventType,
      occurredAt: DateTime.now(),
      notes: notes,
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

  Future<void> _refreshFromServer(String cropId) async {
    try {
      final remote = await _api.list(cropId);
      await _dao.upsertAll(remote);
    } catch (_) {}
  }

  /// Sube eventos guardados offline vía `POST /api/sync/batch` (después de cultivos).
  Future<void> syncPendingViaBatch() async {
    final unsynced = await _dao.listUnsynced();
    if (unsynced.isEmpty) return;
    final payload = unsynced.map((e) => e.toJson()).toList();
    final sentIds = unsynced.map((e) => e.id).toList();
    try {
      await _syncApi.postBatch(crops: const [], events: payload);
      await _dao.markEventsSynced(sentIds);
    } catch (_) {
      // Reintento en próximo ciclo del coordinador.
    }
  }

  static String _uuid() {
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
