import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo de hoja redondeado usado en AppBar, Splash y pantallas de auth.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 32,
    this.background = AppColors.primaryGreen,
    this.foreground = Colors.white,
    this.rounded = true,
  });

  final double size;
  final Color background;
  final Color foreground;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(rounded ? size * 0.28 : 0),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.eco,
        color: foreground,
        size: size * 0.6,
      ),
    );
  }
}
