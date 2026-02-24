import 'dart:async';
import 'dart:math' as math;

import 'package:blinker/blinker.dart';
import 'package:driveguard/provider/esp_device_provider/esp_device_provider.dart';
import 'package:driveguard/provider/road_protection_provider/road_protection_provider.dart';
import 'package:driveguard/provider/speed_provider/speed_provider.dart';
import 'package:driveguard/provider/weather_service_provider/weather_service_provider.dart';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class DahsboardPage extends StatefulWidget {
  const DahsboardPage({super.key});

  @override
  State<DahsboardPage> createState() => _DahsboardPageState();
}

class _DahsboardPageState extends State<DahsboardPage> {
  Timer? periodicTimer;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      periodicTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        Provider.of<WeatherServiceProvider>(
          context,
          listen: false,
        ).getCurentWeather();
        Provider.of<RoadProtectionProvider>(
          context,
          listen: false,
        ).checkRoadProtectionStatus(context);
      });
      Provider.of<SpeedProvider>(context, listen: false).getSpeedData();
      WakelockPlus.enable();
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    periodicTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    Provider.of<SpeedProvider>(context, listen: false).disposeStream();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      WeatherServiceProvider,
      SpeedProvider,
      RoadProtectionProvider,
      EspDeviceProvider
    >(
      builder:
          (
            BuildContext context,
            WeatherServiceProvider weather_provider,
            SpeedProvider speed_provider,
            RoadProtectionProvider road_provider,
            EspDeviceProvider espProvider,
            Widget? child,
          ) {
            if (road_provider.isRoadProtectionActive) {
              Haptics.vibrate(HapticsType.error);
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: ListView(
                  children: [
                    _TopBar(
                      weatherText:
                          "${weather_provider.condition} ${weather_provider.temperature}°C",
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Dashboard',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(280, 280),
                              painter: GaugePainter(
                                speed: speed_provider.getSpeed,
                                safeSpeed:
                                    road_provider.roadProtectionSpeedLimit,
                                maxSpeed: 120,
                              ),
                            ),
                            Text(
                              '${speed_provider.getSpeed} \nKm/h',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(fontSize: 40, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            Positioned(
                              top: 6,
                              child: _SafeSpeedBadge(
                                value: road_provider.roadProtectionSpeedLimit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    _RiskPill(
                      status: road_provider.isRoadProtectionActive
                          ? "Please Slow Down the vehicle"
                          : road_provider.isRainProtectionActive
                          ? "Please drive carefully"
                          : 'Safe to drive',
                    ),
                    const SizedBox(height: 20),
                    detected_road_sign(),
                    const SizedBox(height: 20),
                    sensor_Ui(),
                  ],
                ),
              ),
            );
          },
    );
  }
}

Widget detected_road_sign() {
  return Consumer<RoadProtectionProvider>(
    builder:
        (
          BuildContext context,
          RoadProtectionProvider road_protection_provider,
          Widget? child,
        ) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.deepOrangeAccent,
            ),
            child: Row(
              children: [
                Icon(Icons.traffic_rounded, color: Colors.white),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    "Detected Road Sign: ${(road_protection_provider.detected_sign?.lables ?? []).isNotEmpty ? road_protection_provider.detected_sign?.lables?.elementAt(0) : ""}",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
  );
}

Widget sensor_Ui() {
  return Consumer<EspDeviceProvider>(
    builder: (BuildContext context, EspDeviceProvider esp_provider, Widget? child) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Road Monitoring Device: ${esp_provider.targetDevice != null ? "Connected" : "Not Connected"}",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 20),
            esp_provider.targetDevice == null
                ? Center(
                    child: ElevatedButton(
                      onPressed: () {
                        esp_provider.startScan();
                      },
                      child: Text("Connect"),
                    ),
                  )
                : Center(
                    child: esp_provider.completedImage != null
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.memory(
                              esp_provider.completedImage!,
                              width: 320,
                              height: 240,
                              fit: BoxFit.fill,
                            ),
                          )
                        : CircularProgressIndicator(),
                  ),
          ],
        ),
      );
    },
  );
}

class _TopBar extends StatelessWidget {
  final String weatherText;

  const _TopBar({required this.weatherText});

