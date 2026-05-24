import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/branded_app_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../domain/models/profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../crops/crops_providers.dart';
import '../../home/home_providers.dart';
import '../../sync/sync_coordinator.dart';
import '../widgets/profile_section_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final online = ref.watch(isOnlineProvider).value ?? true;
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandedAppBar(
        online: online,
        pendingCount: pendingCount,
        isSyncing: ref.watch(syncCoordinatorProvider),
        onSyncTap: () => requestSyncFromAppBar(context, ref),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('No se pudo cargar el perfil.')),
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Sin sesión activa.'));
              }
              return _ProfileBody(profile: profile, ref: ref, online: online);
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.ref,
    required this.online,
  });

  final Profile profile;
  final WidgetRef ref;
  final bool online;

  Future<void> _signOut(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).signOut();
    // El redirect del router navega al login automáticamente.
  }

  void _showAboutAgromag(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Agromag',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(
        Icons.eco,
        color: AppColors.primaryGreen,
        size: 40,
      ),
      children: const [
        Text(
          'Agromag es una aplicación móvil offline-first creada para apoyar '
          'a productores agrícolas del Magdalena en la gestión de sus cultivos, '
          'actividades de campo, recomendaciones, alertas climáticas y asistencia '
          'con AGROBOT.',
        ),
        SizedBox(height: 12),
        Text(
          'La app permite registrar cultivos, consultar clima, recibir '
          'recomendaciones agronómicas, manejar alertas y conservar datos '
          'localmente cuando no hay conexión. Al reconectarse, la información '
          'se sincroniza con el backend de forma segura.',
        ),
        SizedBox(height: 12),
        Text(
          'AGROBOT usa el contexto registrado en la app para responder preguntas '
          'sobre cultivos, alertas, recomendaciones y labores de campo. Si se '
          'habilita búsqueda web, solo usa consultas agronómicas sanitizadas, '
          'sin enviar datos privados del productor.',
        ),
        SizedBox(height: 12),
        Text(
          'Tus cultivos, eventos, alertas y recomendaciones pertenecen a tu cuenta. '
          'Agromag está diseñado para que cada productor acceda únicamente a su '
          'propia información.',
        ),
        SizedBox(height: 12),
        Text('Agromag MVP - Magdalena, Colombia'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            profile.fullName.isEmpty ? profile.email : profile.fullName,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                profile.municipality.label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.softGreenBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              profile.role.name == 'ADR_TECHNICIAN'
                  ? 'Técnico ADR'
                  : 'Productor Independiente',
              style: const TextStyle(
                color: AppColors.primaryGreenDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ProfileSectionGroup(
          title: 'Mi cuenta',
          children: [
            ProfileSectionTile(
              icon: Icons.person_outline,
              title: 'Editar datos personales',
              onTap: () => context.push(AppRoutes.profileEdit),
            ),
            ProfileSectionTile(
              icon: Icons.lock_outline,
              title: 'Cambiar contraseña',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProfileSectionGroup(
          title: 'Datos',
          children: [
            ProfileSectionTile(
              icon: Icons.sync,
              title: 'Sincronizar ahora',
              subtitle: profile.syncedAt != null
                  ? 'Última vez: ${_formatDate(profile.syncedAt!)}'
                  : 'Sin sincronizar',
              trailing: const SizedBox.shrink(),
              onTap: () => requestSyncFromAppBar(context, ref),
            ),
            ProfileSectionTile(
              icon: Icons.storage_outlined,
              title: 'Ver datos guardados',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProfileSectionGroup(
          title: 'Aplicación',
          children: [
            ProfileSectionTile(
              icon: Icons.info_outline,
              title: 'Acerca de Agromag',
              onTap: () => _showAboutAgromag(context),
            ),
            ProfileSectionTile(
              icon: Icons.smartphone,
              title: 'Versión',
              trailing: const Text(
                '1.0.0',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        DangerButton(
          label: 'Cerrar sesión',
          icon: Icons.logout,
          onPressed: () => _signOut(context),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return 'Hoy, $hh:$mm';
  }
}
