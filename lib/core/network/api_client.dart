import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'api_exceptions.dart';

/// Cliente HTTP Dio preconfigurado para el backend Spring.
///
/// Añade automáticamente el Bearer token de Supabase y maneja refresh en 401.
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(_dio));
    _dio.interceptors.add(_ErrorInterceptor());
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  Dio get dio => _dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        final newToken = refreshed.session?.accessToken;
        if (newToken != null) {
          final opts = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(opts);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // refresh fallido → deja pasar el error 401
      }
    }
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;

    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException(),
          type: DioExceptionType.unknown,
        ),
      );
      return;
    }

    final mapped = switch (statusCode) {
      401 => const UnauthorizedException(),
      404 => const NotFoundException(),
      400 || 422 => ValidationException(
        _extractMessage(err.response?.data) ?? 'Datos inválidos.',
      ),
      _ => const ServerException(),
    };

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: mapped,
        type: err.type,
      ),
    );
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ?? data['error'] as String?;
    }
    return null;
  }
}
