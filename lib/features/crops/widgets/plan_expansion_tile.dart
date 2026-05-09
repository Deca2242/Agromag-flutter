import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PlanExpansionTile extends StatelessWidget {
  const PlanExpansionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.children = const [],
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          children: children.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'No hay actividades programadas en este plan.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ]
              : children,
        ),
      ),
    );
  }
}
