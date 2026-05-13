import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock/mock_user.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/recommendation.dart';
import '../crops/crops_providers.dart';

// Reexporta el provider real de perfil para que las vistas no importen
// directamente desde auth_providers.
export '../auth/providers/auth_providers.dart' show currentProfileProvider;

final recommendationsProvider = Provider<List<Recommendation>>((ref) {
  final cropsAsync = ref.watch(cropsProvider);
  final crops = cropsAsync.value ?? [];

  if (crops.isEmpty) return [];

  final List<Recommendation> recs = [];
  int idCounter = 1;

  for (final crop in crops) {
    recs.add(Recommendation(
      id: 'rec_${idCounter++}',
      title: 'Riego para ${crop.name}',
      body: 'Humedad del suelo estimada baja. Programar riego ligero al atardecer en ${crop.lot}.',
      level: RecommendationLevel.moderate,
      iconCodePoint: Icons.water_drop.codePoint,
      accentColor: AppColors.warningAmber,
    ));

    String pest = 'plagas';
    final typeLower = crop.type.toLowerCase();
    if (typeLower.contains('mango')) pest = 'mosca de la fruta';
    if (typeLower.contains('maíz')) pest = 'cogollero';
    if (typeLower.contains('yuca')) pest = 'mosca blanca';
    if (typeLower.contains('banano') || typeLower.contains('plátano')) pest = 'sigatoka negra';
    if (typeLower.contains('palma')) pest = 'pudrición del cogollo';

    recs.add(Recommendation(
      id: 'rec_${idCounter++}',
      title: 'Fitosanitario (${crop.type})',
      body: 'Riesgo moderado de $pest. Inspeccionar ${crop.name} preventivamente.',
      level: RecommendationLevel.alert,
      iconCodePoint: Icons.bug_report.codePoint,
      accentColor: AppColors.alertRed,
    ));
  }

  return recs;
});

/// Perfil de respaldo para el estado de carga (evita pantallas en blanco).
final fallbackProfileProvider = Provider<Profile>((ref) => kMockProfile);

/// Estado de conectividad en tiempo real basado en `connectivity_plus`.
///
/// Emite `true` cuando hay al menos una interfaz de red disponible.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
        (results) => results.any(
          (r) => r != ConnectivityResult.none,
        ),
      );
});
