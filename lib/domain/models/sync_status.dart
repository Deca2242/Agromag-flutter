// ignore_for_file: constant_identifier_names

/// Estado de sincronización de un cultivo local con el backend.
enum SyncStatus {
  PENDING,
  SYNCED,
  ERROR;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SyncStatus.PENDING,
    );
  }
}
