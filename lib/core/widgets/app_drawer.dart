import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import 'brand_logo.dart';
import 'primary_button.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.value;

    final routerState = GoRouterState.of(context);
    final currentLocation = routerState.matchedLocation;

    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 20,
              20,
              20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryGreenDark, AppColors.primaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandLogo(
                      size: 32,
                      background: Colors.white,
                      foreground: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Agromag',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar menú',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        profile?.initials ?? '…',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.fullName.isEmpty ?? true
                                ? 'Cargando...'
                                : profile!.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _DrawerTile(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Inicio',
                  isActive: currentLocation == AppRoutes.home,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.home);
                  },
                ),
                const SizedBox(height: 4),
                _DrawerTile(
                  icon: Icons.agriculture_outlined,
                  selectedIcon: Icons.agriculture,
                  label: 'Mis Cultivos',
                  isActive: currentLocation.startsWith(AppRoutes.crops),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.crops);
                  },
                ),
                const SizedBox(height: 4),
                _DrawerTile(
                  icon: Icons.notifications_outlined,
                  selectedIcon: Icons.notifications,
                  label: 'Alertas Climáticas',
                  isActive: currentLocation == AppRoutes.alerts,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.alerts);
                  },
                ),
                const SizedBox(height: 4),
                _DrawerTile(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Mi Perfil',
                  isActive: currentLocation.startsWith(AppRoutes.profile),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.profile);
                  },
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(color: AppColors.border),
                ),
                const SizedBox(height: 12),
                _DrawerTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'AGROBOT (Asistente)',
                  isActive: currentLocation == AppRoutes.assistant,
                  textColor: AppColors.primaryGreen,
                  iconColor: AppColors.primaryGreen,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.pushNamed(AppRoutes.assistantName);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 20,
            ),
            child: DangerButton(
              label: 'Cerrar sesión',
              icon: Icons.logout,
              onPressed: () => _signOut(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.softGreenBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
        leading: Icon(
          isActive ? selectedIcon : icon,
          color: isActive
              ? AppColors.primaryGreen
              : (iconColor ?? AppColors.textSecondary),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive
                ? AppColors.primaryGreen
                : (textColor ?? AppColors.textPrimary),
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        dense: true,
      ),
    );
  }
}
