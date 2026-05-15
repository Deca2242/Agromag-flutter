import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pastilla con color dependiente del estado/severidad mostrado.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  const StatusBadge.active({super.key})
    : label = 'Activo',
      background = AppColors.primaryGreen,
      foreground = Colors.white;

  const StatusBadge.monitoring({super.key})
    : label = 'Seguimiento',
      background = AppColors.softGreenBg,
      foreground = AppColors.primaryGreenDark;

  const StatusBadge.harvested({super.key})
    : label = 'Cosechado',
      background = AppColors.divider,
      foreground = AppColors.textSecondary;

  const StatusBadge.alert({super.key})
    : label = 'ALERTA',
      background = AppColors.alertRedSoft,
      foreground = AppColors.alertRed;

  const StatusBadge.moderate({super.key})
    : label = 'MODERADO',
      background = AppColors.warningAmberSoft,
      foreground = AppColors.warningAmberText;

  const StatusBadge.optimal({super.key})
    : label = 'ÓPTIMO',
      background = AppColors.softGreenBg,
      foreground = AppColors.primaryGreenDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
