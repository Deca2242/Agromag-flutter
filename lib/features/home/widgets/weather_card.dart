import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({
    super.key,
    required this.location,
    required this.source,
    required this.temperature,
    required this.humidity,
    this.onRetry,
    this.fetchedAt,
    this.onTap,
  });

  final String location;
  final String source;
  final String temperature;
  final String humidity;
  /// Si se provee, se muestra un ícono de reintento cuando hay error.
  final VoidCallback? onRetry;
  /// Cuándo se obtuvo el dato; si tiene más de 15 min se muestra aviso.
  final DateTime? fetchedAt;
  /// Abre detalle del clima (p. ej. pronóstico y gráficos).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.softGreenBg,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (fetchedAt != null &&
                        DateTime.now().difference(fetchedAt!) >
                            const Duration(minutes: 15)) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Actualizado hace ${_minutesAgo(fetchedAt!)} min',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          temperature,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.water_drop_outlined,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          humidity,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (onRetry != null)
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.textSecondary,
                    size: 28,
                  ),
                  onPressed: onRetry,
                  tooltip: 'Reintentar',
                )
              else
                const Icon(
                  Icons.wb_cloudy_outlined,
                  size: 56,
                  color: AppColors.textPrimary,
                ),
            ],
          ),
        ],
      ),
    );
    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }
    return card;
  }

  static int _minutesAgo(DateTime t) =>
      DateTime.now().difference(t).inMinutes;
}
