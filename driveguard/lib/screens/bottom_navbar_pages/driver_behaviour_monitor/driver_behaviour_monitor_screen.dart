import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/drive_profile.dart';
import '../../../provider/mqtt_service_provider/mqtt_service.dart';

class BehaviourMonitorScreen extends StatefulWidget {
  const BehaviourMonitorScreen({super.key});

  @override
  State<BehaviourMonitorScreen> createState() => _BehaviourMonitorScreenState();
}

class _BehaviourMonitorScreenState extends State<BehaviourMonitorScreen> {
  final MqttService _mqttService = MqttService();

  DriverProfile? _currentProfile;
  List<double> _stHistory = [];

  @override
  void initState() {
    super.initState();
    _connectMqtt();
  }

  void _connectMqtt() async {
    await _mqttService.connect();
    _mqttService.profileStream.listen((profile) {
      setState(() {
        _currentProfile = profile;
        if (_stHistory.length > 50) _stHistory.removeAt(0);
        _stHistory.add(profile.stMean);
      });

      // Show banners for drift alerts
      for (var alert in profile.alerts) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                alert,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: alert.contains("degraded")
                  ? Colors.redAccent
                  : Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  Color _getRankColor(String rank) {
    if (rank.contains("S")) return Colors.purpleAccent;
    if (rank.contains("A")) return Colors.greenAccent;
    if (rank.contains("B")) return Colors.lightBlueAccent;
    if (rank.contains("C")) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentProfile == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Connecting to Vehicle MQTT...',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final p = _currentProfile!;
    final rankColor = _getRankColor(p.rank);

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver ID: ${p.deviceId}'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rank Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: rankColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'LIFETIME RANK',
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 2,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p.rank,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Trip Average',
                      p.stMean,
                      Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildStatCard('Lifetime Avg', p.ltMean, rankColor),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Live Chart
              const Text(
                'LIVE TRIP SAFETY',
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _stHistory
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blueAccent.withOpacity(0.2),
                          ),
                          dotData: FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(1)} / 100',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
