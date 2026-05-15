import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tarjeta blanca con borde sutil usada como contenedor de secciones.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: border ? Border.all(color: AppColors.border) : null,
      ),
      child: child,
    );
  }
}
