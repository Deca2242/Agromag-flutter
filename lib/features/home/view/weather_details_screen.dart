import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/weather.dart';
import '../../auth/providers/auth_providers.dart';
import '../weather_providers.dart';

class WeatherDetailsScreen extends ConsumerWidget {
  const WeatherDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(currentLocationWeatherProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final locationName = profileAsync is AsyncData && profileAsync.value != null 
        ? profileAsync.value!.municipality.label 
        : 'Santa Marta';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Clima',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.softGreenBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'EN LÍNEA',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: weatherAsync.when(
        data: (weather) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(weather: weather.current, locationName: locationName),
              const SizedBox(height: 20),
              _DetailsGrid(weather: weather.current),
              const SizedBox(height: 30),
              _HourlyForecast(hourly: weather.hourly),
              const SizedBox(height: 30),
              _TemperatureChart(hourly: weather.hourly),
              const SizedBox(height: 30),
              _DailyForecast(daily: weather.daily),
              const SizedBox(height: 40),
              _RadarCard(
                lat: profileAsync.value?.municipality.latitude ?? 11.2408, 
                lon: profileAsync.value?.municipality.longitude ?? -74.1992
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final CurrentWeather weather;
  final String locationName;
  const _HeaderCard({required this.weather, required this.locationName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B3D2F),
            const Color(0xFF2D5A44),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clima Detallado',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.softGreenBg, size: 14),
              const SizedBox(width: 4),
              Text(
                locationName,
                style: const TextStyle(color: AppColors.softGreenBg, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weather.temperature.round()}°',
                    style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    weather.condition,
                    style: const TextStyle(color: AppColors.softGreenBg, fontSize: 18),
                  ),
                ],
              ),
              const Icon(Icons.wb_sunny, color: AppColors.softGreenBg, size: 80),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  final CurrentWeather weather;
  const _DetailsGrid({required this.weather});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _DetailItem(
          icon: Icons.water_drop,
          label: 'Humedad',
          value: '${weather.humidity.round()} %',
        ),
        _DetailItem(
          icon: Icons.air,
          label: 'Viento',
          value: '${weather.windSpeed.round()} km/h',
        ),
        _DetailItem(
          icon: Icons.wb_sunny_outlined,
          label: 'Índice UV',
          value: '${weather.uvIndex.round()}',
          badge: weather.uvIndex > 5 ? 'Alto' : 'Bajo',
        ),
        _DetailItem(
          icon: Icons.cloud,
          label: 'Lluvia',
          value: '${weather.rain.round()} %',
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyForecast extends StatelessWidget {
  final List<HourlyWeather> hourly;
  const _HourlyForecast({required this.hourly});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximas horas',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 8, // Mostrar próximas 8 horas
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final h = hourly[index];
              final isNow = index == 0;
              return Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNow ? 'Ahora' : DateFormat('HH:00').format(h.time),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.wb_sunny, size: 20, color: AppColors.textPrimary),
                    Text(
                      '${h.temperature.round()}°',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemperatureChart extends StatelessWidget {
  final List<HourlyWeather> hourly;
  const _TemperatureChart({required this.hourly});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tendencia de Temperatura',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const Icon(Icons.show_chart, size: 18, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 3, // Mostrar cada 3 horas
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < hourly.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('HH:00').format(hourly[index].time),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}°',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: hourly.sublist(0, 12).asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.temperature);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.primaryGreen,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        // Resaltar algunos puntos
                        if (index % 4 == 0) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: AppColors.primaryGreen,
                          );
                        }
                        return FlDotCirclePainter(radius: 0);
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryGreen.withOpacity(0.2),
                          AppColors.primaryGreen.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppColors.primaryGreenDark,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        return LineTooltipItem(
                          '${touchedSpot.y.round()}°',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyForecast extends StatelessWidget {
  final List<DailyWeather> daily;
  const _DailyForecast({required this.daily});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Próximos 7 días',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daily.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final d = daily[index];
            String label = DateFormat('EEEE', 'es').format(d.date);
            label = label[0].toUpperCase() + label.substring(1);
            if (index == 0) label = 'Hoy';
            if (index == 1) label = 'Mañana';

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Expanded(
                  flex: 2,
                  child: Icon(Icons.wb_sunny, color: AppColors.textPrimary, size: 20),
                ),
                Expanded(
                  flex: 2,
                  child: Text('${d.minTemp.round()}°', style: const TextStyle(color: AppColors.textSecondary)),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${d.maxTemp.round()}°',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RadarCard extends StatelessWidget {
  final double lat;
  final double lon;
  const _RadarCard({required this.lat, required this.lon});

  Future<void> _openRadar() async {
    final url = Uri.parse('https://embed.windy.com/embed2.html?lat=$lat&lon=$lon&zoom=9&level=surface&overlay=temp');
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1500382017468-9049fed747ef?q=80&w=2532&auto=format&fit=crop'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0), Colors.black.withOpacity(0.5)],
          ),
        ),
        padding: const EdgeInsets.all(20),
        alignment: Alignment.bottomCenter,
        child: ElevatedButton.icon(
          onPressed: _openRadar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.map),
          label: const Text('Ver Radar Interactivo', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
