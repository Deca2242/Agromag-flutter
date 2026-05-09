import 'package:flutter/material.dart';

import '../../domain/models/crop.dart';

final List<Crop> kMockCrops = [
  Crop(
    id: 'mango-lote-a',
    name: 'Mango Lote A',
    type: 'Mango',
    lot: 'Lote A, Finca El Sol',
    stage: 'Producción',
    areaHa: 2.5,
    plantedAt: DateTime(2022, 3, 15),
    status: CropStatus.active,
    iconCodePoint: Icons.eco.codePoint,
    iconBackground: const Color(0xFFE8F5E9),
    iconForeground: const Color(0xFF1F7A3A),
    imageEmoji: '🥭',
  ),
  Crop(
    id: 'maiz-norte',
    name: 'Maíz Norte',
    type: 'Maíz',
    lot: 'Lote 2, Finca El Norte',
    stage: 'Crecimiento',
    areaHa: 5.0,
    plantedAt: DateTime(2023, 8, 10),
    status: CropStatus.monitoring,
    iconCodePoint: Icons.grass.codePoint,
    iconBackground: const Color(0xFFFFF6DD),
    iconForeground: const Color(0xFF8A6D00),
    imageEmoji: '🌽',
  ),
  Crop(
    id: 'yuca-sur',
    name: 'Yuca Sur',
    type: 'Yuca',
    lot: 'Lote Sur, Finca La Esperanza',
    stage: 'Cosechado',
    areaHa: 1.2,
    plantedAt: DateTime(2023, 1, 5),
    status: CropStatus.harvested,
    iconCodePoint: Icons.spa.codePoint,
    iconBackground: const Color(0xFFEDEFF1),
    iconForeground: const Color(0xFF6B6B6B),
    imageEmoji: '🌿',
  ),
  Crop(
    id: 'tomate-chonto',
    name: 'Tomate Chonto',
    type: 'Tomate',
    lot: 'Lote 3, Finca El Sol',
    stage: 'Crecimiento',
    areaHa: 0.8,
    plantedAt: DateTime(2024, 2, 20),
    status: CropStatus.active,
    iconCodePoint: Icons.local_florist.codePoint,
    iconBackground: const Color(0xFFFDECEC),
    iconForeground: const Color(0xFFC62828),
    imageEmoji: '🍅',
  ),
];

const List<String> kCropTypes = [
  'Banano',
  'Café',
  'Cacao',
  'Maíz',
  'Mango',
  'Palma',
  'Plátano',
  'Tomate',
  'Yuca',
];

const List<String> kSoilTypes = [
  'Arcilloso',
  'Arenoso',
  'Franco',
  'Limoso',
];

const List<String> kIrrigationSystems = [
  'Goteo',
  'Aspersión',
  'Gravedad',
  'Manual',
];
