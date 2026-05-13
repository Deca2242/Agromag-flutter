import 'package:dio/dio.dart';
import '../../domain/models/weather.dart';

class WeatherRepository {
  final Dio _dio = Dio();

  Future<WeatherData> getWeatherData(double lat, double lon) async {
    final response = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': 'temperature_2m,relative_humidity_2m,rain,weather_code,wind_speed_10m,uv_index',
        'hourly': 'temperature_2m,weather_code',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': 7,
      },
    );

    final current = response.data['current'];
    final hourly = response.data['hourly'];
    final daily = response.data['daily'];

    final currentWeather = CurrentWeather(
      temperature: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      uvIndex: (current['uv_index'] as num).toDouble(),
      rain: (current['rain'] as num).toDouble(),
      weatherCode: current['weather_code'] as int,
      condition: getWeatherCondition(current['weather_code'] as int),
    );

    final List<HourlyWeather> hourlyList = [];
    final now = DateTime.now();
    
    // Encontrar el índice de la hora actual
    int startIndex = 0;
    for (int i = 0; i < (hourly['time'] as List).length; i++) {
      final time = DateTime.parse(hourly['time'][i]);
      if (time.isAfter(now.subtract(const Duration(hours: 1)))) {
        startIndex = i;
        break;
      }
    }

    for (int i = startIndex; i < (hourly['time'] as List).length; i++) {
      if (hourlyList.length < 24) {
        hourlyList.add(HourlyWeather(
          time: DateTime.parse(hourly['time'][i]),
          temperature: (hourly['temperature_2m'][i] as num).toDouble(),
          weatherCode: hourly['weather_code'][i] as int,
        ));
      }
    }

    final List<DailyWeather> dailyList = [];
    for (int i = 0; i < (daily['time'] as List).length; i++) {
      dailyList.add(DailyWeather(
        date: DateTime.parse(daily['time'][i]),
        minTemp: (daily['temperature_2m_min'][i] as num).toDouble(),
        maxTemp: (daily['temperature_2m_max'][i] as num).toDouble(),
        weatherCode: daily['weather_code'][i] as int,
      ));
    }

    return WeatherData(
      current: currentWeather,
      hourly: hourlyList,
      daily: dailyList,
    );
  }
}
