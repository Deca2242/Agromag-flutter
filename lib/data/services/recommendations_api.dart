import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/recommendation.dart';
import '../../domain/models/recommendation_page.dart';

/// Endpoints de recomendaciones del backend Spring.
class RecommendationsApi {
  const RecommendationsApi();

  Dio get _dio => ApiClient.instance.dio;

  /// [followedFilter]: `any` | `pending` | `decided`
  Future<RecommendationPage> listByCropPaged(
    String cropId, {
    String followedFilter = 'any',
    int page = 0,
    int size = 10,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/crops/$cropId/recommendations',
        queryParameters: <String, dynamic>{
          'followed': followedFilter,
          'page': page,
          'size': size,
        },
      );
      return RecommendationPage.fromSpringJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Pendientes de decisión (compatibilidad con vistas que esperan lista).
  Future<List<Recommendation>> listByCrop(String cropId) async {
    final page = await listByCropPaged(
      cropId,
      followedFilter: 'pending',
      page: 0,
      size: 20,
    );
    return page.items;
  }

  Future<Recommendation> generateIrrigation(String cropId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/crops/$cropId/recommendations/irrigation',
      );
      return Recommendation.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<Recommendation> generateFertilizer(String cropId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/crops/$cropId/recommendations/fertilizer',
      );
      return Recommendation.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<Recommendation> generatePhytosanitary(String cropId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/crops/$cropId/recommendations/phytosanitary',
      );
      return Recommendation.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Marca si el productor siguió la recomendación (`true`) o no (`false`).
  Future<void> submitDecision({
    required String recommendationId,
    required bool followed,
  }) async {
    try {
      await _dio.patch<void>(
        '/api/recommendations/decision',
        data: {
          'recommendationId': recommendationId,
          'followed': followed,
        },
      );
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<void> resetDecision(String recommendationId) async {
    try {
      await _dio.delete<void>(
        '/api/recommendations/$recommendationId/decision',
      );
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
