class WeatherData {
  final CurrentWeather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;

  WeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
  });
}

class CurrentWeather {
  final double temperature;
  final double humidity;
  final double windSpeed;
  final double uvIndex;
  final double rain;
  final String condition;
  final int weatherCode;

  CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.uvIndex,
    required this.rain,
    required this.condition,
    required this.weatherCode,
  });
}

class HourlyWeather {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });
}

class DailyWeather {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int weatherCode;

  DailyWeather({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.weatherCode,
  });
}

String getWeatherCondition(int code) {
  if (code == 0) return 'Soleado';
  if (code >= 1 && code <= 3) return 'Parcialmente nublado';
  if (code >= 45 && code <= 48) return 'Neblina';
  if (code >= 51 && code <= 67) return 'Llovizna';
  if (code >= 71 && code <= 77) return 'Nieve';
  if (code >= 80 && code <= 82) return 'Lluvia moderada';
  if (code >= 95) return 'Tormenta';
  return 'Nublado';
}
