import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// AppBar con el branding "AgroMagdalena" + indicador de conectividad.
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({
    super.key,
    this.showMenu = true,
    this.showOfflineIcon = true,
    this.online = false,
    this.leading,
  });

  final bool showMenu;
  final bool showOfflineIcon;
  final bool online;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      leadingWidth: leading == null && showMenu ? 56 : null,
      leading: leading ??
          (showMenu
              ? IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.menu),
                  tooltip: 'Abrir menú',
                  color: AppColors.textPrimary,
                )
              : null),
      title: const Row(
        children: [
          BrandLogo(size: 28),
          SizedBox(width: 8),
          Text(
            'AgroMagdalena',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        if (showOfflineIcon)
          IconButton(
            onPressed: () {},
            tooltip: online ? 'Conectado' : 'Sin conexión',
            icon: Icon(
              online ? Icons.cloud_done_outlined : Icons.cloud_off,
              color: online ? AppColors.primaryGreen : AppColors.alertRed,
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}
