import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/recommendation.dart';

final List<Recommendation> kMockRecommendations = [
  Recommendation(
    id: 'riego',
    title: 'Riego',
    body: 'Humedad del suelo al 40%. '
        'Programar riego ligero al atardecer en lote 2.',
    level: RecommendationLevel.moderate,
    iconCodePoint: Icons.water_drop.codePoint,
    accentColor: AppColors.warningAmber,
  ),
  Recommendation(
    id: 'fitosanitario',
    title: 'Fitosanitario',
    body: 'Riesgo alto de Sigatoka Negra por lluvias recientes. '
        'Inspeccionar plantación principal.',
    level: RecommendationLevel.alert,
    iconCodePoint: Icons.bug_report.codePoint,
    accentColor: AppColors.alertRed,
  ),
  Recommendation(
    id: 'fertilizacion',
    title: 'Fertilización',
    body: 'Condiciones ideales para aplicar abono orgánico en '
        'la zona norte.',
    level: RecommendationLevel.optimal,
    iconCodePoint: Icons.eco.codePoint,
    accentColor: AppColors.primaryGreen,
  ),
];
