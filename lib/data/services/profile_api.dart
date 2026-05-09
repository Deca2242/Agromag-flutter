import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/profile.dart';

/// Accede a los endpoints del backend Spring relacionados con el perfil.
///
/// Endpoints:
///   GET /api/profile  — autoprovisiona la fila si no existe.
///   PUT /api/profile  — actualiza fullName y municipality.
class ProfileApi {
  const ProfileApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<Profile> getProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/profile');
      return Profile.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Future<Profile> updateProfile({
    required String fullName,
    required Municipality municipality,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/profile',
        data: {
          'fullName': fullName,
          'municipality': municipality.name,
        },
      );
      return Profile.fromJson(response.data!);
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
