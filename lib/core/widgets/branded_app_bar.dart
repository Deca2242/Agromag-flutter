import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// AppBar con el branding "Agromag" + indicador de conectividad.
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({
    super.key,
    this.showMenu = true,
    this.showOfflineIcon = true,
    this.online = false,
    this.leading,
    this.pendingCount = 0,
    this.isSyncing = false,
    this.onSyncTap,
    this.actions,
  });

  final bool showMenu;
  final bool showOfflineIcon;
  final bool online;
  final Widget? leading;

  /// Número de elementos pendientes de sincronizar (badge).
  final int pendingCount;

  /// Mientras el coordinador ejecuta [requestSync].
  final bool isSyncing;

  /// Sincronización manual; si es null no se muestra el botón de sync.
  final VoidCallback? onSyncTap;

  /// Widgets adicionales al final del AppBar (antes de los iconos de sync/red).
  final List<Widget>? actions;

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
      leading:
          leading ??
          (showMenu
              ? IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.menu),
                  tooltip: 'Abrir menú',
                  color: AppColors.textPrimary,
                )
              : null),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 28),
            const SizedBox(width: 8),
            const Text(
              'Agromag',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (actions != null) ...actions!,
        if (onSyncTap != null)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: isSyncing ? null : onSyncTap,
                tooltip: isSyncing
                    ? 'Sincronizando…'
                    : pendingCount > 0
                    ? '$pendingCount pendiente(s). Toca para sincronizar.'
                    : 'Sincronizar',
                icon: isSyncing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    : Icon(
                        pendingCount > 0
                            ? Icons.cloud_upload_outlined
                            : Icons.sync,
                        color: pendingCount > 0
                            ? AppColors.warningAmber
                            : AppColors.primaryGreen,
                      ),
              ),
              if (pendingCount > 0 && !isSyncing)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.alertRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
