import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/crop_type.dart';
import '../../../domain/models/municipality.dart';
import '../../auth/providers/auth_providers.dart';
import '../../home/home_providers.dart';
import '../../sync/sync_coordinator.dart';
import '../crops_providers.dart';
import '../widgets/crop_form_body.dart';

class EditCropScreen extends ConsumerStatefulWidget {
  const EditCropScreen({super.key, required this.crop});

  final Crop crop;

  @override
  ConsumerState<EditCropScreen> createState() => _EditCropScreenState();
}

class _EditCropScreenState extends ConsumerState<EditCropScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _areaCtrl;

  late CropType? _cropType;
  late Municipality? _municipality;
  late DateTime? _sownDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cropType = widget.crop.cropType;
    _municipality = widget.crop.municipality;
    _sownDate = widget.crop.sownDate;
    _areaCtrl = TextEditingController(
      text: widget.crop.areaHectares.toString(),
    );
  }

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

      final updated = widget.crop.copyWith(
        cropType: _cropType,
        areaHectares: double.parse(_areaCtrl.text.replaceAll(',', '.')),
        municipality: _municipality,
        sownDate: _sownDate,
      );

      await ref
          .read(cropsRepositoryProvider)
          .updateCrop(updated, profileId: session.user.id);

      ref.invalidate(cropsProvider);
      ref.read(syncCoordinatorProvider.notifier).scheduleDebouncedSync();

      if (mounted) {
        final isOnline = ref.read(isOnlineProvider).value ?? true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isOnline
                  ? 'Cultivo actualizado.'
                  : 'Guardado localmente. Se sincronizará cuando vuelva la conexión.',
            ),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No se pudo actualizar el cultivo. Intenta nuevamente.',
            ),
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
                  'Editar Cultivo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Modifica los detalles de tu cultivo.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                CropFormBody(
                  areaCtrl: _areaCtrl,
                  cropType: _cropType,
                  municipality: _municipality,
                  sownDate: _sownDate,
                  onCropTypeChanged: (v) => setState(() => _cropType = v),
                  onMunicipalityChanged: (v) =>
                      setState(() => _municipality = v),
                  onDateChanged: (d) => setState(() => _sownDate = d),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: _saving ? 'Guardando…' : 'Guardar cambios',
                  icon: Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
