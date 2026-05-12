import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/alerts/view/alerts_screen.dart';
import '../../features/assistant/view/assistant_screen.dart';
import '../../features/auth/view/forgot_password_screen.dart';
import '../../features/auth/view/login_screen.dart';
import '../../features/auth/view/register_screen.dart';
import '../../features/crops/view/crop_detail_screen.dart';
import '../../features/crops/view/crops_list_screen.dart';
import '../../features/crops/view/edit_crop_screen.dart';
import '../../features/crops/view/new_crop_screen.dart';
import '../../features/home/view/home_screen.dart';
import '../../features/profile/view/edit_profile_screen.dart';
import '../../features/profile/view/profile_screen.dart';
import '../../features/splash/view/splash_screen.dart';
import '../widgets/scaffold_with_nav_bar.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavHomeKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _shellNavCropsKey = GlobalKey<NavigatorState>(debugLabel: 'crops');
final _shellNavAlertsKey = GlobalKey<NavigatorState>(debugLabel: 'alerts');
final _shellNavProfileKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final appRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthChangeNotifier();

  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loggedIn = session != null;

      final loc = state.matchedLocation;

      // Splash: siempre pasa, decide sola.
      if (loc == AppRoutes.splash) return null;

      final goingToAuth = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;

      if (!loggedIn && !goingToAuth) return AppRoutes.login;
      if (loggedIn && goingToAuth) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotName,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.assistant,
        name: AppRoutes.assistantName,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AssistantScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavHomeKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavCropsKey,
            routes: [
              GoRoute(
                path: AppRoutes.crops,
                name: AppRoutes.cropsName,
                builder: (context, state) => const CropsListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: AppRoutes.cropsNewName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const NewCropScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: AppRoutes.cropsDetailName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return CropDetailScreen(cropId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: AppRoutes.cropsEditName,
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final crop =
                              state.extra as dynamic;
                          return EditCropScreen(crop: crop);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavAlertsKey,
            routes: [
              GoRoute(
                path: AppRoutes.alerts,
                name: AppRoutes.alertsName,
                builder: (context, state) => const AlertsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavProfileKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: AppRoutes.profileEditName,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Hace que GoRouter reaccione al stream de cambios de sesión de Supabase.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
