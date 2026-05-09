// ignore_for_file: constant_identifier_names
// Los nombres coinciden con los valores Java del backend (SCREAMING_SNAKE_CASE).

/// Espejo del enum `Role` del backend Spring.
enum AppRole {
  PRODUCER,
  ADR_TECHNICIAN;

  static AppRole fromJson(String value) {
    return AppRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => AppRole.PRODUCER,
    );
  }
}
