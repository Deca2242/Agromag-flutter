import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum RecommendationLevel { moderate, alert, optimal }

extension RecommendationLevelX on RecommendationLevel {
  String get label => switch (this) {
    RecommendationLevel.moderate => 'MODERADO',
    RecommendationLevel.alert => 'ALERTA',
    RecommendationLevel.optimal => 'ÓPTIMO',
  };
}

enum RecommendationType { irrigation, fertilizer, phytosanitary }

@immutable
class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    required this.iconCodePoint,
    required this.accentColor,
    this.cropId,
    this.cropTypeCode,
    this.type,
    this.generatedAt,
    this.followed,
  });

  final String id;
  final String title;
  final String body;
  final RecommendationLevel level;
  final int iconCodePoint;
  final Color accentColor;
  final String? cropId;

  /// Código del enum backend (`BANANO`, …) para etiqueta si no hay `Crop` local.
  final String? cropTypeCode;
  final RecommendationType? type;
  final DateTime? generatedAt;

  /// `null` = pendiente de decisión; `true` = realizada; `false` = rechazada.
  final bool? followed;

  static RecommendationLevel _levelFromString(String? s) {
    return switch ((s ?? '').toUpperCase()) {
      'HIGH' => RecommendationLevel.alert,
      'MEDIUM' => RecommendationLevel.moderate,
      _ => RecommendationLevel.optimal,
    };
  }

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? '').toUpperCase();
    final type = switch (typeStr) {
      'IRRIGATION' => RecommendationType.irrigation,
      'FERTILIZER' => RecommendationType.fertilizer,
      'PHYTOSANITARY' => RecommendationType.phytosanitary,
      _ => RecommendationType.irrigation,
    };
    final level = _levelFromString(json['level'] as String?);
    final (title, icon, color) = switch (type) {
      RecommendationType.irrigation => (
        'Riego',
        Icons.water_drop_outlined.codePoint,
        AppColors.infoBlue,
      ),
      RecommendationType.fertilizer => (
        'Fertilización',
        Icons.eco_outlined.codePoint,
        AppColors.warningBrown,
      ),
      RecommendationType.phytosanitary => (
        'Fitosanitario',
        Icons.bug_report_outlined.codePoint,
        AppColors.alertRedStrong,
      ),
    };
    final followedRaw = json['followed'];
    bool? followed;
    if (followedRaw is bool) {
      followed = followedRaw;
    }

    return Recommendation(
      id: (json['id'] as String? ?? ''),
      title: title,
      body: (json['message'] as String? ?? ''),
      level: level,
      iconCodePoint: icon,
      accentColor: color,
      cropId: json['cropId'] as String?,
      cropTypeCode: json['cropType'] as String?,
      type: type,
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String)
          : null,
      followed: followed,
    );
  }
}
