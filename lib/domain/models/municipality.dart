// ignore_for_file: constant_identifier_names
// Los nombres de enum coinciden con los valores Java del backend (SCREAMING_SNAKE_CASE).

/// Espejo exacto del enum `Municipality` del backend Spring.
///
/// Los valores del enum coinciden con los nombres Java (usados por el backend
/// en serialización JSON con `@Enumerated(EnumType.STRING)`).
enum Municipality {
  SANTA_MARTA('Santa Marta'),
  CIENAGA('Ciénaga'),
  FUNDACION('Fundación'),
  ZONA_BANANERA('Zona Bananera'),
  ARACATACA('Aracataca'),
  EL_RETEN('El Retén'),
  PUEBLOVIEJO('Puebloviejo'),
  PIVIJAY('Pivijay'),
  PLATO('Plato'),
  EL_BANCO('El Banco'),
  ALGARROBO('Algarrobo'),
  ARIGUANI('Ariguaní'),
  CERRO_SAN_ANTONIO('Cerro de San Antonio'),
  CHIBOLO('Chibolo'),
  CONCORDIA('Concordia'),
  EL_PINON('El Piñón'),
  GUAMAL('Guamal'),
  NUEVA_GRANADA('Nueva Granada'),
  PEDRAZA('Pedraza'),
  PIJINO_DEL_CARMEN('Pijiño del Carmen'),
  REMOLINO('Remolino'),
  SABANAS_DE_SAN_ANGEL('Sabanas de San Ángel'),
  SALAMINA('Salamina'),
  SAN_SEBASTIAN('San Sebastián de Buenavista'),
  SAN_ZENON('San Zenón'),
  SANTA_ANA('Santa Ana'),
  SANTA_BARBARA('Santa Bárbara de Pinto'),
  SITIONUEVO('Sitionuevo'),
  TENERIFE('Tenerife'),
  ZAPAYAN('Zapayán');

  const Municipality(this.label);

  /// Nombre legible para mostrar en la UI.
  final String label;

  /// Convierte el string JSON del backend (nombre del enum Java) al enum Dart.
  static Municipality fromJson(String value) {
    return Municipality.values.firstWhere(
      (m) => m.name == value,
      orElse: () => Municipality.SANTA_MARTA,
    );
  }
}
