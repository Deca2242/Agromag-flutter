import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/crop_event.dart';

/// Endpoints de eventos de cultivo en el backend Spring.
class CropEventsApi {
  const CropEventsApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<List<CropEvent>> list(String cropId) async {
    try {
      final response = await _dio
          .get<List<dynamic>>('/api/crops/$cropId/events');
      final data = response.data ?? [];
      return data
          .cast<Map<String, dynamic>>()
          .map(CropEvent.fromJson)
          .toList();
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<CropEvent> create(CropEvent event) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/crops/${event.cropId}/events',
        data: event.toJson(),
      );
      return CropEvent.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
