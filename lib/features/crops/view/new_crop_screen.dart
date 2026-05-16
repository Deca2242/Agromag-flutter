import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/models/crop_type.dart';
import '../../../domain/models/municipality.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/home_providers.dart';
import '../../sync/sync_coordinator.dart';
import '../crops_providers.dart';

class NewCropScreen extends ConsumerStatefulWidget {
  const NewCropScreen({super.key});

  @override
  ConsumerState<NewCropScreen> createState() => _NewCropScreenState();
}

class _NewCropScreenState extends ConsumerState<NewCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaCtrl = TextEditingController();

  CropType? _cropType;
  Municipality? _municipality;
  DateTime? _sownDate;
  bool _saving = false;

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cropType == null || _municipality == null || _sownDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final session = ref.read(authSessionProvider).value;
      if (session == null) throw Exception('Sin sesión');

      final crop = await ref
          .read(cropsRepositoryProvider)
          .createCropOffline(
            profileId: session.user.id,
            cropType: _cropType!,
            areaHectares: double.parse(_areaCtrl.text.replaceAll(',', '.')),
            municipality: _municipality!,
            sownDate: _sownDate!,
          );

      // Invalida el provider para que la lista se refresque.
      ref.invalidate(cropsProvider);
      ref.read(syncCoordinatorProvider.notifier).scheduleDebouncedSync();

      if (mounted) {
        final online = ref.read(isOnlineProvider).value ?? true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              online
                  ? 'Cultivo guardado y sincronizando…'
                  : 'Guardado localmente. Se sincronizará cuando vuelva la conexión.',
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(crop);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
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
    final online = ref.watch(isOnlineProvider).value ?? true;

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              online ? Icons.cloud_done_outlined : Icons.cloud_off,
              color: online ? AppColors.primaryGreen : AppColors.alertRed,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Nuevo Cultivo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Registra los detalles de tu nueva siembra para llevar '
                  'un control preciso.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _IdentificationCard(
                  cropType: _cropType,
                  onCropTypeChanged: (v) => setState(() => _cropType = v),
                ),
                const SizedBox(height: 16),
                _TerrainCard(
                  areaCtrl: _areaCtrl,
                  municipality: _municipality,
                  onMunicipalityChanged: (v) =>
                      setState(() => _municipality = v),
                ),
                const SizedBox(height: 16),
                _DateCard(
                  sownDate: _sownDate,
                  onDateChanged: (d) => setState(() => _sownDate = d),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _saving ? 'Guardando…' : 'Guardar cultivo',
                  icon: Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        online ? Icons.sync : Icons.cloud_off,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Se guardará localmente aunque no tengas conexión',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _IdentificationCard extends StatelessWidget {
  const _IdentificationCard({
    required this.cropType,
    required this.onCropTypeChanged,
  });

  final CropType? cropType;
  final ValueChanged<CropType?> onCropTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(icon: Icons.eco, label: 'Identificación'),
          const SizedBox(height: 14),
          const _Label('Tipo de cultivo *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<CropType>(
            initialValue: cropType,
            decoration: const InputDecoration(hintText: 'Selecciona un tipo'),
            items: CropType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: onCropTypeChanged,
            validator: (v) =>
                v == null ? 'Selecciona el tipo de cultivo.' : null,
          ),
        ],
      ),
    );
  }
}

class _TerrainCard extends StatelessWidget {
  const _TerrainCard({
    required this.areaCtrl,
    required this.municipality,
    required this.onMunicipalityChanged,
  });

  final TextEditingController areaCtrl;
  final Municipality? municipality;
  final ValueChanged<Municipality?> onMunicipalityChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(icon: Icons.terrain, label: 'Detalles del Terreno'),
          const SizedBox(height: 14),
          const _Label('Área (Hectáreas) *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: areaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(hintText: 'Ej: 2.5'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa el área.';
              }
              final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) {
                return 'Ingresa un valor mayor a 0.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          const _Label('Municipio *'),
          const SizedBox(height: 6),
          DropdownButtonFormField<Municipality>(
            initialValue: municipality,
            decoration: const InputDecoration(
              hintText: 'Selecciona un municipio',
            ),
            isExpanded: true,
            items: Municipality.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: onMunicipalityChanged,
            validator: (v) => v == null ? 'Selecciona el municipio.' : null,
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.sownDate, required this.onDateChanged});

  final DateTime? sownDate;
  final ValueChanged<DateTime> onDateChanged;

  String _formatDate() {
    if (sownDate == null) return 'Seleccionar fecha';
    return DateFormat('dd/MM/yyyy').format(sownDate!);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            icon: Icons.calendar_today_outlined,
            label: 'Fecha de Siembra',
          ),
          const SizedBox(height: 14),
          const _Label('Fecha de siembra *'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: sownDate ?? now,
                firstDate: DateTime(2000),
                lastDate: now,
              );
              if (picked != null) onDateChanged(picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: sownDate == null ? null : null, // validator manual
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(),
                      style: TextStyle(
                        color: sownDate == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}
