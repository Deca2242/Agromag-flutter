import 'package:flutter/material.dart';

import '../../core/errors/error_handling.dart';
import '../../core/theme/app_colors.dart';
import 'crop.dart';
import 'offline_recommendation_result.dart';

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
    this.source,
  });

  final String id;
  final String title;
  final String body;
  final RecommendationLevel level;
  final int iconCodePoint;
  final Color accentColor;
  final String? cropId;

  // Código del enum backend (`BANANO`, …) para etiqueta si no hay `Crop` local.
  final String? cropTypeCode;
  final RecommendationType? type;
  final DateTime? generatedAt;

  // `null` = pendiente de decisión; `true` = realizada; `false` = rechazada.
  final bool? followed;

  // Origen de la recomendación: `RULE`, `AI`, `RULE_LOCAL` (offline) o null (legado).
  final String? source;

  // Verdadero si la recomendación fue generada localmente sin conexión.
  bool get isOffline => source == 'RULE_LOCAL';

  static RecommendationLevel _levelFromString(String? s) {
    return switch ((s ?? '').toUpperCase()) {
      'HIGH' => RecommendationLevel.alert,
      'MEDIUM' => RecommendationLevel.moderate,
      _ => RecommendationLevel.optimal,
    };
  }

  // Mapea un string de tipo a RecommendationType.
  // Retorna null para strings desconocidos para que el caller pueda
  // decidir cómo manejarlo (filtrar, loguear, mostrar genérico).
  static RecommendationType? _typeFromString(String? s) {
    return switch ((s ?? '').toUpperCase()) {
      'IRRIGATION' => RecommendationType.irrigation,
      'FERTILIZER' => RecommendationType.fertilizer,
      'PHYTOSANITARY' => RecommendationType.phytosanitary,
      _ => null,
    };
  }

  // Metadatos visuales (título, ícono, color) por tipo de recomendación.
  // Cuando type es null devuelve visuals genéricos.
  static (String, int, Color) _visualsForType(RecommendationType? type) {
    return switch (type) {
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
      null => (
        'Recomendación',
        Icons.tips_and_updates_outlined.codePoint,
        AppColors.textSecondary,
      ),
    };
  }

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    final type = _typeFromString(typeStr);
    if (type == null && typeStr != null && typeStr.isNotEmpty) {
      AppErrorHandling.report(
        'recommendation_unknown_type_json',
        'Unknown recommendation type: $typeStr',
        StackTrace.current,
      );
    }
    final level = _levelFromString(json['level'] as String?);
    final (title, icon, color) = _visualsForType(type);
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
      source: json['source'] as String?,
    );
  }

  // Construye una recomendación desde una fila de la tabla `recommendations_cache` (SQLite).
  factory Recommendation.fromLocalRow(Map<String, dynamic> row) {
    final typeStr = row['type'] as String?;
    final type = _typeFromString(typeStr);
    if (type == null && typeStr != null && typeStr.isNotEmpty) {
      debugPrint('[Recommendation] unknown type in local row: $typeStr id=${row['id']}');
    }
    final level = _levelFromString(row['level'] as String?);
    final (title, icon, color) = _visualsForType(type);

    final followedRaw = row['followed'];
    bool? followed;
    if (followedRaw is int) {
      followed = followedRaw == 1;
    }

    return Recommendation(
      id: row['id'] as String,
      title: title,
      body: row['message'] as String? ?? '',
      level: level,
      iconCodePoint: icon,
      accentColor: color,
      cropId: row['crop_id'] as String?,
      cropTypeCode: row['crop_type'] as String?,
      type: type,
      generatedAt: row['generated_at'] != null
          ? DateTime.tryParse(row['generated_at'] as String)
          : null,
      followed: followed,
      source: row['source'] as String?,
    );
  }

  // Construye una recomendación desde el resultado del motor de reglas offline.
  factory Recommendation.fromOfflineResult(
    OfflineRecommendationResult result,
    Crop crop,
    String id,
  ) {
    final (title, icon, color) = _visualsForType(result.type);
    return Recommendation(
      id: id,
      title: title,
      body: result.message,
      level: result.level,
      iconCodePoint: icon,
      accentColor: color,
      cropId: crop.id,
      cropTypeCode: crop.cropType.name,
      type: result.type,
      generatedAt: result.generatedAt,
      followed: null,
      source: 'RULE_LOCAL',
    );
  }
}
