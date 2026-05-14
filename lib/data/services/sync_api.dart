import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/crop.dart';
import 'pending_decisions_local_dao.dart';

/// Respuesta del endpoint POST /api/sync/batch.
class SyncBatchResult {
  const SyncBatchResult({
    required this.status,
    required this.syncedCropIds,
    required this.syncedEventIds,
    required this.failedCropIds,
    required this.failedEventIds,
    required this.failedDecisionIds,
  });

  final String status;
  final List<String> syncedCropIds;
  final List<String> syncedEventIds;
  final List<String> failedCropIds;
  final List<String> failedEventIds;
  final List<String> failedDecisionIds;

  bool get isFullSuccess => status == 'OK';
  bool get isPartial => status == 'PARTIAL';
}

/// Envía la cola offline al backend en un único request.
class SyncApi {
  const SyncApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<SyncBatchResult> postBatch({
    List<Crop> crops = const [],
    List<Map<String, dynamic>> events = const [],
    List<PendingDecisionRecord> decisions = const [],
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/sync/batch',
        data: {
          'crops': crops.map((c) => c.toSyncJson()).toList(),
          'events': events,
          'decisions': decisions.map((d) => d.toSyncJson()).toList(),
        },
      );
      final data = response.data!;
      final syncedCrops = (data['syncedCrops'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final cropIds = syncedCrops
          .map((c) => c['id'] as String)
          .toList();
      final syncedEvents = (data['syncedEvents'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final eventIds = syncedEvents
          .map((e) => e['id'] as String)
          .toList();
      final failedCropIds = (data['failedCropIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();
      final failedEventIds = (data['failedEventIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();
      final failedDecisionIds = (data['failedDecisionIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();
      return SyncBatchResult(
        status: data['status'] as String,
        syncedCropIds: cropIds,
        syncedEventIds: eventIds,
        failedCropIds: failedCropIds,
        failedEventIds: failedEventIds,
        failedDecisionIds: failedDecisionIds,
      );
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
