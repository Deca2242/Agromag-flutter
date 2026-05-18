import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_checker.dart';
import '../../data/services/recommendations_api.dart';
import '../../domain/models/recommendation.dart';
import '../crops/crops_providers.dart';

// Reexporta el provider real de perfil para que las vistas no importen
// directamente desde auth_providers.
export '../auth/providers/auth_providers.dart' show currentProfileProvider;

/// Proveedor de la API de recomendaciones (acceso directo para llamadas online).
final recommendationsApiProvider = Provider<RecommendationsApi>(
  (_) => const RecommendationsApi(),
);

/// Recomendaciones para un cultivo específico.
/// Intenta la API del backend; si no hay red, usa la caché local.
/// Propaga el error como AsyncValue.error para que la UI lo muestre.
final cropRecommendationsProvider =
    FutureProvider.family<List<Recommendation>, String>((ref, cropId) async {
      return ref
          .read(recommendationsRepositoryProvider)
          .listByCrop(cropId);
    });

/// Fuerza recarga del historial paginado de decisiones en detalle de cultivo.
final recommendationHistoryTickProvider = StateProvider.family<int, String>(
  (ref, _) => 0,
);

/// Hasta 3 recomendaciones **pendientes** (`followed == null`) entre cultivos (Inicio).
/// Estrategia:
///   1. Si hay internet → consulta por cada cultivo vía repositorio (cachea en SQLite).
///   2. Si no hay internet → usa caché local (recomendaciones previas o generadas offline).
final dashboardRecommendationsProvider = FutureProvider<List<Recommendation>>((
  ref,
) async {
  final crops = await ref.watch(cropsProvider.future);
  if (crops.isEmpty) return [];

  final isOnline = ref.watch(isOnlineProvider).value ?? true;
  final repo = ref.read(recommendationsRepositoryProvider);

  if (isOnline) {
    final lists = await Future.wait(
      crops.map((c) => repo.listPendingByCrop(c.id, size: 5)),
    );
    final all = lists.expand((e) => e).toList();
    all.sort((a, b) {
      final da = a.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.generatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return all.take(3).toList();
  } else {
    return repo.listPendingFromCache(limit: 3);
  }
});

/// Estado de conectividad con verificación HTTP real.
///
/// Combina connectivity_plus (interfaz de red) con un ping HTTP a /api/health
/// para confirmar que el backend es alcanzable. Los falsos positivos de
/// "Wi-Fi conectado pero sin internet" quedan eliminados.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  // Verificación inicial al arrancar el provider
  yield await ConnectivityChecker.instance.isReachable(forceCheck: true);

  await for (final results in Connectivity().onConnectivityChanged) {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      ConnectivityChecker.instance.invalidate();
      yield false;
    } else {
      yield await ConnectivityChecker.instance.isReachable(forceCheck: true);
    }
  }
});
