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
    final icon = switch (alert.category) {
      AlertCategory.irrigation => Icons.water_drop,
      AlertCategory.fertilization => Icons.eco,
      AlertCategory.phytosanitary => Icons.bug_report,
      AlertCategory.climate => Icons.cloud_outlined,
    };
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
        icon,
        color: p.iconFg,
        size: 18,
      ),
    );
  }

  String _recommendedAction() {
    return switch (alert.category) {
      AlertCategory.irrigation =>
        'Revisa la humedad del suelo, evita encharcamientos y registra el riego si lo realizas.',
      AlertCategory.fertilization =>
        'Valida la etapa del cultivo, revisa si tienes análisis de suelo y registra cualquier aplicación.',
      AlertCategory.phytosanitary =>
        'Inspecciona hojas, tallos y frutos. Si ves síntomas, registra una observación y consulta a un técnico local.',
      AlertCategory.climate =>
        'Monitorea el cultivo durante el día y registra cambios relevantes en la app.',
    };
  }

  void _showDetails(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final p = _palette();
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIcon(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
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
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(label: alert.severity.label, color: p.side),
                      _DetailChip(label: alert.category.label, color: AppColors.primaryGreen),
                      _DetailChip(
                        label: alert.isRead ? 'Leída' : 'No leída',
                        color: alert.isRead ? AppColors.textMuted : p.side,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(title: 'Cultivo', body: alert.cropTag),
                  _DetailSection(title: 'Detalle', body: alert.description),
                  _DetailSection(title: 'Acción sugerida', body: _recommendedAction()),
                  const SizedBox(height: 12),
                  if (!alert.isRead)
                    FilledButton.icon(
                      onPressed: () {
                        ref.read(alertsProvider.notifier).markAsRead(alert.id);
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.done_outlined),
                      label: const Text('Marcar como leída'),
                    ),
                  if (alert.cropId != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.pushNamed(
                          AppRoutes.cropsDetailName,
                          pathParameters: {'id': alert.cropId!},
                        );
                      },
                      icon: const Icon(Icons.agriculture_outlined),
                      label: const Text('Ir al cultivo'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
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
                      TextButton.icon(
                        onPressed: () => _showDetails(context, ref),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Más detalle'),
                      ),
                      const SizedBox(height: 4),
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
