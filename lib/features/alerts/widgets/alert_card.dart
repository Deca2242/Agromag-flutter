import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/alert.dart';
import '../alerts_providers.dart';

class AlertCard extends ConsumerWidget {
  const AlertCard({super.key, required this.alert});

  final Alert alert;

  ({Color side, Color iconBg, Color iconFg}) _palette() {
    switch (alert.severity) {
      case AlertSeverity.high:
        return (
          side: AppColors.alertRed,
          iconBg: AppColors.alertRedSoft,
          iconFg: AppColors.alertRed,
        );
      case AlertSeverity.medium:
        return (
          side: AppColors.warningAmber,
          iconBg: AppColors.warningAmberSoft,
          iconFg: AppColors.warningAmberText,
        );
      case AlertSeverity.info:
        return (
          side: AppColors.primaryGreen,
          iconBg: AppColors.softGreenBg,
          iconFg: AppColors.primaryGreen,
        );
    }
  }

  Widget _buildIcon() {
    final p = _palette();
    if (alert.severity == AlertSeverity.high) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: p.iconBg,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.alertRed,
          size: 20,
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: p.iconBg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        IconData(
          alert.iconCodePoint,
          fontFamily: 'MaterialIcons',
        ),
        color: p.iconFg,
        size: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = _palette();
    final isRead = alert.isRead;

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.alertRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        ref.read(alertsProvider.notifier).deleteAlert(alert.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alerta eliminada'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isRead ? AppColors.surface.withValues(alpha: 0.6) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? AppColors.border.withValues(alpha: 0.5) : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: isRead ? 2 : 4,
                color: isRead ? p.side.withValues(alpha: 0.4) : p.side,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIcon(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        alert.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isRead
                                              ? AppColors.textSecondary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: p.side,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.timestamp,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        alert.description,
                        style: TextStyle(
                          color: isRead
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (alert.cropId != null)
                        InkWell(
                          onTap: () {
                            context.pushNamed(
                              AppRoutes.cropsDetailName,
                              pathParameters: {'id': alert.cropId!},
                            );
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.agriculture_outlined,
                                  size: 14,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  alert.cropTag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 10,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.agriculture_outlined,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                alert.cropTag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
