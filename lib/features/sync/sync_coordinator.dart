import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/crops_repository.dart';
import '../../data/services/crop_sync_conflict.dart';
import '../../data/services/local_db.dart';
import '../auth/providers/auth_providers.dart';
import '../crops/crops_providers.dart';
import '../home/home_providers.dart';
import 'widgets/conflict_detail_sheet.dart';

/// Resultado de una pasada completa de sincronización (push + pull).
@immutable
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
    this.error,
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
  final String? error;

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
    if (error != null) return error!;
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
  static const _networkStabilizeMs = 800;
  static const _maxRetriesPerCycle = 3;

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

        debugPrint('[SYNC] Iniciando ciclo de sincronización...');

        var cycleSucceeded = false;
        var retryCount = 0;

        while (retryCount < _maxRetriesPerCycle && !cycleSucceeded) {
          if (retryCount > 0) {
            debugPrint('[SYNC] Reintento $retryCount de $_maxRetriesPerCycle...');
          }

          // 1. Verificar sesión activa (máx 5s).
          final session = await _waitUntilSessionAvailable();
          if (session == null) {
            debugPrint('[SYNC] No hay sesión activa.');
            _lastSyncResult = ManualSyncResult(
              profilePushOk: false,
              cropsReport: const SyncReport(synced: 0, failed: 0),
              eventsPushOk: false,
              eventsDeletesOk: false,
              decisionsPushOk: false,
              pullCropsOk: false,
              pullProfileOk: false,
              pullEventsOk: false,
              error: 'No hay sesión activa. Inicia sesión de nuevo.',
            );
            retryCount++;
            await Future<void>.delayed(const Duration(seconds: 2));
            continue;
          }
          debugPrint('[SYNC] Sesión obtenida: ${session.user.id}');

          // 2. Verificar conectividad real (HTTP ping).
          final isActuallyOnline = await _verifyConnectivity();
          if (!isActuallyOnline) {
            debugPrint('[SYNC] Sin conectividad con el servidor.');
            _lastSyncResult = ManualSyncResult(
              profilePushOk: false,
              cropsReport: const SyncReport(synced: 0, failed: 0),
              eventsPushOk: false,
              eventsDeletesOk: false,
              decisionsPushOk: false,
              pullCropsOk: false,
              pullProfileOk: false,
              pullEventsOk: false,
              error: 'No se puede conectar con el servidor. Verifica tu conexión.',
            );
            retryCount++;
            await Future<void>.delayed(const Duration(seconds: 2));
            continue;
          }
          debugPrint('[SYNC] Conectividad verificada.');

          // 3. Backoff exponencial entre intentos fallidos.
          final backoff = _backoffMs;
          final timeSinceLastSync = _lastSyncTime != null
              ? DateTime.now().difference(_lastSyncTime!).inMilliseconds
              : _maxBackoffMs + 1;
          if (backoff > 0 && timeSinceLastSync < backoff) {
            final waitMs = backoff - timeSinceLastSync;
            debugPrint('[SYNC] Backoff: esperando ${waitMs}ms');
            await Future<void>.delayed(Duration(milliseconds: waitMs));
          }

          await Future<void>.delayed(
            const Duration(milliseconds: _networkStabilizeMs),
          );

          // 4. Ejecutar sincronización completa.
          debugPrint('[SYNC] Ejecutando sincronización completa...');
          state = true;
          try {
            _lastSyncResult = await _runFullSync(profileId: session.user.id);
            if (_lastSyncResult!.isFullSuccess) {
              _consecutiveFailures = 0;
              await LocalDb.instance.purgeOldSyncedData();
              debugPrint('[SYNC] Sincronización exitosa.');
            } else {
              _consecutiveFailures++;
              debugPrint('[SYNC] Sincronización parcial o fallida.');
            }
            _lastSyncTime = DateTime.now();
            cycleSucceeded = true;
          } catch (e, st) {
            debugPrint('[SYNC] Error durante la sincronización: $e\n$st');
            _consecutiveFailures++;
            _lastSyncResult = ManualSyncResult(
              profilePushOk: false,
              cropsReport: const SyncReport(synced: 0, failed: 0),
              eventsPushOk: false,
              eventsDeletesOk: false,
              decisionsPushOk: false,
              pullCropsOk: false,
              pullProfileOk: false,
              pullEventsOk: false,
              error: 'Error durante la sincronización: $e',
            );
            retryCount++;
            await Future<void>.delayed(const Duration(seconds: 2));
          } finally {
            state = false;
          }
        }

        if (!cycleSucceeded && _lastSyncResult == null) {
          _lastSyncResult = ManualSyncResult(
            profilePushOk: false,
            cropsReport: const SyncReport(synced: 0, failed: 0),
            eventsPushOk: false,
            eventsDeletesOk: false,
            decisionsPushOk: false,
            pullCropsOk: false,
            pullProfileOk: false,
            pullEventsOk: false,
            error: 'No se pudo sincronizar tras $_maxRetriesPerCycle intentos.',
          );
        }

        // Si llegaron más señales durante el ciclo, repetir.
      }
    } catch (e, st) {
      debugPrint('[SYNC] Error crítico en _pump: $e\n$st');
      _lastSyncResult = ManualSyncResult(
        profilePushOk: false,
        cropsReport: const SyncReport(synced: 0, failed: 0),
        eventsPushOk: false,
        eventsDeletesOk: false,
        decisionsPushOk: false,
        pullCropsOk: false,
        pullProfileOk: false,
        pullEventsOk: false,
        error: 'Error inesperado: $e',
      );
    } finally {
      state = false;
      _gate = null;
    }
  }

  /// Espera hasta 5s a que haya una sesión activa.
  Future<Session?> _waitUntilSessionAvailable() async {
    int attempts = 0;
    while (attempts < 10) {
      final session = ref.read(authSessionProvider).value;
      if (session != null) return session;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      attempts++;
    }
    return null;
  }

  Future<bool> _verifyConnectivity() async {
    try {
      final response = await ApiClient.instance.dio.get(
        '/api/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      final isOk = response.statusCode == 200;
      debugPrint('[SYNC] Conectividad: ${isOk ? "OK" : "FALLÓ"}');
      return isOk;
    } catch (e) {
      debugPrint('[SYNC] Conectividad falló: $e');
      return false;
    }
  }

  Future<ManualSyncResult> _runFullSync({required String profileId}) async {
    debugPrint('[SYNC] Iniciando sync completo para profileId=$profileId');
    final profileRepo = ref.read(profileRepositoryProvider);
    final cropsRepo = ref.read(cropsRepositoryProvider);
    final eventsRepo = ref.read(cropEventsRepositoryProvider);
    final recommendationsRepo = ref.read(recommendationsRepositoryProvider);

    var profilePushOk = false;
    var cropsReport = const SyncReport(synced: 0, failed: 0);
    var eventsPushOk = false;
    var eventsDeletesOk = false;
    var decisionsPushOk = false;
    var pullCropsOk = false;
    var pullProfileOk = false;
    var pullEventsOk = false;
    List<CropSyncConflict> conflicts = const [];

    try {
      // 1) Push: perfil pendiente
      debugPrint('[SYNC] Push perfil pendiente...');
      try {
        profilePushOk = await profileRepo.syncPendingProfile();
        debugPrint('[SYNC] Push perfil: ${profilePushOk ? "OK" : "FALLÓ"}');
      } catch (e) {
        debugPrint('[SYNC] Error push perfil: $e');
      }

      // 2) Push: cultivos pendientes
      debugPrint('[SYNC] Push cultivos pendientes...');
      try {
        cropsReport = await cropsRepo.syncPending(profileId: profileId);
        debugPrint('[SYNC] Push cultivos: ${cropsReport.synced} sincronizados, ${cropsReport.failed} fallidos');
      } catch (e) {
        debugPrint('[SYNC] Error push cultivos: $e');
      }

      // 3) Push: eventos pendientes
      debugPrint('[SYNC] Push eventos pendientes...');
      try {
        eventsPushOk = await eventsRepo.syncPendingViaBatch();
        debugPrint('[SYNC] Push eventos: ${eventsPushOk ? "OK" : "FALLÓ"}');
      } catch (e) {
        debugPrint('[SYNC] Error push eventos: $e');
      }

      // 4) Push: eliminaciones de eventos
      debugPrint('[SYNC] Push eliminaciones de eventos...');
      try {
        eventsDeletesOk = await eventsRepo.syncPendingDeletes();
        debugPrint('[SYNC] Push eliminaciones: ${eventsDeletesOk ? "OK" : "FALLÓ"}');
      } catch (e) {
        debugPrint('[SYNC] Error push eliminaciones: $e');
      }

      // 5) Push: decisiones pendientes
      debugPrint('[SYNC] Push decisiones pendientes...');
      try {
        decisionsPushOk = await recommendationsRepo.syncPendingDecisions();
        debugPrint('[SYNC] Push decisiones: ${decisionsPushOk ? "OK" : "FALLÓ"}');
      } catch (e) {
        debugPrint('[SYNC] Error push decisiones: $e');
      }

      // 6) Pull cultivos
      debugPrint('[SYNC] Pull cultivos desde servidor...');
      try {
        final pullResult = await cropsRepo.pullCropsFromServer(
          profileId: profileId,
        );
        pullCropsOk = pullResult.success;
        conflicts = pullResult.conflicts;
        debugPrint('[SYNC] Pull cultivos: ${pullCropsOk ? "OK" : "FALLÓ"}, ${conflicts.length} conflictos');
      } catch (e) {
        debugPrint('[SYNC] Error pull cultivos: $e');
      }

      // 7) Pull perfil
      debugPrint('[SYNC] Pull perfil desde servidor...');
      try {
        await profileRepo.refreshFromServer();
        pullProfileOk = true;
        debugPrint('[SYNC] Pull perfil: OK');
      } catch (e) {
        debugPrint('[SYNC] Error pull perfil: $e');
      }

      // 8) Pull eventos por cada cultivo local
      debugPrint('[SYNC] Obteniendo IDs de cultivos locales...');
      List<String> cropIds = [];
      try {
        cropIds = await cropsRepo.listLocalCropIds(profileId: profileId);
        debugPrint('[SYNC] ${cropIds.length} cultivos locales encontrados');
      } catch (e) {
        debugPrint('[SYNC] Error obteniendo IDs locales: $e');
      }

      debugPrint('[SYNC] Pull eventos desde servidor...');
      try {
        pullEventsOk = await eventsRepo.refreshAllFromServer(cropIds);
        debugPrint('[SYNC] Pull eventos: ${pullEventsOk ? "OK" : "FALLÓ"}');
      } catch (e) {
        debugPrint('[SYNC] Error pull eventos: $e');
      }

      for (final id in cropIds) {
        ref.invalidate(cropEventsProvider(id));
      }

      ref.invalidate(cropsProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(pendingSyncCountProvider);
      ref.invalidate(dashboardRecommendationsProvider);
    } catch (e, st) {
      debugPrint('[SYNC] Error general en _runFullSync: $e\n$st');
    }

    debugPrint('[SYNC] Sync completo finalizado');
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
        backgroundColor: result.isFullSuccess
            ? AppColors.primaryGreen
            : result.error != null
                ? AppColors.alertRedStrong
                : null,
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
  } else {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se pudo completar la sincronización.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Registra listeners de conectividad y sesión; observar desde el shell de la app.
final syncBootstrapProvider = Provider<void>((ref) {
  bool? prevOnline;

  ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
    final online = next.value;
    debugPrint('[SYNC] isOnlineProvider cambió: $online (previo: $prevOnline)');
    if (online == true && prevOnline != true) {
      debugPrint('[SYNC] Reconexión detectada, solicitando sync...');
      ref.read(syncCoordinatorProvider.notifier).resetBackoff();
      ref.read(syncCoordinatorProvider.notifier).requestSync();
    }
    if (online != null) prevOnline = online;
  }, fireImmediately: true);

  ref.listen<AsyncValue<Session?>>(authSessionProvider, (previous, next) {
    final now = next.value;
    debugPrint('[SYNC] authSessionProvider cambió: ${now != null ? "sesión activa" : "sin sesión"}');
    if (now == null) return;
    final prevSession = previous?.value;
    if (prevSession == null || prevSession.user.id != now.user.id) {
      debugPrint('[SYNC] Nueva sesión o cambio de usuario, solicitando sync...');
      ref.read(syncCoordinatorProvider.notifier).requestSync();
    }
  }, fireImmediately: true);
});
