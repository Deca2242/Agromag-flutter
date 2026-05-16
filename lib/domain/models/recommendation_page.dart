import 'package:flutter/foundation.dart';

import 'recommendation.dart';

/// Respuesta paginada Spring `Page<RecommendationResponse>`.
@immutable
class RecommendationPage {
  const RecommendationPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.pageNumber,
    required this.pageSize,
  });

  final List<Recommendation> items;
  final int totalElements;
  final int totalPages;
  final int pageNumber;
  final int pageSize;

  bool get hasNextPage => pageNumber + 1 < totalPages;

  factory RecommendationPage.fromSpringJson(Map<String, dynamic> json) {
    final raw = json['content'];
    final list = raw is List<dynamic>
        ? raw.cast<Map<String, dynamic>>().map(Recommendation.fromJson).toList()
        : <Recommendation>[];
    int n(dynamic v, int d) {
      if (v == null) return d;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return d;
    }

    return RecommendationPage(
      items: list,
      totalElements: n(json['totalElements'], list.length),
      totalPages: n(json['totalPages'], list.isEmpty ? 0 : 1),
      pageNumber: n(json['number'], 0),
      pageSize: n(json['size'], list.length),
    );
  }
}
