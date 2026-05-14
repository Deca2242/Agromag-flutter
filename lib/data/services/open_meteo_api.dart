import 'package:dio/dio.dart';

import '../../domain/models/municipality.dart';
import '../../domain/models/municipality_coords.dart';
import '../../domain/models/weather.dart';

/// Consulta el clima directamente desde Open-Meteo.
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

  /// Resumen actual (compatibilidad con caché existente).
  Future<CurrentWeather> fetchWeather(Municipality municipality) async {
    final data = await fetchWeatherData(municipality);
    return data.current;
  }

  /// Pronóstico actual + horario + 7 días.
  Future<WeatherData> fetchWeatherData(Municipality municipality) async {
    final coords = coordsOf(municipality);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/forecast',
        queryParameters: {
          'latitude': coords.lat,
          'longitude': coords.lon,
          'current':
              'temperature_2m,relative_humidity_2m,rain,weather_code,wind_speed_10m,uv_index',
          'hourly': 'temperature_2m,weather_code',
          'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );
      final data = response.data!;
      final current = data['current'] as Map<String, dynamic>;
      final hourly = data['hourly'] as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>;

      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final now = DateTime.now();
      final currentWeather = CurrentWeather(
        temperature: (current['temperature_2m'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toDouble(),
        windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
        uvIndex: (current['uv_index'] as num?)?.toDouble() ?? 0,
        rain: (current['rain'] as num?)?.toDouble() ?? 0,
        weatherCode: code,
        condition: getWeatherCondition(code),
        fetchedAt: now,
        source: 'Open-Meteo',
      );

      final hourlyList = <HourlyWeather>[];
      final times = hourly['time'] as List<dynamic>;
      int startIndex = 0;
      for (var i = 0; i < times.length; i++) {
        final time = DateTime.parse(times[i] as String);
        if (time.isAfter(now.subtract(const Duration(hours: 1)))) {
          startIndex = i;
          break;
        }
      }
      for (var i = startIndex; i < times.length; i++) {
        if (hourlyList.length >= 24) break;
        hourlyList.add(
          HourlyWeather(
            time: DateTime.parse(times[i] as String),
            temperature: (hourly['temperature_2m'][i] as num).toDouble(),
            weatherCode: hourly['weather_code'][i] as int,
          ),
        );
      }

      final dailyList = <DailyWeather>[];
      final dailyTimes = daily['time'] as List<dynamic>;
      for (var i = 0; i < dailyTimes.length; i++) {
        dailyList.add(
          DailyWeather(
            date: DateTime.parse(dailyTimes[i] as String),
            minTemp: (daily['temperature_2m_min'][i] as num).toDouble(),
            maxTemp: (daily['temperature_2m_max'][i] as num).toDouble(),
            weatherCode: daily['weather_code'][i] as int,
          ),
        );
      }

      return WeatherData(
        current: currentWeather,
        hourly: hourlyList,
        daily: dailyList,
      );
    } on DioException {
      rethrow;
    }
  }
}
