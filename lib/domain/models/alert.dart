import 'package:flutter/material.dart';

enum AlertCategory { irrigation, fertilization, phytosanitary, climate }

enum AlertSeverity { high, medium, info }

extension AlertCategoryX on AlertCategory {
  String get label => switch (this) {
    AlertCategory.irrigation => 'Riego',
    AlertCategory.fertilization => 'Fertilización',
    AlertCategory.phytosanitary => 'Fitosanitario',
    AlertCategory.climate => 'Clima',
  };
}

extension AlertSeverityX on AlertSeverity {
  String get label => switch (this) {
    AlertSeverity.high => 'Alta',
    AlertSeverity.medium => 'Media',
    AlertSeverity.info => 'Informativa',
  };
}

@immutable
class Alert {
  const Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.category,
    required this.severity,
    required this.cropTag,
    required this.iconCodePoint,
    this.cropId,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String description;
  final String timestamp;
  final AlertCategory category;
  final AlertSeverity severity;
  final String cropTag;
  final int iconCodePoint;
  final String? cropId;
  final bool isRead;

  static AlertCategory _categoryFromType(String type) {
    return switch (type.toUpperCase()) {
      'IRRIGATION' => AlertCategory.irrigation,
      'FERTILIZER' => AlertCategory.fertilization,
      'PHYTOSANITARY' => AlertCategory.phytosanitary,
      _ => AlertCategory.climate,
    };
  }

  static AlertSeverity _severityFromBackend(String severity) {
    return switch (severity.toUpperCase()) {
      'HIGH' => AlertSeverity.high,
      'MEDIUM' => AlertSeverity.medium,
      _ => AlertSeverity.info,
    };
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: (json['id'] as String? ?? ''),
      title: (json['title'] as String? ?? ''),
      description: (json['message'] as String? ?? ''),
      timestamp: (json['createdAt'] as String? ?? ''),
      category: _categoryFromType(json['type'] as String? ?? ''),
      severity: _severityFromBackend(json['severity'] as String? ?? ''),
      cropTag: (json['cropTag'] as String? ?? ''),
      iconCodePoint:
          (json['iconCode'] as num?)?.toInt() ?? Icons.notifications.codePoint,
      cropId: json['cropId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
