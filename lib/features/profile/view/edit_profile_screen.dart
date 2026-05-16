import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../domain/models/municipality.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/home_providers.dart';
import '../../sync/sync_coordinator.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  Municipality? _municipality;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) return;
    _nameCtrl.text = profile.fullName;
    _municipality = profile.municipality;
    _initialized = true;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_municipality == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona tu municipio.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            fullName: _nameCtrl.text.trim(),
            municipality: _municipality!,
          );
      ref.invalidate(currentProfileProvider);
      ref.read(syncCoordinatorProvider.notifier).scheduleDebouncedSync();

      if (mounted) {
        final isOnline = ref.read(isOnlineProvider).value ?? false;
        final msg = isOnline
            ? 'Datos actualizados.'
            : 'Guardado localmente. Se sincronizará cuando vuelva la conexión.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: AppColors.alertRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    // Inicializa campos cuando el perfil esté disponible.
    profileAsync.whenData((_) => _initFromProfile());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            BrandLogo(size: 24),
            SizedBox(width: 8),
            Text(
              'Agromag',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) =>
                const Center(child: Text('No se pudo cargar el perfil.')),
            data: (_) => _EditForm(
              formKey: _formKey,
              nameCtrl: _nameCtrl,
              municipality: _municipality,
              onMunicipalityChanged: (v) => setState(() => _municipality = v),
              saving: _saving,
              onSave: _save,
              email: ref.read(currentProfileProvider).value?.email ?? '',
              role: ref.read(currentProfileProvider).value?.role.name ?? '',
            ),
          ),
        ),
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.nameCtrl,
    required this.municipality,
    required this.onMunicipalityChanged,
    required this.saving,
    required this.onSave,
    required this.email,
    required this.role,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final Municipality? municipality;
  final ValueChanged<Municipality?> onMunicipalityChanged;
  final bool saving;
  final VoidCallback onSave;
  final String email;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            'Editar datos personales',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Actualiza tu nombre y municipio.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          // Campos solo lectura
          _ReadOnlyField(label: 'Correo electrónico', value: email),
          const SizedBox(height: 16),
          _ReadOnlyField(
            label: 'Rol',
            value: role == 'ADR_TECHNICIAN'
                ? 'Técnico ADR'
                : 'Productor Independiente',
          ),
          const SizedBox(height: 24),
          // Campos editables
          const Text(
            'Nombre completo *',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ej: Juan Valdez'),
            validator: (v) {
              if (v == null || v.trim().length < 2) {
                return 'Mínimo 2 caracteres.';
              }
              if (v.trim().length > 100) {
                return 'Máximo 100 caracteres.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Municipio *',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Municipality>(
            initialValue: municipality,
            isExpanded: true,
            decoration: const InputDecoration(hintText: 'Seleccionar…'),
            items: Municipality.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: onMunicipalityChanged,
            validator: (v) => v == null ? 'Selecciona tu municipio.' : null,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: saving ? 'Guardando…' : 'Guardar cambios',
            icon: Icons.save_outlined,
            onPressed: saving ? null : onSave,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
