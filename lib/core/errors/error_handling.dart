import 'dart:developer' as developer;

import '../network/api_exceptions.dart';

class AppErrorHandling {
  const AppErrorHandling._();

  static String userMessage(
    Object error, {
    String fallback = 'Ocurrió un error. Intenta de nuevo.',
  }) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is FormatException) {
      return 'No se pudo procesar la respuesta del servidor.';
    }
    return fallback;
  }

  static void report(String context, Object error, [StackTrace? stackTrace]) {
    developer.log(
      context,
      name: 'agromag.app',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
