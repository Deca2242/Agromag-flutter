import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/agronomic_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/mock/mock_crops.dart'; // keeping it just in case, but probably not needed for crops anymore
import '../../../domain/models/crop.dart';
import '../crops_providers.dart';
import 'package:geolocator/geolocator.dart';

class NewCropScreen extends ConsumerStatefulWidget {
  const NewCropScreen({super.key});

  @override
  ConsumerState<NewCropScreen> createState() => _NewCropScreenState();
}

class _NewCropScreenState extends ConsumerState<NewCropScreen> {
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _locationController = TextEditingController();
  final _densityController = TextEditingController();

  String? _cropType;
  String? _soilType;
  String? _irrigationSystem;
  DateTime? _plantedAt;

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _locationController.dispose();
    _densityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              'AgroMagdalena',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.cloud_off, color: AppColors.alertRed),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Nuevo Cultivo',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
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
                nameController: _nameController,
                onCropTypeChanged: (v) => setState(() => _cropType = v),
              ),
              const SizedBox(height: 16),
              _TerrainCard(
                soilType: _soilType,
                areaController: _areaController,
                densityController: _densityController,
                locationController: _locationController,
                onSoilTypeChanged: (v) => setState(() => _soilType = v),
              ),
              const SizedBox(height: 16),
              _ManagementCard(
                irrigationSystem: _irrigationSystem,
                plantedAt: _plantedAt,
                onIrrigationChanged: (v) =>
                    setState(() => _irrigationSystem = v),
                onDateChanged: (d) => setState(() => _plantedAt = d),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Guardar cultivo',
                icon: Icons.save_outlined,
                onPressed: () {
                  if (_cropType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Por favor selecciona un tipo de cultivo')),
                    );
                    return;
                  }
                  
                  final newCrop = Crop(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: _nameController.text.isNotEmpty ? _nameController.text : 'Lote ${_cropType}',
                    type: _cropType!,
                    lot: _locationController.text.isNotEmpty ? _locationController.text : 'Principal',
                    stage: 'Siembra',
                    areaHa: double.tryParse(_areaController.text) ?? 1.0,
                    plantingDensity: double.tryParse(_densityController.text) ?? 0.0,
                    plantedAt: _plantedAt ?? DateTime.now(),
                    status: CropStatus.active,
                    iconCodePoint: Icons.eco.codePoint,
                    iconBackground: const Color(0xFFE8F5E9),
                    iconForeground: const Color(0xFF1F7A3A),
                    imageEmoji: '🌱',
                  );

                  ref.read(cropsProvider.notifier).addCrop(newCrop);
                  context.pop();
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.sync,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
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
    );
  }
}

class _IdentificationCard extends StatelessWidget {
  const _IdentificationCard({
    required this.cropType,
    required this.nameController,
    required this.onCropTypeChanged,
  });

  final String? cropType;
  final TextEditingController nameController;
  final ValueChanged<String?> onCropTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(icon: Icons.eco, label: 'Identificación'),
          const SizedBox(height: 14),
          const _Label('Nombre personalizado'),
          const SizedBox(height: 6),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Ej: Lote San Juan'),
          ),
          const SizedBox(height: 14),
          const _Label('Tipo de cultivo'),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<String>(
                initialSelection: cropType,
                hintText: 'Selecciona o busca un tipo',
                width: constraints.maxWidth,
                menuHeight: 250,
                requestFocusOnTap: true,
                dropdownMenuEntries: kComprehensiveCropTypes
                    .map((t) => DropdownMenuEntry(value: t, label: t))
                    .toList(),
                onSelected: onCropTypeChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TerrainCard extends StatelessWidget {
  const _TerrainCard({
    required this.soilType,
    required this.areaController,
    required this.densityController,
    required this.locationController,
    required this.onSoilTypeChanged,
  });

  final String? soilType;
  final TextEditingController areaController;
  final TextEditingController densityController;
  final TextEditingController locationController;
  final ValueChanged<String?> onSoilTypeChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(icon: Icons.terrain, label: 'Detalles del Terreno'),
          const SizedBox(height: 14),
          const _Label('Área (Hectáreas)'),
          const SizedBox(height: 6),
          TextField(
            controller: areaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '0.0'),
          ),
          const _Label('Densidad de siembra (Plantas/Ha)'),
          const SizedBox(height: 6),
          TextField(
            controller: densityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Ej: 10000'),
          ),
          const SizedBox(height: 14),
          const _Label('Ubicación (Coordenadas o Vereda)'),
          const SizedBox(height: 6),
          TextField(
            controller: locationController,
            decoration: InputDecoration(
              hintText: 'Sector, Vereda o GPS',
              suffixIcon: Semantics(
                label: 'Detectar ubicación con GPS',
                button: true,
                child: IconButton(
                  onPressed: () async {
                    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) return;
                    LocationPermission permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) return;
                    }
                    if (permission == LocationPermission.deniedForever) return;
                    
                    final position = await Geolocator.getCurrentPosition();
                    locationController.text = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
                  },
                  icon: const Icon(
                    Icons.gps_fixed,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Label('Tipo de suelo'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: soilType,
            decoration: const InputDecoration(hintText: 'Selecciona un tipo'),
            items: kUSDA_SoilTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: onSoilTypeChanged,
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.irrigationSystem,
    required this.plantedAt,
    required this.onIrrigationChanged,
    required this.onDateChanged,
  });

  final String? irrigationSystem;
  final DateTime? plantedAt;
  final ValueChanged<String?> onIrrigationChanged;
  final ValueChanged<DateTime> onDateChanged;

  String _formatDate() {
    if (plantedAt == null) return 'mm/dd/yyyy';
    final m = plantedAt!.month.toString().padLeft(2, '0');
    final d = plantedAt!.day.toString().padLeft(2, '0');
    return '$m/$d/${plantedAt!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title(
            icon: Icons.water_drop_outlined,
            label: 'Manejo y Fechas',
          ),
          const SizedBox(height: 14),
          const _Label('Sistema de riego'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: irrigationSystem,
            decoration:
                const InputDecoration(hintText: 'Selecciona un sistema'),
            items: kIrrigationSystems
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: onIrrigationChanged,
          ),
          const SizedBox(height: 14),
          const _Label('Fecha de siembra'),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: plantedAt ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) onDateChanged(picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(),
                      style: TextStyle(
                        color: plantedAt == null
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
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
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
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}
