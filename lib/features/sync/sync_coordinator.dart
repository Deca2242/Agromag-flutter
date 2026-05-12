import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/providers/auth_providers.dart';
import '../crops/crops_providers.dart';
import '../home/home_providers.dart';

/// Orquesta sync perfil → cultivos → eventos con single-flight y coalescing.
final syncCoordinatorProvider =
    NotifierProvider<SyncCoordinatorNotifier, bool>(SyncCoordinatorNotifier.new);

class SyncCoordinatorNotifier extends Notifier<bool> {
  Timer? _debounce;
  Future<void>? _gate;
  bool _pendingAgain = false;

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
        final session = ref.read(authSessionProvider).value;
        if (session == null) continue;
        if (ref.read(isOnlineProvider).value != true) continue;
        state = true;
        try {
          await syncAll(profileId: session.user.id);
        } finally {
          state = false;
        }
      }
    } finally {
      state = false;
      _gate = null;
    }
  }

  Future<void> syncAll({required String profileId}) async {
    if (ref.read(isOnlineProvider).value != true) return;

    await ref.read(profileRepositoryProvider).syncPendingProfile();
    await ref.read(cropsRepositoryProvider).syncPending(profileId: profileId);
    await ref.read(cropEventsRepositoryProvider).syncPendingViaBatch();

    ref.invalidate(cropsProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(pendingSyncCountProvider);
    ref.invalidate(dashboardRecommendationsProvider);
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
