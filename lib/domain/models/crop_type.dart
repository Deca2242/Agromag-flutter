// ignore_for_file: constant_identifier_names
// Los nombres coinciden con el enum Java del backend (SCREAMING_SNAKE_CASE).

import 'package:flutter/material.dart';

/// Espejo del enum `CropType` del backend Spring.
enum CropType {
  BANANO,
  MANGO,
  YUCA,
  PLATANO,
  MAIZ,
  PALMA;

  static CropType fromJson(String value) {
    return CropType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => CropType.BANANO,
    );
  }
}

extension CropTypeX on CropType {
  String get label => switch (this) {
        CropType.BANANO => 'Banano',
        CropType.MANGO => 'Mango',
        CropType.YUCA => 'Yuca',
        CropType.PLATANO => 'Plátano',
        CropType.MAIZ => 'Maíz',
        CropType.PALMA => 'Palma',
      };

  String get emoji => switch (this) {
        CropType.BANANO => '🍌',
        CropType.MANGO => '🥭',
        CropType.YUCA => '🌿',
        CropType.PLATANO => '🍌',
        CropType.MAIZ => '🌽',
        CropType.PALMA => '🌴',
      };

  IconData get icon => switch (this) {
        CropType.BANANO => Icons.grass,
        CropType.MANGO => Icons.eco,
        CropType.YUCA => Icons.spa,
        CropType.PLATANO => Icons.grass,
        CropType.MAIZ => Icons.grass,
        CropType.PALMA => Icons.park,
      };

  Color get iconBackground => switch (this) {
        CropType.BANANO => const Color(0xFFFFF6DD),
        CropType.MANGO => const Color(0xFFE8F5E9),
        CropType.YUCA => const Color(0xFFEDEFF1),
        CropType.PLATANO => const Color(0xFFFFF6DD),
        CropType.MAIZ => const Color(0xFFFFF6DD),
        CropType.PALMA => const Color(0xFFE8F5E9),
      };

  Color get iconForeground => switch (this) {
        CropType.BANANO => const Color(0xFF8A6D00),
        CropType.MANGO => const Color(0xFF1F7A3A),
        CropType.YUCA => const Color(0xFF6B6B6B),
        CropType.PLATANO => const Color(0xFF8A6D00),
        CropType.MAIZ => const Color(0xFF8A6D00),
        CropType.PALMA => const Color(0xFF1F7A3A),
      };
}
