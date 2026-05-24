import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/branded_app_bar.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../home/home_providers.dart';
import '../../sync/sync_coordinator.dart';
import '../crops_providers.dart';
import '../widgets/crop_list_card.dart';

class CropsListScreen extends ConsumerWidget {
  const CropsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropsAsync = ref.watch(cropsProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;

    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;

    void retrySync() {
      requestSyncFromAppBar(context, ref);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandedAppBar(
        online: online,
        pendingCount: pendingCount,
        isSyncing: ref.watch(syncCoordinatorProvider),
        onSyncTap: () => requestSyncFromAppBar(context, ref),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-crop-fab',
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => context.pushNamed(AppRoutes.cropsNewName),
        tooltip: 'Registrar nuevo cultivo',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!online) const OfflineBanner(),
            Expanded(
              child: cropsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.alertRed,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error al cargar cultivos:\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(cropsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (crops) => LayoutBuilder(
                  builder: (context, constraints) {
                    if (crops.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.eco_outlined,
                              size: 56,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Aún no tienes cultivos registrados.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  context.pushNamed(AppRoutes.cropsNewName),
                              icon: const Icon(Icons.add),
                              label: const Text('Registrar cultivo'),
                            ),
                          ],
                        ),
                      );
                    }

                    final isWide = constraints.maxWidth > 600;
                    if (isWide) {
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: crops.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 180,
                            ),
                        itemBuilder: (_, i) => CropListCard(
                          crop: crops[i],
                          onRetrySync: retrySync,
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      children: [
                        Text(
                          'Mis Cultivos',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gestiona tus plantaciones actuales.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        for (final crop in crops) ...[
                          CropListCard(crop: crop, onRetrySync: retrySync),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
