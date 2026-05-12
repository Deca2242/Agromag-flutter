import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/recommendations_api.dart';
import '../../domain/models/recommendation.dart';
import '../crops/crops_providers.dart';

// Reexporta el provider real de perfil para que las vistas no importen
// directamente desde auth_providers.
export '../auth/providers/auth_providers.dart' show currentProfileProvider;

/// Proveedor de la API de recomendaciones.
final recommendationsApiProvider = Provider<RecommendationsApi>(
  (_) => const RecommendationsApi(),
);

/// Recomendaciones para un cultivo específico.
/// Retorna lista vacía si no hay red o si el cultivo no tiene recomendaciones.
final cropRecommendationsProvider =
    FutureProvider.family<List<Recommendation>, String>((ref, cropId) async {
  try {
    return await ref
        .read(recommendationsApiProvider)
        .listByCrop(cropId);
  } catch (_) {
    return [];
  }
});

/// Fuerza recarga del historial paginado de decisiones en detalle de cultivo.
final recommendationHistoryTickProvider =
    StateProvider.family<int, String>((ref, _) => 0);

/// Hasta 3 recomendaciones **pendientes** (`followed == null`) entre cultivos (Inicio).
final dashboardRecommendationsProvider =
    FutureProvider<List<Recommendation>>((ref) async {
  final crops = await ref.watch(cropsProvider.future);
  if (crops.isEmpty) return [];
  final api = ref.read(recommendationsApiProvider);
  final lists = await Future.wait(
    crops.map((c) async {
      try {
        final page = await api.listByCropPaged(
          c.id,
          followedFilter: 'pending',
          page: 0,
          size: 5,
        );
        return page.items;
      } catch (_) {
        return <Recommendation>[];
      }
    }),
  );
  final all = lists.expand((e) => e).toList();
  all.sort((a, b) {
    final da = a.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  return all.take(3).toList();
});

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
