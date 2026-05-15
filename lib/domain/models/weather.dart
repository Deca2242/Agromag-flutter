import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class WeatherData {
  const WeatherData({
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final CurrentWeather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;

  Map<String, dynamic> toJson() => {
    'current': current.toJson(),
    'hourly': hourly.map((e) => e.toJson()).toList(),
    'daily': daily.map((e) => e.toJson()).toList(),
  };

  static WeatherData fromJson(Map<String, dynamic> json) {
    return WeatherData(
      current: CurrentWeather.fromJson(
        Map<String, dynamic>.from(json['current'] as Map),
      ),
      hourly: (json['hourly'] as List<dynamic>)
          .map(
            (e) => HourlyWeather.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      daily: (json['daily'] as List<dynamic>)
          .map(
            (e) => DailyWeather.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  static WeatherData? decodeFromForecastJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return WeatherData.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

@immutable
class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.fetchedAt,
    this.source = 'Open-Meteo',
    this.windSpeed = 0,
    this.uvIndex = 0,
    this.rain = 0,
    this.condition = '—',
    this.weatherCode = 0,
  });

  final double temperature;
  final double humidity;
  final DateTime fetchedAt;
  final String source;
  final double windSpeed;
  final double uvIndex;
  final double rain;
  final String condition;
  final int weatherCode;

  String get temperatureLabel => '${temperature.toStringAsFixed(1)}°C';
  String get humidityLabel => '${humidity.toStringAsFixed(0)}%';

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'fetchedAt': fetchedAt.toIso8601String(),
    'source': source,
    'windSpeed': windSpeed,
    'uvIndex': uvIndex,
    'rain': rain,
    'condition': condition,
    'weatherCode': weatherCode,
  };

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      source: json['source'] as String? ?? 'Open-Meteo',
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0,
      uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 0,
      rain: (json['rain'] as num?)?.toDouble() ?? 0,
      condition: json['condition'] as String? ?? '—',
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
    );
  }

  /// Fila legacy SQLite: solo temp, humedad y fecha.
  factory CurrentWeather.fromLegacyRow({
    required double temperature,
    required double humidity,
    required DateTime fetchedAt,
    String source = 'cache',
  }) {
    return CurrentWeather(
      temperature: temperature,
      humidity: humidity,
      fetchedAt: fetchedAt,
      source: source,
    );
  }
}

@immutable
class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'temperature': temperature,
    'weatherCode': weatherCode,
  };

  factory HourlyWeather.fromJson(Map<String, dynamic> json) {
    return HourlyWeather(
      time: DateTime.parse(json['time'] as String),
      temperature: (json['temperature'] as num).toDouble(),
      weatherCode: (json['weatherCode'] as num).toInt(),
    );
  }
}

@immutable
class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.weatherCode,
  });

  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int weatherCode;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'minTemp': minTemp,
    'maxTemp': maxTemp,
    'weatherCode': weatherCode,
  };

  factory DailyWeather.fromJson(Map<String, dynamic> json) {
    return DailyWeather(
      date: DateTime.parse(json['date'] as String),
      minTemp: (json['minTemp'] as num).toDouble(),
      maxTemp: (json['maxTemp'] as num).toDouble(),
      weatherCode: (json['weatherCode'] as num).toInt(),
    );
  }
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
