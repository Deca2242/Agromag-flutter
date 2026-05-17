import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/alert.dart';

class AlertsApi {
  const AlertsApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<AlertPage> getAlerts({
    String? type,
    int page = 0,
    int size = 20,
  }) async {
    final queryParameters = <String, dynamic>{'page': page, 'size': size};
    if (type != null) {
      queryParameters['type'] = type;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/alerts',
        queryParameters: queryParameters,
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

  Future<void> markAsRead(String alertId) async {
    try {
      await _dio.patch('/api/alerts/$alertId/read');
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

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

  Future<void> deleteAlert(String alertId) async {
    try {
      await _dio.delete('/api/alerts/$alertId');
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

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

@immutable
class AlertUnreadCount {
  const AlertUnreadCount({required this.total, required this.high});

  final int total;
  final int high;
}
