import '../../domain/models/crop_type.dart';

/// Representa un conflicto detectado cuando el servidor sobrescribe datos locales.
class CropSyncConflict {
  const CropSyncConflict({
    required this.cropId,
    required this.cropType,
    required this.fieldName,
    required this.localValue,
    required this.serverValue,
  });

  final String cropId;
  final CropType cropType;
  final String fieldName;
  final String localValue;
  final String serverValue;

  String get cropLabel => cropType.label;

  String get fieldLabel => switch (fieldName) {
    'areaHectares' => 'Área (ha)',
    'municipality' => 'Municipio',
    'sownDate' => 'Fecha de siembra',
    _ => fieldName,
  };
}
