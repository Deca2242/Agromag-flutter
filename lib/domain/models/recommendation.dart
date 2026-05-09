import 'package:flutter/material.dart';

enum RecommendationLevel { moderate, alert, optimal }

extension RecommendationLevelX on RecommendationLevel {
  String get label => switch (this) {
        RecommendationLevel.moderate => 'MODERADO',
        RecommendationLevel.alert => 'ALERTA',
        RecommendationLevel.optimal => 'ÓPTIMO',
      };
}

@immutable
class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    required this.iconCodePoint,
    required this.accentColor,
  });

  final String id;
  final String title;
  final String body;
  final RecommendationLevel level;
  final int iconCodePoint;
  final Color accentColor;
}
