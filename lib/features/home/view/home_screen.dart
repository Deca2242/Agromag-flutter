import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/branded_app_bar.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/crop_type.dart';
import '../../../domain/models/municipality.dart';
import '../../../domain/models/recommendation.dart';
import '../../crops/crops_providers.dart'
    show cropsProvider, pendingSyncCountProvider;
import '../../sync/sync_coordinator.dart';
import '../home_providers.dart';
import '../weather_providers.dart';
import '../widgets/crops_chips_row.dart';
import '../widgets/generate_recommendations_button.dart';
import '../widgets/recommendation_tile.dart';
import '../widgets/weather_card.dart';

String? _cropLabelFor(Recommendation r, List<Crop> crops) {
  final id = r.cropId;
  if (id != null) {
    for (final c in crops) {
      if (c.id == id) return c.cropType.label;
    }
  }
  final code = r.cropTypeCode;
  if (code != null && code.isNotEmpty) {
    try {
      return CropType.fromJson(code).label;
    } catch (_) {
      return code;
    }
  }
  return null;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final cropsAsync = ref.watch(cropsProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;

    final profile = profileAsync.value;
    final firstName = profile?.fullName.split(' ').first ?? '…';
    final municipality = profile?.municipality ?? Municipality.SANTA_MARTA;

    final weatherAsync = ref.watch(currentWeatherProvider(municipality));

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
              Row(
                children: [
                  const Icon(
                    Icons.eco,
                    color: AppColors.primaryGreen,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hola, $firstName',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.divider,
                    child: Icon(
                      Icons.person_outline,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      online ? 'Sincronizado' : 'Sin sincronizar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              weatherAsync.when(
                loading: () => const _WeatherSkeleton(),
                error: (_, _) => WeatherCard(
                  location: municipality.label,
                  source: 'Open-Meteo',
                  temperature: '--°C',
                  humidity: '--%',
                  onRetry: () {
                    ref.invalidate(currentWeatherProvider(municipality));
                    ref.invalidate(weatherDataProvider(municipality));
                  },
                ),
                data: (w) => WeatherCard(
                  location: municipality.label,
                  source: w.source,
                  temperature: w.temperatureLabel,
                  humidity: w.humidityLabel,
                  fetchedAt: w.fetchedAt,
                  onTap: () => context.pushNamed(
                    AppRoutes.homeWeatherName,
                    extra: municipality,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mis cultivos',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              cropsAsync.when(
                loading: () => const SizedBox(
                  height: 96,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (crops) => CropsChipsRow(crops: crops),
              ),
              const SizedBox(height: 24),
              Text(
                'Recomendaciones pendientes',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              cropsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (crops) {
                  if (crops.isEmpty) {
                    return const Text(
                      'Registra un cultivo para ver recomendaciones.',
                      style: TextStyle(color: AppColors.textSecondary),
                    );
                  }
                  return _RecommendationsSection(
                      crops: crops, online: online);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationsSection extends ConsumerWidget {
  const _RecommendationsSection(
      {required this.crops, required this.online});

  final List<Crop> crops;
  final bool online;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(dashboardRecommendationsProvider);

    return recsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (recs) {
        if (recs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No hay recomendaciones pendientes para tus cultivos.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (online) ...[
                const SizedBox(height: 12),
                GenerateRecommendationsButton(cropId: crops.first.id),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in recs) ...[
              RecommendationTile(
                recommendation: r,
                cropLabel: _cropLabelFor(r, crops),
                onOpenCrop: r.cropId != null && r.cropId!.isNotEmpty
                    ? () => context.pushNamed(
                          AppRoutes.cropsDetailName,
                          pathParameters: {'id': r.cropId!},
                        )
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            if (online)
              Text(
                'Para generar más recomendaciones, abre un cultivo y usa el botón allí.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
          ],
        );
      },
    );
  }
}

class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
