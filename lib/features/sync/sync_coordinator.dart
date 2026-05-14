import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../data/repositories/crops_repository.dart';
import '../../data/repositories/recommendations_repository.dart';
import '../auth/providers/auth_providers.dart';
import '../crops/crops_providers.dart';
import '../home/home_providers.dart';

/// Resultado de una pasada completa de sincronización (push + pull).
class ManualSyncResult {
  const ManualSyncResult({
    required this.profilePushOk,
    required this.cropsReport,
    required this.eventsPushOk,
    required this.eventsDeletesOk,
    required this.decisionsPushOk,
    required this.pullCropsOk,
    required this.pullProfileOk,
    required this.pullEventsOk,
  });

  final bool profilePushOk;
  final SyncReport cropsReport;
  final bool eventsPushOk;
  final bool eventsDeletesOk;
  final bool decisionsPushOk;
  final bool pullCropsOk;
  final bool pullProfileOk;
  final bool pullEventsOk;

  bool get isFullSuccess =>
      profilePushOk &&
      eventsPushOk &&
      eventsDeletesOk &&
      decisionsPushOk &&
      cropsReport.failed == 0 &&
      pullCropsOk &&
      pullProfileOk &&
      pullEventsOk;

  String userMessage() {
    if (!pullCropsOk || !pullProfileOk) {
      return 'No se pudo descargar todo desde el servidor. '
          'Revisa la conexión y API_BASE_URL.';
    }
    if (!profilePushOk || !eventsPushOk || !eventsDeletesOk || !decisionsPushOk || cropsReport.failed > 0) {
      final parts = <String>[];
      if (!profilePushOk) parts.add('perfil');
      if (cropsReport.failed > 0) {
        parts.add(
          '${cropsReport.failed} cultivo(s)',
        );
      }
      if (!eventsPushOk) parts.add('eventos');
      if (!eventsDeletesOk) parts.add('eliminaciones de eventos');
      if (!decisionsPushOk) parts.add('decisiones');
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
  int _consecutiveFailures = 0;
  DateTime? _lastSyncTime;

  static const _maxBackoffMs = 30000;
  static const _baseBackoffMs = 1000;
  static const _networkStabilizeMs = 1500;

  int get _backoffMs {
    if (_consecutiveFailures == 0) return 0;
    final exponential = _baseBackoffMs * (1 << (_consecutiveFailures - 1));
    return exponential.clamp(0, _maxBackoffMs);
  }

  /// Ultimo resultado tras [requestSync] (p. ej. para SnackBar). Se consume una vez.
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

  /// Resetea el backoff exponencial (se llama al detectar reconexión).
  void resetBackoff() {
    _consecutiveFailures = 0;
    _lastSyncTime = null;
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
        if (session == null) {
          await _waitForCondition(() => ref.read(authSessionProvider).value != null);
          continue;
        }
        if (ref.read(isOnlineProvider).value != true) {
          await _waitForCondition(() => ref.read(isOnlineProvider).value == true);
          continue;
        }

        final backoff = _backoffMs;
        final timeSinceLastSync = _lastSyncTime != null
            ? DateTime.now().difference(_lastSyncTime!).inMilliseconds
            : _maxBackoffMs + 1;
        if (backoff > 0 && timeSinceLastSync < backoff) {
          final waitMs = backoff - timeSinceLastSync;
          await Future<void>.delayed(Duration(milliseconds: waitMs));
        }

        await Future<void>.delayed(const Duration(milliseconds: _networkStabilizeMs));

        final isActuallyOnline = await _verifyConnectivity();
        if (!isActuallyOnline) {
          _consecutiveFailures++;
          continue;
        }

        state = true;
        try {
          _lastSyncResult = await _runFullSync(profileId: session.user.id);
          if (_lastSyncResult!.isFullSuccess) {
            _consecutiveFailures = 0;
          } else {
            _consecutiveFailures++;
          }
          _lastSyncTime = DateTime.now();
        } finally {
          state = false;
        }
      }
    } finally {
      state = false;
      _gate = null;
    }
  }

  Future<void> _waitForCondition(bool Function() condition) async {
    int attempts = 0;
    while (!condition() && attempts < 20) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
  }

  Future<bool> _verifyConnectivity() async {
    try {
      await ApiClient.instance.dio.get(
        '/api/profile',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ManualSyncResult> _runFullSync({required String profileId}) async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final cropsRepo = ref.read(cropsRepositoryProvider);
    final eventsRepo = ref.read(cropEventsRepositoryProvider);
    final recommendationsRepo = ref.read(recommendationsRepositoryProvider);

    // 1) Push: perfil pendiente → cultivos → eventos → eliminaciones de eventos → decisiones
    final profilePushOk = await profileRepo.syncPendingProfile();
    final cropsReport = await cropsRepo.syncPending(profileId: profileId);
    final eventsPushOk = await eventsRepo.syncPendingViaBatch();
    final eventsDeletesOk = await eventsRepo.syncPendingDeletes();
    final decisionsPushOk = await recommendationsRepo.syncPendingDecisions();

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
      eventsDeletesOk: eventsDeletesOk,
      decisionsPushOk: decisionsPushOk,
      pullCropsOk: pullCropsOk,
      pullProfileOk: pullProfileOk,
      pullEventsOk: pullEventsOk,
    );
  }
}

/// Sincronización manual desde la AppBar: avisa si no hay red.
Future<void> requestSyncFromAppBar(BuildContext context, WidgetRef ref) async {
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
        ref.read(syncCoordinatorProvider.notifier).resetBackoff();
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
