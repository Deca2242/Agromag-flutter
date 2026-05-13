import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/branded_app_bar.dart';
import '../../../domain/models/alert.dart';
import '../../alerts/alerts_providers.dart';
import '../../crops/crops_providers.dart';
import '../home_providers.dart';
import '../widgets/crops_chips_row.dart';
import '../widgets/recommendation_tile.dart';
import '../widgets/weather_card.dart';
import 'weather_details_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final fallback = ref.watch(fallbackProfileProvider);
    final user = switch (profileAsync) {
      AsyncData(:final value) when value != null => value,
      _ => fallback,
    };
    final cropsAsync = ref.watch(cropsProvider);
    final crops = cropsAsync.value ?? [];
    final recs = ref.watch(recommendationsProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandedAppBar(online: online),
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
                      'Hola, ${user.fullName.split(' ').first}',
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
                    const Icon(
                      Icons.wifi,
                      color: Colors.white,
                      size: 16,
                    ),
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
              WeatherCard(
                location: 'Magdalena',
                source: 'Datos de Open-Meteo',
                temperature: '28°C',
                humidity: '75%',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeatherDetailsScreen(),
                    ),
                  );
                },
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
              CropsChipsRow(crops: crops),
              const SizedBox(height: 24),
              Text(
                'Recomendaciones del día',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final r in recs) ...[
                RecommendationTile(
                  recommendation: r,
                  onTap: () {
                    AlertCategory? category;
                    final titleLower = r.title.toLowerCase();
                    if (titleLower.contains('riego') || titleLower.contains('hídric')) {
                      category = AlertCategory.irrigation;
                    } else if (titleLower.contains('fertiliza') || titleLower.contains('nutri')) {
                      category = AlertCategory.fertilization;
                    } else if (titleLower.contains('fito') || titleLower.contains('plaga') || titleLower.contains('enfermedad')) {
                      category = AlertCategory.phytosanitary;
                    } else if (titleLower.contains('clima') || titleLower.contains('tempe')) {
                      category = AlertCategory.climate;
                    }

                    if (category != null) {
                      ref.read(alertsFilterProvider.notifier).state = category;
                    }
                    context.goNamed(AppRoutes.alertsName);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
