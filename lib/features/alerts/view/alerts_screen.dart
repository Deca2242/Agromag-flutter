import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/branded_app_bar.dart';
import '../../crops/crops_providers.dart';
import '../../home/home_providers.dart';
import '../../sync/sync_coordinator.dart';
import '../alerts_providers.dart';
import '../widgets/alert_card.dart';
import '../widgets/alert_filter_chips.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  bool _markedAsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_markedAsRead) {
      final alerts = ref.read(alertsProvider).value;
      if (alerts != null && alerts.isNotEmpty) {
        _markedAsRead = true;
        ref.read(alertsProvider.notifier).markAllVisibleAsRead(alerts);
      }
    }
  }

  Future<void> _showClearReadDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar alertas leídas'),
        content: const Text(
          '¿Eliminar todas las alertas que ya has visto? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.alertRed),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final deleted = await ref.read(alertsProvider.notifier).deleteAllRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deleted alerta(s) eliminada(s)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(alertsRefreshTickProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final filter = ref.watch(alertsFilterProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandedAppBar(
        online: online,
        pendingCount: pendingCount,
        isSyncing: ref.watch(syncCoordinatorProvider),
        onSyncTap: () => requestSyncFromAppBar(context, ref),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final alerts = ref.watch(alertsProvider).value ?? [];
              final readCount = alerts.where((a) => a.isRead).length;
              if (readCount == 0) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Limpiar alertas leídas',
                onPressed: _showClearReadDialog,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: alertsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar las alertas.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.read(alertsProvider.notifier).reload(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (alerts) {
              final filteredAlerts = filter == null
                  ? alerts
                  : alerts.where((a) => a.category == filter).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  Text(
                    'Alertas y Notificaciones',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manténgase informado sobre el estado de sus cultivos.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const AlertFilterChips(),
                  const SizedBox(height: 16),
                  if (filteredAlerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No hay alertas en esta categoría',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        for (final alert in filteredAlerts) ...[
                          AlertCard(alert: alert),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