  @override
  Widget build(BuildContext context) {
    return Consumer3<
      WeatherServiceProvider,
      SpeedProvider,
      RoadProtectionProvider
    >(
      builder:
          (
            BuildContext context,
            WeatherServiceProvider weather_provider,
            SpeedProvider speed_provider,
            RoadProtectionProvider road_provider,
            Widget? child,
          ) {
            return Row(
              children: [
                road_provider.isRoadProtectionActive
                    ? Blinker.fade(
                        startColor: Colors.grey,
                        endColor: Colors.red,
                        duration: Duration(milliseconds: 500),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Colors.grey,
                          size: 30,
                        ),
                      )
                    : Icon(Icons.warning_rounded, color: Colors.grey, size: 30),
                const Spacer(),
                Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          (weather_provider.isDayTime)
                              ? Icons.wb_sunny_outlined
                              : Icons.nights_stay_rounded,
                          color: Colors.orangeAccent,
                          size: 30,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          weatherText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.water_drop_outlined,
                          color: Colors.lightBlue,
                          size: 25,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${weather_provider.rainProbability}% chance of ${weather_provider.rainProbabilitytype}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
    );
  }
}

class _SafeSpeedBadge extends StatelessWidget {
  final double value;

  const _SafeSpeedBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFF4D4D), width: 5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  final String status;

  const _RiskPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoadProtectionProvider>(
      builder:
          (
            BuildContext context,
            RoadProtectionProvider road_provider,
            Widget? child,
          ) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: road_provider.isRoadProtectionActive
                    ? Colors.red
                    : road_provider.isRainProtectionActive
                    ? Colors.orange
                    : const Color(0xFF57D163),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Status: $status',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            );
          },
    );
  }
}

class _FleetPreviewList extends StatelessWidget {
  final List<FleetRow> rows;

  const _FleetPreviewList({required this.rows});

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('online')) return const Color(0xFF57D163);
    if (s.contains('maint')) return const Color(0xFFFFD54A);
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = rows[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F27),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    r.vehicleId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(r.status).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _statusColor(r.status).withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      r.status,
                      style: TextStyle(
                        color: _statusColor(r.status),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _Chip(text: r.connectivity),
                  _Chip(text: r.sensors),
                  _Chip(text: r.storage),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class FleetRow {
  final String vehicleId;
  final String connectivity;
  final String sensors;
  final String storage;
  final String status;

  const FleetRow({
    required this.vehicleId,
    required this.connectivity,
    required this.sensors,
    required this.storage,
    required this.status,
  });
}

const fleetData = <FleetRow>[
  FleetRow(
    vehicleId: 'Fleet-01',
    connectivity: '📶 4G High',
    sensors: '✅ All OK',
    storage: '💾 85%',
    status: 'Online',
  ),
  FleetRow(
    vehicleId: 'Fleet-02',
    connectivity: '📶 Low',
    sensors: '❌ Camera',
    storage: '💾 10%',
    status: 'Maint. Req',
  ),
  FleetRow(
    vehicleId: 'Fleet-03',
    connectivity: '⚪ Offline',
    sensors: '⚪ Unknown',
    storage: '⚪ N/A',
    status: 'Disconnected',
  ),
];

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252B35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class FleetPage extends StatelessWidget {
  const FleetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fleet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: fleetData.length,
                itemBuilder: (_, i) {
                  final r = fleetData[i];
                  return Card(
                    color: const Color(0xFF1A1F27),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        r.vehicleId,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${r.connectivity}  •  ${r.sensors}  •  ${r.storage}',
                      ),
                      trailing: Text(
                        r.status,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double speed;
  final double safeSpeed;
  final double maxSpeed;

  GaugePainter({
    required this.speed,
    required this.safeSpeed,
    required this.maxSpeed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r1 = math.min(size.width, size.height) / 2 - 14;

    const startAngle = -math.pi * 0.85; // visually similar to screenshot
    const sweepAngle = math.pi * 1.7;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = Colors.white10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r1),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    final segments = 42;
    final gap = sweepAngle * 0.008;
    final segSweep = (sweepAngle / segments) - gap;

    final safeRatio = (safeSpeed / maxSpeed).clamp(0.0, 1.0);
    final safeSegs = (segments * safeRatio).round();

    for (int i = 0; i < segments; i++) {
      final a = startAngle + (sweepAngle / segments) * i;
      final isSafe = i <= safeSegs;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10
        ..color = isSafe ? const Color(0xFF57D163) : const Color(0xFFFF4D4D);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r1),
        a,
        segSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return speed != oldDelegate.speed ||
        safeSpeed != oldDelegate.safeSpeed ||
        maxSpeed != oldDelegate.maxSpeed;
  }
}
