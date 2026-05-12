import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/crop_type.dart';

class CropsChipsRow extends StatelessWidget {
  const CropsChipsRow({super.key, required this.crops});

  final List<Crop> crops;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crops.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == crops.length) {
            return _NewCropTile(
              onTap: () => context.pushNamed(AppRoutes.cropsNewName),
            );
          }
          return _CropTile(crop: crops[index]);
        },
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: () => context.pushNamed(
          AppRoutes.cropsDetailName,
          pathParameters: {'id': crop.id},
        ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: crop.cropType.iconBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                crop.cropType.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              crop.cropType.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCropTile extends StatelessWidget {
  const _NewCropTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nuevo',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
