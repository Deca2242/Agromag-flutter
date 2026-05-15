import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../data/repositories/crops_repository.dart';
import '../../data/repositories/recommendations_repository.dart';
import '../../data/services/crop_sync_conflict.dart';
import '../../data/services/local_db.dart';
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
    this.conflicts = const [],
  });

  final bool profilePushOk;
  final SyncReport cropsReport;
  final bool eventsPushOk;
  final bool eventsDeletesOk;
  final bool decisionsPushOk;
  final bool pullCropsOk;
  final bool pullProfileOk;
  final bool pullEventsOk;
  final List<CropSyncConflict> conflicts;

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
    if (!profilePushOk ||
        !eventsPushOk ||
        !eventsDeletesOk ||
        !decisionsPushOk ||
        cropsReport.failed > 0) {
      final parts = <String>[];
      if (!profilePushOk) parts.add('perfil');
      if (cropsReport.failed > 0) {
        parts.add('${cropsReport.failed} cultivo(s)');
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
    if (conflicts.isNotEmpty) {
      return 'Sincronización completada. ${conflicts.length} campo(s) '
          'actualizado(s) desde el servidor.';
    }
    return 'Sincronización completada.';
  }
}

/// Orquesta sync perfil → cultivos → eventos con single-flight y coalescing.
final syncCoordinatorProvider = NotifierProvider<SyncCoordinatorNotifier, bool>(
  SyncCoordinatorNotifier.new,
);

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

        // 1. Esperar sesión activa (máx 15s con verificación directa).
        final session = await _waitUntilSessionAvailable();
        if (session == null) continue;

        // 2. Verificar conectividad real (HTTP ping) — no depender de
        //    isOnlineProvider que puede tardar en emitir su primer valor.
        final isActuallyOnline = await _waitUntilOnlineVerified();
        if (!isActuallyOnline) continue;

        // 3. Backoff exponencial entre intentos fallidos.
        final backoff = _backoffMs;
        final timeSinceLastSync = _lastSyncTime != null
            ? DateTime.now().difference(_lastSyncTime!).inMilliseconds
            : _maxBackoffMs + 1;
        if (backoff > 0 && timeSinceLastSync < backoff) {
          final waitMs = backoff - timeSinceLastSync;
          await Future<void>.delayed(Duration(milliseconds: waitMs));
        }

        await Future<void>.delayed(
          const Duration(milliseconds: _networkStabilizeMs),
        );

        // 4. Doble verificación antes de ejecutar.
        final stillOnline = await _verifyConnectivity();
        if (!stillOnline) {
          _consecutiveFailures++;
          continue;
        }

        state = true;
        try {
          _lastSyncResult = await _runFullSync(profileId: session.user.id);
          if (_lastSyncResult!.isFullSuccess) {
            _consecutiveFailures = 0;
            await LocalDb.instance.purgeOldSyncedData();
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

  /// Espera hasta 15s a que haya una sesión activa, verificando directamente
  /// el provider en lugar de confiar solo en el último valor emitido.
  Future<Session?> _waitUntilSessionAvailable() async {
    int attempts = 0;
    while (attempts < 30) {
      final session = ref.read(authSessionProvider).value;
      if (session != null) return session;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    return null;
  }

  /// Verifica conectividad real con HTTP ping.
  /// Intenta hasta 20 veces (10s) antes de rendirse.
  /// Si isOnlineProvider ya indica conexión, hace un solo intento rápido.
  Future<bool> _waitUntilOnlineVerified() async {
    // Fast path: si el provider ya dice que hay red, un solo ping basta.
    final providerHint = ref.read(isOnlineProvider).value;
    if (providerHint == true) {
      return _verifyConnectivity();
    }

    // Slow path: verificar con polling hasta que haya conexión o timeout.
    int attempts = 0;
    while (attempts < 20) {
      if (await _verifyConnectivity()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    return false;
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

    // 2) Pull cultivos (ahora retorna conflictos)
    final pullResult = await cropsRepo.pullCropsFromServer(
      profileId: profileId,
    );
    final pullCropsOk = pullResult.success;
    final conflicts = pullResult.conflicts;

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
      conflicts: conflicts,
    );
  }
}

/// Sincronización manual desde la AppBar: avisa si no hay red.
Future<void> requestSyncFromAppBar(BuildContext context, WidgetRef ref) async {
  await ref.read(syncCoordinatorProvider.notifier).requestSync();
  if (!context.mounted) return;
  final result = ref
      .read(syncCoordinatorProvider.notifier)
      .consumeLastSyncResult();
  if (result != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.userMessage()),
        behavior: SnackBarBehavior.floating,
        action: result.conflicts.isNotEmpty
            ? SnackBarAction(
                label: 'Ver detalles',
                onPressed: () {
                  showConflictDetailSheet(context, result.conflicts);
                },
              )
            : null,
      ),
    );
  }
}

/// Registra listeners de conectividad y sesión; observar desde el shell de la app.
final syncBootstrapProvider = Provider<void>((ref) {
  bool? prevOnline;

  ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
    final online = next.value;
    if (online == true && prevOnline != true) {
      ref.read(syncCoordinatorProvider.notifier).resetBackoff();
      ref.read(syncCoordinatorProvider.notifier).requestSync();
    }
    if (online != null) prevOnline = online;
  }, fireImmediately: true);

  ref.listen<AsyncValue<Session?>>(authSessionProvider, (previous, next) {
    final now = next.value;
    if (now == null) return;
    final prevSession = previous?.value;
    if (prevSession == null || prevSession.user.id != now.user.id) {
      ref.read(syncCoordinatorProvider.notifier).requestSync();
    }
  }, fireImmediately: true);
});

/// Muestra un modal con el detalle de los conflictos de sincronización.
void showConflictDetailSheet(
  BuildContext context,
  List<CropSyncConflict> conflicts,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Campos actualizados desde el servidor',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus cambios locales fueron sobrescritos por la versión del servidor.',
              style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: conflicts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = conflicts[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cloud_download_outlined,
                          size: 18,
                          color: Color(0xFF1F7A3A),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.cropLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.fieldLabel}: ${c.localValue} → ${c.serverValue}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
