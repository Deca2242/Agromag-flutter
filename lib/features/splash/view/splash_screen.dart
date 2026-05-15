import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';

/// Pantalla de carga inicial.
///
/// Espera a que Supabase emita el estado inicial de auth (sesión restaurada
/// desde disco) antes de enrutar a /home o /login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<Session?> _resolveInitialSession() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session != null) return session;

    try {
      final ev = await auth.onAuthStateChange.first.timeout(
        const Duration(seconds: 2),
      );
      session = ev.session ?? auth.currentSession;
    } on TimeoutException {
      session = auth.currentSession;
    } catch (_) {
      session = auth.currentSession;
    }
    return session ?? auth.currentSession;
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final session = await _resolveInitialSession();
    if (!mounted) return;

    if (session != null) {
      context.goNamed(AppRoutes.homeName);
    } else {
      context.goNamed(AppRoutes.loginName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(
                    size: 96,
                    background: Color(0x33FFFFFF),
                    foreground: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'AgroMagdalena',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UNIVERSIDAD DEL MAGDALENA',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Divider(color: Colors.white54, thickness: 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
