/// Excepciones tipadas para errores del backend Spring.
sealed class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}

/// 401 — sesión expirada sin posibilidad de refresh.
final class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('Sesión expirada. Inicia sesión de nuevo.');
}

/// 404 — recurso no encontrado.
final class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Recurso no encontrado.']);
}

/// 400/422 — datos inválidos enviados al servidor.
final class ValidationException extends ApiException {
  const ValidationException(super.message);
}

/// Cualquier otro error del servidor (5xx, etc.).
final class ServerException extends ApiException {
  const ServerException([super.message = 'Error del servidor. Intenta más tarde.']);
}

/// Sin conexión a internet.
final class NetworkException extends ApiException {
  const NetworkException()
      : super('Sin conexión. Verifica tu red e intenta de nuevo.');
}
