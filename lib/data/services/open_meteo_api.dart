import 'package:dio/dio.dart';

import '../../domain/models/municipality.dart';
import '../../domain/models/municipality_coords.dart';
import '../../domain/models/weather.dart';

/// Consulta el clima actual directamente desde Open-Meteo.
///
/// Usa un Dio independiente sin el Bearer de Supabase, ya que Open-Meteo
/// es una API pública sin autenticación.
class OpenMeteoApi {
  OpenMeteoApi() : _dio = _buildDio();

  final Dio _dio;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: 'https://api.open-meteo.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  Future<CurrentWeather> fetchWeather(Municipality municipality) async {
    final coords = coordsOf(municipality);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/forecast',
        queryParameters: {
          'latitude': coords.lat,
          'longitude': coords.lon,
          'current': 'temperature_2m,relative_humidity_2m',
        },
      );
      final data = response.data!;
      final current = data['current'] as Map<String, dynamic>;
      final temperature = (current['temperature_2m'] as num).toDouble();
      final humidity = (current['relative_humidity_2m'] as num).toDouble();
      return CurrentWeather(
        temperature: temperature,
        humidity: humidity,
        fetchedAt: DateTime.now(),
      );
    } on DioException {
      rethrow;
    }
  }
}
