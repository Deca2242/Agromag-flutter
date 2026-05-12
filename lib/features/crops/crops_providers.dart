import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/crop_events_repository.dart';
import '../../data/repositories/crops_repository.dart';
import '../../data/services/crop_events_api.dart';
import '../../data/services/crop_events_local_dao.dart';
import '../../data/services/crops_api.dart';
import '../../data/services/crops_local_dao.dart';
import '../../data/services/sync_api.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/crop_event.dart';
import '../auth/providers/auth_providers.dart';

// ── Servicios ──────────────────────────────────────────────────────────────

final cropsRepositoryProvider = Provider<CropsRepository>((ref) {
  return const CropsRepository(
    dao: CropsLocalDao(),
    api: CropsApi(),
    syncApi: SyncApi(),
  );
});

// ── Lista de cultivos ──────────────────────────────────────────────────────

/// Lista de cultivos del usuario autenticado.
/// Lee de SQLite y refresca desde el servidor en background.
final cropsProvider = FutureProvider<List<Crop>>((ref) async {
  final session = ref.watch(authSessionProvider).value;
  if (session == null) return [];
  final profileId = session.user.id;
  return ref.read(cropsRepositoryProvider).getCrops(profileId: profileId);
});

// ── Cultivo individual ─────────────────────────────────────────────────────

final cropByIdProvider =
    FutureProvider.family<Crop?, String>((ref, id) async {
  final cropsAsync = ref.watch(cropsProvider);
  final crops = cropsAsync.value;
  if (crops != null) {
    try {
      return crops.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
  return ref.read(cropsRepositoryProvider).getById(id);
});

// ── Pending sync count ─────────────────────────────────────────────────────

/// Total de cultivos pendientes de sincronizar (para badge en AppBar).
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final session = ref.watch(authSessionProvider).value;
  if (session == null) return 0;
  return ref
      .read(cropsRepositoryProvider)
      .pendingCount(profileId: session.user.id);
});

// ── Eventos de cultivo ─────────────────────────────────────────────────────

final cropEventsRepositoryProvider = Provider<CropEventsRepository>((ref) {
  return const CropEventsRepository(
    api: CropEventsApi(),
    dao: CropEventsLocalDao(),
    syncApi: SyncApi(),
  );
});

final cropEventsProvider =
    FutureProvider.family<List<CropEvent>, String>((ref, cropId) async {
  return ref.read(cropEventsRepositoryProvider).getEvents(cropId);
});
