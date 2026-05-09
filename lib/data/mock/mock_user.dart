import '../../domain/models/app_role.dart';
import '../../domain/models/municipality.dart';
import '../../domain/models/profile.dart';

/// Perfil de ejemplo para mostrar mientras no hay datos reales.
final Profile kMockProfile = Profile(
  id: 'mock-user-id',
  email: 'juan@ejemplo.com',
  role: AppRole.PRODUCER,
  fullName: 'Juan Valdez',
  municipality: Municipality.SANTA_MARTA,
  createdAt: DateTime(2024, 1, 1),
);

/// Lista completa de municipios del Magdalena para el dropdown de registro.
const List<Municipality> kMagdalenaMunicipalities = Municipality.values;

const List<String> kProducerTypes = [
  'Productor Independiente',
  'Cooperativa',
  'Asociación',
  'Empresa Agrícola',
];
