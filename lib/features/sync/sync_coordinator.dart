import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_exceptions.dart';
import '../../data/repositories/crops_repository.dart';
import '../auth/providers/auth_providers.dart';
import '../crops/crops_providers.dart';
import '../home/home_providers.dart';

/// Resultado de una pasada completa de sincronización (push + pull).
class ManualSyncResult {
  const ManualSyncResult({
    required this.profilePushOk,
    required this.cropsReport,
    required this.eventsPushOk,
    required this.pullCropsOk,
    required this.pullProfileOk,
    required this.pullEventsOk,
  });

  final bool profilePushOk;
  final SyncReport cropsReport;
  final bool eventsPushOk;
  final bool pullCropsOk;
  final bool pullProfileOk;
  final bool pullEventsOk;

  bool get isFullSuccess =>
      profilePushOk &&
      eventsPushOk &&
      cropsReport.failed == 0 &&
      pullCropsOk &&
      pullProfileOk &&
      pullEventsOk;

  String userMessage() {
    if (!pullCropsOk || !pullProfileOk) {
      return 'No se pudo descargar todo desde el servidor. '
          'Revisa la conexión y API_BASE_URL.';
    }
    if (!profilePushOk || !eventsPushOk || cropsReport.failed > 0) {
      final parts = <String>[];
      if (!profilePushOk) parts.add('perfil');
      if (cropsReport.failed > 0) {
        parts.add(
          '${cropsReport.failed} cultivo(s)',
        );
      }
      if (!eventsPushOk) parts.add('eventos');
      return 'Sincronización parcial: no se pudo subir ${parts.join(', ')}. '
          'Se reintentará al volver a sincronizar.';
    }
    if (!pullEventsOk) {
      return 'Sincronización completada, pero algunos eventos no se '
          'actualizaron desde el servidor.';
    }
    return 'Sincronización completada.';
  }
}

/// Orquesta sync perfil → cultivos → eventos con single-flight y coalescing.
final syncCoordinatorProvider =
    NotifierProvider<SyncCoordinatorNotifier, bool>(SyncCoordinatorNotifier.new);

class SyncCoordinatorNotifier extends Notifier<bool> {
  Timer? _debounce;
  Future<void>? _gate;
  bool _pendingAgain = false;
  ManualSyncResult? _lastSyncResult;

  /// Último resultado tras [requestSync] (p. ej. para SnackBar). Se consume una vez.
  ManualSyncResult? consumeLastSyncResult() {
    final r = _lastSyncResult;
    _lastSyncResult = null;
    return r;
  }

  @override
  bool build() {
    ref.onDispose(() => _debounce?.cancel());
    return false;
  }

  /// Agrupa ráfagas de escrituras locales antes de subir.
  void scheduleDebouncedSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _debounce = null;
      unawaited(requestSync());
    });
  }

  /// Encola una pasada de sincronización; varias llamadas concurrentes comparten
  /// la misma ejecución y, si llegan señales durante el sync, se hace un segundo pase.
  Future<void> requestSync() async {
    _pendingAgain = true;
    _gate ??= _pump();
    await _gate;
  }

  Future<void> _pump() async {
    try {
      while (_pendingAgain) {
        _pendingAgain = false;
        _lastSyncResult = null;
        final session = ref.read(authSessionProvider).value;
        if (session == null) continue;
        if (ref.read(isOnlineProvider).value != true) continue;
        state = true;
        try {
          _lastSyncResult = await _runFullSync(profileId: session.user.id);
        } finally {
          state = false;
        }
      }
    } finally {
      state = false;
      _gate = null;
    }
  }

  Future<ManualSyncResult> _runFullSync({required String profileId}) async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final cropsRepo = ref.read(cropsRepositoryProvider);
    final eventsRepo = ref.read(cropEventsRepositoryProvider);

    // 1) Push: perfil pendiente → cultivos → eventos
    final profilePushOk = await profileRepo.syncPendingProfile();
    final cropsReport = await cropsRepo.syncPending(profileId: profileId);
    final eventsPushOk = await eventsRepo.syncPendingViaBatch();

    // 2) Pull cultivos
    final pullCropsOk = await cropsRepo.pullCropsFromServer(profileId: profileId);

    // 3) Pull perfil
    var pullProfileOk = true;
    try {
      await profileRepo.refreshFromServer();
    } on ApiException {
      pullProfileOk = false;
    }

    // 4) Pull eventos por cada cultivo local
    final cropIds = await cropsRepo.listLocalCropIds(profileId: profileId);
    final pullEventsOk = await eventsRepo.refreshAllFromServer(cropIds);

    for (final id in cropIds) {
      ref.invalidate(cropEventsProvider(id));
    }

    ref.invalidate(cropsProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(pendingSyncCountProvider);
    ref.invalidate(dashboardRecommendationsProvider);

    return ManualSyncResult(
      profilePushOk: profilePushOk,
      cropsReport: cropsReport,
      eventsPushOk: eventsPushOk,
      pullCropsOk: pullCropsOk,
      pullProfileOk: pullProfileOk,
      pullEventsOk: pullEventsOk,
    );
  }
}

/// Sincronización manual desde la AppBar: avisa si no hay red.
Future<void> requestSyncFromAppBar(BuildContext context, WidgetRef ref) async {
  if (ref.read(isOnlineProvider).value != true) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sin conexión. Conéctate para sincronizar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }
  await ref.read(syncCoordinatorProvider.notifier).requestSync();
  if (!context.mounted) return;
  final result = ref.read(syncCoordinatorProvider.notifier).consumeLastSyncResult();
  if (result != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.userMessage()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Registra listeners de conectividad y sesión; observar desde el shell de la app.
final syncBootstrapProvider = Provider<void>((ref) {
  bool? prevOnline;

  ref.listen<AsyncValue<bool>>(
    isOnlineProvider,
    (previous, next) {
      final online = next.value;
      if (online == true && prevOnline != true) {
        ref.read(syncCoordinatorProvider.notifier).requestSync();
      }
      if (online != null) prevOnline = online;
    },
    fireImmediately: true,
  );

  ref.listen<AsyncValue<Session?>>(
    authSessionProvider,
    (previous, next) {
      final now = next.value;
      if (now == null) return;
      if (ref.read(isOnlineProvider).value != true) return;
      final prevSession = previous?.value;
      if (prevSession == null || prevSession.user.id != now.user.id) {
        ref.read(syncCoordinatorProvider.notifier).requestSync();
      }
    },
    fireImmediately: true,
  );
});
