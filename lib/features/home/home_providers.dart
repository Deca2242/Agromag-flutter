import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_recommendations.dart';
import '../../data/mock/mock_user.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/recommendation.dart';

// Reexporta el provider real de perfil para que las vistas no importen
// directamente desde auth_providers.
export '../auth/providers/auth_providers.dart' show currentProfileProvider;

final recommendationsProvider =
    Provider<List<Recommendation>>((ref) => kMockRecommendations);

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
