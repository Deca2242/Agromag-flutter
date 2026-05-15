import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/crop_type.dart';
import '../../../domain/models/sync_status.dart';

class CropListCard extends StatelessWidget {
  const CropListCard({super.key, required this.crop, this.onRetrySync});

  final Crop crop;

  /// Llamado cuando el usuario toca el badge de error para reintentar sync.
  final VoidCallback? onRetrySync;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: () => context.pushNamed(
        AppRoutes.cropsDetailName,
        pathParameters: {'id': crop.id},
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: crop.cropType.iconBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    crop.cropType.icon,
                    color: crop.cropType.iconForeground,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    crop.cropType.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                _SyncStatusBadge(status: crop.syncStatus, onRetry: onRetrySync),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'FECHA DE SIEMBRA',
                    value: df.format(crop.sownDate),
                  ),
                ),
                Expanded(
                  child: _Stat(label: 'ÁREA', value: '${crop.areaHectares} ha'),
                ),
                Expanded(
                  child: _Stat(
                    label: 'MUNICIPIO',
                    value: crop.municipality.label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Ver detalle',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  const _SyncStatusBadge({required this.status, this.onRetry});
  final SyncStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SyncStatus.SYNCED => const Tooltip(
        message: 'Sincronizado',
        child: Icon(
          Icons.cloud_done_outlined,
          size: 20,
          color: AppColors.primaryGreen,
        ),
      ),
      SyncStatus.PENDING => const Tooltip(
        message: 'Pendiente de sincronización',
        child: Icon(
          Icons.cloud_upload_outlined,
          size: 20,
          color: AppColors.warningAmber,
        ),
      ),
      SyncStatus.ERROR => GestureDetector(
        onTap: onRetry,
        child: Tooltip(
          message: 'Error de sincronización. Toca para reintentar.',
          child: Icon(
            Icons.cloud_off,
            size: 20,
            color: onRetry != null
                ? AppColors.alertRed
                : AppColors.textSecondary,
          ),
        ),
      ),
    };
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
