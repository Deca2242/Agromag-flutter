import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'ai_fab.dart';

/// Shell con la `NavigationBar` inferior que persiste a través de las
/// 4 pestañas principales. Sigue la skill `flutter-setup-declarative-routing`.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFab = navigationShell.currentIndex != 1;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: showFab ? const AiFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.softGreenBg,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryGreen),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.agriculture_outlined),
            selectedIcon:
                Icon(Icons.agriculture, color: AppColors.primaryGreen),
            label: 'Cultivos',
          ),
          NavigationDestination(
            icon: _AlertsIcon(showDot: true),
            selectedIcon: Icon(
              Icons.notifications,
              color: AppColors.primaryGreen,
            ),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryGreen),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _AlertsIcon extends StatelessWidget {
  const _AlertsIcon({required this.showDot});

  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (showDot)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.alertRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
