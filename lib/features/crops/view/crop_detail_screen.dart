import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../home/home_providers.dart';
import '../crops_providers.dart';
import '../widgets/plan_expansion_tile.dart';
import '../widgets/task_history_tile.dart';

class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({super.key, required this.cropId});

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crop = ref.watch(cropByIdProvider(cropId));
    final online = ref.watch(isOnlineProvider).value ?? true;

    if (crop == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: const Center(child: Text('Cultivo no encontrado')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            BrandLogo(size: 24),
            SizedBox(width: 8),
            Text(
              'Detalle de Cultivo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!online)
              const OfflineBanner(
                message: 'Modo sin conexión. Datos guardados localmente.',
              ),
            Expanded(
              child: AdaptiveBody(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    _Header(
                      emoji: crop.imageEmoji,
                      title: crop.type,
                      lot: crop.lot,
                      stage: crop.stage,
                    ),
                    const SizedBox(height: 16),
                    _ClimateCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Planes Activos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    const PlanExpansionTile(
                      title: 'Riego',
                      icon: Icons.water_drop,
                      iconColor: AppColors.primaryGreen,
                      iconBackground: AppColors.softGreenBg,
                    ),
                    const SizedBox(height: 10),
                    const PlanExpansionTile(
                      title: 'Fertilización',
                      icon: Icons.eco,
                      iconColor: Color(0xFF8A4B00),
                      iconBackground: Color(0xFFF6E7D7),
                    ),
                    const SizedBox(height: 10),
                    const PlanExpansionTile(
                      title: 'Fitosanitario',
                      icon: Icons.bug_report,
                      iconColor: AppColors.alertRed,
                      iconBackground: AppColors.alertRedSoft,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Historial de Tareas',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          TaskHistoryTile(
                            title: 'Riego Aplicado',
                            subtitle: '15L por surco completado',
                            when: 'Ayer',
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          TaskHistoryTile(
                            title: 'Inspección Visual',
                            subtitle: 'Sin plagas detectadas',
                            when: 'Hace 3 días',
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          TaskHistoryTile(
                            title: 'Riego Aplicado',
                            subtitle: '10L por surco completado',
                            when: 'Hace 1 sem.',
                          ),
                          Divider(height: 1, color: AppColors.divider),
                          TaskHistoryTile(
                            title: 'Siembra Registrada',
                            subtitle: 'Inicio del ciclo',
                            when: 'Hace 1 mes',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar cultivo'),
                    ),
                    const SizedBox(height: 10),
                    DangerButton(
                      label: 'Eliminar cultivo',
                      icon: Icons.delete_outline,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.emoji,
    required this.title,
    required this.lot,
    required this.stage,
  });

  final String emoji;
  final String title;
  final String lot;
  final String stage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.softGreenBg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      lot,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.eco,
                    size: 14,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Etapa: $stage',
                    style: const TextStyle(
                      color: AppColors.primaryGreenDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClimateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Clima en el lote',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '28°C',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                ),
                Text(
                  'Parcialmente soleado',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.wb_cloudy,
                size: 44,
                color: Colors.white,
              ),
              SizedBox(height: 12),
              Text(
                'Humedad: 65%',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
