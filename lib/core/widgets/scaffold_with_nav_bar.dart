import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/alerts_providers.dart';
import '../../features/home/home_providers.dart';
import '../../features/sync/sync_coordinator.dart';
import '../theme/app_colors.dart';
import 'ai_fab.dart';

/// Shell con la `NavigationBar` inferior que persiste a través de las
/// 4 pestañas principales. Sigue la skill `flutter-setup-declarative-routing`.
class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with WidgetsBindingObserver {
  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final online = ref.read(isOnlineProvider).value ?? false;
    if (!online) return;
    ref.read(syncCoordinatorProvider.notifier).requestSync();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncBootstrapProvider);
    final navigationShell = widget.navigationShell;
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
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryGreen),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.agriculture_outlined),
            selectedIcon: Icon(
              Icons.agriculture,
              color: AppColors.primaryGreen,
            ),
            label: 'Cultivos',
          ),
          NavigationDestination(
            icon: Consumer(
              builder: (context, ref, _) {
                final countAsync = ref.watch(alertsUnreadCountProvider);
                final count = countAsync.value?.total ?? 0;
                return _AlertsIcon(showDot: count > 0, count: count);
              },
            ),
            selectedIcon: const Icon(
              Icons.notifications,
              color: AppColors.primaryGreen,
            ),
            label: 'Alertas',
          ),
          const NavigationDestination(
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
  const _AlertsIcon({required this.showDot, this.count = 0});

  final bool showDot;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (showDot && count > 1)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.alertRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (showDot)
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
