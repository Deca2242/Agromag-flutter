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

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(filteredAlertsProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandedAppBar(
        online: online,
        pendingCount: pendingCount,
        isSyncing: ref.watch(syncCoordinatorProvider),
        onSyncTap: () => requestSyncFromAppBar(context, ref),
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Text(
                'Alertas y Notificaciones',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manténgase informado sobre el estado de sus cultivos.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const AlertFilterChips(),
              const SizedBox(height: 16),
              if (alerts.isEmpty)
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
                for (final alert in alerts) ...[
                  AlertCard(alert: alert),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
