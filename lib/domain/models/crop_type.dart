// ignore_for_file: constant_identifier_names
// Los nombres coinciden con el enum Java del backend (SCREAMING_SNAKE_CASE).

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
    CropType.BANANO => AppColors.warningAmberSoft,
    CropType.MANGO => AppColors.softGreenBg,
    CropType.YUCA => AppColors.divider,
    CropType.PLATANO => AppColors.warningAmberSoft,
    CropType.MAIZ => AppColors.warningAmberSoft,
    CropType.PALMA => AppColors.softGreenBg,
  };

  Color get iconForeground => switch (this) {
    CropType.BANANO => AppColors.cropTextBrown,
    CropType.MANGO => AppColors.primaryGreen,
    CropType.YUCA => AppColors.textSecondary,
    CropType.PLATANO => AppColors.cropTextBrown,
    CropType.MAIZ => AppColors.cropTextBrown,
    CropType.PALMA => AppColors.primaryGreen,
  };
}
