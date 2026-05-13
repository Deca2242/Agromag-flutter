import 'package:flutter/material.dart';

enum CropStatus { active, monitoring, harvested }

extension CropStatusX on CropStatus {
  String get label => switch (this) {
        CropStatus.active => 'Activo',
        CropStatus.monitoring => 'Seguimiento',
        CropStatus.harvested => 'Cosechado',
      };
}

@immutable
class Crop {
  const Crop({
    required this.id,
    required this.name,
    required this.type,
    required this.lot,
    required this.stage,
    required this.areaHa,
    required this.plantingDensity,
    required this.plantedAt,
    required this.status,
    required this.iconCodePoint,
    this.iconBackground = const Color(0xFFE8F5E9),
    this.iconForeground = const Color(0xFF1F7A3A),
    this.imageEmoji = '🌱',
  });

  final String id;
  final String name;
  final String type;
  final String lot;
  final String stage;
  final double areaHa;
  final double plantingDensity;
  final DateTime plantedAt;
  final CropStatus status;
  final int iconCodePoint;
  final Color iconBackground;
  final Color iconForeground;
  final String imageEmoji;
}
