import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/alert.dart';
import '../alerts_providers.dart';

class AlertFilterChips extends ConsumerWidget {
  const AlertFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(alertsFilterProvider);

    final entries = <(AlertCategory?, String)>[
      (null, 'Todas'),
      (AlertCategory.irrigation, 'Riego'),
      (AlertCategory.fertilization, 'Fertilización'),
      (AlertCategory.phytosanitary, 'Fitosanitario'),
      (AlertCategory.climate, 'Clima'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (category, label) = entries[i];
          final isSelected = category == selected;
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) =>
                ref.read(alertsFilterProvider.notifier).state = category,
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.softGreenBg,
            side: BorderSide(
              color: isSelected ? AppColors.primaryGreen : AppColors.border,
            ),
            labelStyle: TextStyle(
              color: isSelected
                  ? AppColors.primaryGreenDark
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}
