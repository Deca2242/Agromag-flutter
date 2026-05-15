import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../domain/models/municipality.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  Municipality? _municipality;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_municipality == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona tu municipio.')));
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
          municipality: _municipality!,
        );

    if (!mounted) return;

    final errorMsg = ref.read(authControllerProvider.notifier).errorMessage;
    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.alertRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Éxito: mostrar confirmación y volver al login.
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirma tu correo'),
          content: Text(
            'Te enviamos un enlace de confirmación a '
            '${_emailCtrl.text.trim()}.\n\n'
            'Confirma tu correo y luego inicia sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) context.goNamed(AppRoutes.loginName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AdaptiveBody(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const BrandLogo(size: 64),
                  const SizedBox(height: 12),
                  Text(
                    'AgroMagdalena',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crear cuenta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AuthTextField(
                          label: 'Nombre Completo',
                          hint: 'Ej: Juan Valdez',
                          icon: Icons.person_outline,
                          controller: _nameCtrl,
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
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Correo Electrónico',
                          hint: 'juan@ejemplo.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailCtrl,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa tu correo.';
                            }
                            final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!re.hasMatch(v.trim())) {
                              return 'Correo inválido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _MunicipalityDropdown(
                          value: _municipality,
                          onChanged: (v) => setState(() => _municipality = v),
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Contraseña',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscure: true,
                          controller: _passCtrl,
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'Mínimo 6 caracteres.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          label: 'Confirmar Contraseña',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscure: true,
                          controller: _confirmCtrl,
                          validator: (v) {
                            if (v != _passCtrl.text) {
                              return 'Las contraseñas no coinciden.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Registrarme'),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => context.goNamed(AppRoutes.loginName),
                    child: Text.rich(
                      TextSpan(
                        text: '¿Ya tienes cuenta? ',
                        style: const TextStyle(color: AppColors.textSecondary),
                        children: const [
                          TextSpan(
                            text: 'Inicia sesión',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MunicipalityDropdown extends StatelessWidget {
  const _MunicipalityDropdown({required this.value, required this.onChanged});

  final Municipality? value;
  final ValueChanged<Municipality?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Municipio', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        DropdownButtonFormField<Municipality>(
          initialValue: value,
          decoration: const InputDecoration(hintText: 'Seleccionar...'),
          items: Municipality.values
              .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
              .toList(),
          onChanged: onChanged,
          validator: (v) => v == null ? 'Selecciona tu municipio.' : null,
        ),
      ],
    );
  }
}
