import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/branded_app_bar.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../home/home_providers.dart';
import '../crops_providers.dart';
import '../widgets/crop_list_card.dart';

class CropsListScreen extends ConsumerWidget {
  const CropsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropsAsync = ref.watch(cropsProvider);
    final crops = cropsAsync.value ?? [];
    final online = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandedAppBar(online: online),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
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
                        mainAxisExtent: 200,
                      ),
                      itemBuilder: (_, i) =>
                          CropListCard(crop: crops[i]),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      Text(
                        'Mis Cultivos',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Gestiona tus plantaciones actuales.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      for (final crop in crops) ...[
                        CropListCard(crop: crop),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
