import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/alert.dart';

/// Endpoints del backend para alertas automaticas.
///
///   GET    /api/alerts              — lista de alertas del usuario.
///   GET    /api/alerts/unread/count — conteo de alertas no leidas.
///   PATCH  /api/alerts/{id}/read    — marcar alerta como leida.
///   DELETE /api/alerts/{id}         — eliminar una alerta.
///   DELETE /api/alerts/read         — eliminar todas las alertas leidas.
class AlertsApi {
  const AlertsApi();

  Dio get _dio => ApiClient.instance.dio;

  /// Retorna alertas paginadas del usuario. Si [type] se especifica, filtra por tipo.
  Future<AlertPage> getAlerts({
    String? type,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/alerts',
        queryParameters: {
          if (type != null) 'type': type,
          'page': page,
          'size': size,
        },
      );
      final data = response.data!;
      final content = (data['content'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Alert.fromJson)
          .toList();
      return AlertPage(
        items: content,
        pageNumber: data['number'] as int,
        pageSize: data['size'] as int,
        totalElements: data['totalElements'] as int,
        totalPages: data['totalPages'] as int,
      );
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Retorna conteo de alertas no leidas (MEDIUM + HIGH).
  Future<AlertUnreadCount> getUnreadCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/alerts/unread/count',
      );
      final data = response.data!;
      return AlertUnreadCount(
        total: (data['total'] as num).toInt(),
        high: (data['high'] as num).toInt(),
      );
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Marca una alerta como leida.
  Future<void> markAsRead(String alertId) async {
    try {
      await _dio.patch('/api/alerts/$alertId/read');
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Marca todas las alertas no leidas como leidas.
  Future<int> markAllAsRead() async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/alerts/read-all',
      );
      final data = response.data!;
      return (data['updated'] as num).toInt();
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Elimina una alerta especifica.
  Future<void> deleteAlert(String alertId) async {
    try {
      await _dio.delete('/api/alerts/$alertId');
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  /// Elimina todas las alertas ya leidas.
  Future<int> deleteAllRead() async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/api/alerts/read',
      );
      final data = response.data!;
      return (data['deleted'] as num).toInt();
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}

/// Pagina de alertas (respuesta paginada del backend).
@immutable
class AlertPage {
  const AlertPage({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalElements,
    required this.totalPages,
  });

  final List<Alert> items;
  final int pageNumber;
  final int pageSize;
  final int totalElements;
  final int totalPages;

  bool get hasNextPage => pageNumber < totalPages - 1;
}

/// Conteo de alertas no leidas.
@immutable
class AlertUnreadCount {
  const AlertUnreadCount({required this.total, required this.high});

  final int total;
  final int high;
}
