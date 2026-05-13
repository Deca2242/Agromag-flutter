import 'dart:ui';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/crop.dart';
import 'local_db.dart';

class CropLocalDao {
  const CropLocalDao();

  Database get _db => LocalDb.instance.db;

  Future<void> insert(Crop crop) async {
    await _db.insert(
      'crops',
      _toMap(crop),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Crop>> getAll() async {
    final maps = await _db.query('crops');
    return maps.map(_fromMap).toList();
  }

  Future<void> clear() async {
    await _db.delete('crops');
  }

  Map<String, dynamic> _toMap(Crop crop) {
    // Para versiones modernas de Flutter, .value puede estar deprecado en favor de .toARGB32()
    // pero .value es seguro si el proyecto aún no se ha actualizado a Flutter > 3.24
    return {
      'id': crop.id,
      'name': crop.name,
      'type': crop.type,
      'variety': '', // Mantenemos la columna en BD por compatibilidad pero vacía
      'lot': crop.lot,
      'stage': crop.stage,
      'area_ha': crop.areaHa,
      'planting_density': crop.plantingDensity,
      'planted_at': crop.plantedAt.toIso8601String(),
      'status': crop.status.name,
      'icon_code_point': crop.iconCodePoint,
      'icon_background': crop.iconBackground.value,
      'icon_foreground': crop.iconForeground.value,
      'image_emoji': crop.imageEmoji,
    };
  }

  Crop _fromMap(Map<String, dynamic> map) {
    return Crop(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      lot: map['lot'] as String,
      stage: map['stage'] as String,
      areaHa: (map['area_ha'] as num).toDouble(),
      plantingDensity: (map['planting_density'] as num).toDouble(),
      plantedAt: DateTime.parse(map['planted_at'] as String),
      status: CropStatus.values.firstWhere(
        (e) => e.name == map['status'] as String,
        orElse: () => CropStatus.active,
      ),
      iconCodePoint: map['icon_code_point'] as int,
      iconBackground: Color(map['icon_background'] as int),
      iconForeground: Color(map['icon_foreground'] as int),
      imageEmoji: map['image_emoji'] as String,
    );
  }
}
