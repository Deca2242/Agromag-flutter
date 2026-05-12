import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/crop.dart';

/// Respuesta del endpoint POST /api/sync/batch.
class SyncBatchResult {
  const SyncBatchResult({
    required this.status,
    required this.syncedCropIds,
    required this.syncedEventIds,
  });

  final String status;
  final List<String> syncedCropIds;
  final List<String> syncedEventIds;
}

/// Envía la cola offline al backend en un único request.
class SyncApi {
  const SyncApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<SyncBatchResult> postBatch({
    List<Crop> crops = const [],
    List<Map<String, dynamic>> events = const [],
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/sync/batch',
        data: {
          'crops': crops.map((c) => c.toSyncJson()).toList(),
          'events': events,
          'decisions': <dynamic>[],
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
      return SyncBatchResult(
        status: data['status'] as String,
        syncedCropIds: cropIds,
        syncedEventIds: eventIds,
      );
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
