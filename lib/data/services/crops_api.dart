import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/crop.dart';

/// Endpoints del backend Spring para cultivos.
///
///   GET    /api/crops          — lista de cultivos del usuario.
///   PUT    /api/crops/{id}     — actualiza un cultivo.
///   DELETE /api/crops/{id}     — elimina un cultivo.
class CropsApi {
  const CropsApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<List<Crop>> list() async {
    try {
      final response = await _dio.get<List<dynamic>>('/api/crops');
      final data = response.data ?? [];
      return data.cast<Map<String, dynamic>>().map(Crop.fromJson).toList();
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<Crop> update(Crop crop) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/crops/${crop.id}',
        data: crop.toSyncJson(),
      );
      return Crop.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/api/crops/$id');
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
