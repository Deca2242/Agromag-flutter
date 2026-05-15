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
  });

  final String id;
  final String title;
  final String description;
  final String timestamp;
  final AlertCategory category;
  final AlertSeverity severity;
  final String cropTag;
  final int iconCodePoint;
}
