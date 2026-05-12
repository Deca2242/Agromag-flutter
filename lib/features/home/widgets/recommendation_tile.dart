import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/models/recommendation.dart';

class RecommendationTile extends StatelessWidget {
  const RecommendationTile({
    super.key,
    required this.recommendation,
    this.cropLabel,
    this.onOpenCrop,
    this.onTap,
  });

  final Recommendation recommendation;
  final String? cropLabel;
  final VoidCallback? onOpenCrop;
  final VoidCallback? onTap;

  StatusBadge _badge() {
    switch (recommendation.level) {
      case RecommendationLevel.moderate:
        return const StatusBadge.moderate();
      case RecommendationLevel.alert:
        return const StatusBadge.alert();
      case RecommendationLevel.optimal:
        return const StatusBadge.optimal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inner = Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: recommendation.accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: recommendation.accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              IconData(
                recommendation.iconCodePoint,
                fontFamily: 'MaterialIcons',
              ),
              color: recommendation.accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recommendation.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _badge(),
                  ],
                ),
                if (cropLabel != null && cropLabel!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    cropLabel!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  recommendation.body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (onOpenCrop != null &&
                    recommendation.cropId != null &&
                    recommendation.cropId!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onOpenCrop,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Ver cultivo'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );

    if (onTap == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: inner,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: inner,
        ),
      ),
    );
  }
}
