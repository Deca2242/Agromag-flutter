import 'package:flutter/foundation.dart';

import 'crop_type.dart';
import 'municipality.dart';
import 'sync_status.dart';

@immutable
class Crop {
  const Crop({
    required this.id,
    required this.cropType,
    required this.areaHectares,
    required this.municipality,
    required this.sownDate,
    required this.syncStatus,
    required this.createdAt,
  });

  final String id;
  final CropType cropType;
  final double areaHectares;
  final Municipality municipality;
  final DateTime sownDate;
  final SyncStatus syncStatus;
  final DateTime createdAt;

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'] as String,
      cropType: CropType.fromJson(json['cropType'] as String),
      areaHectares: (json['areaHectares'] as num).toDouble(),
      municipality: Municipality.fromJson(json['municipality'] as String),
      sownDate: DateTime.parse(json['sownDate'] as String),
      syncStatus: SyncStatus.SYNCED,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Serialización para el body de POST /api/sync/batch.
  Map<String, dynamic> toSyncJson() {
    final d = sownDate;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'id': id,
      'cropType': cropType.name,
      'areaHectares': areaHectares,
      'municipality': municipality.name,
      'sownDate': dateStr,
    };
  }

  Crop copyWith({
    CropType? cropType,
    double? areaHectares,
    Municipality? municipality,
    DateTime? sownDate,
    SyncStatus? syncStatus,
  }) {
    return Crop(
      id: id,
      cropType: cropType ?? this.cropType,
      areaHectares: areaHectares ?? this.areaHectares,
      municipality: municipality ?? this.municipality,
      sownDate: sownDate ?? this.sownDate,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
    );
  }
}
