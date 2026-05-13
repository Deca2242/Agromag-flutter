import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/models/recommendation.dart';

class RecommendationTile extends StatelessWidget {
  const RecommendationTile({super.key, required this.recommendation, this.onTap});

  final Recommendation recommendation;
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
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
                  const SizedBox(height: 4),
                  Text(
                    recommendation.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.3,
                    ),
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
