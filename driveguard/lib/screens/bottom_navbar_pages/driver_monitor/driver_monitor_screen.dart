import 'package:blinker/blinker.dart';
import 'package:driveguard/provider/driver_live_monitor/driver_live_monitor.dart';
import 'package:driveguard/provider/esp_device_provider/esp_device_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/fatigue_data.dart';
import '../../../provider/websocket_service_provider/websocket_service.dart';

class DriverMonitorScreen extends StatefulWidget {
  const DriverMonitorScreen({super.key});

  @override
  State<DriverMonitorScreen> createState() => _DriverMonitorScreenState();
}

class _DriverMonitorScreenState extends State<DriverMonitorScreen>
    with TickerProviderStateMixin {
  late final WebSocketService _service;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _service = context.read<WebSocketService>();
    if (!_service.connectionNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _service.connect());
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DriverLiveMonitor, EspDeviceProvider>(
      builder:
          (
            BuildContext context,
            DriverLiveMonitor driver_monitor,
            EspDeviceProvider esp_connector,
            Widget? child,
          ) {
            return Scaffold(
              backgroundColor: const Color(0xFF050A14),
              appBar: _buildAppBar(context, driver_monitor, esp_connector),
              body: ValueListenableBuilder<FatigueData?>(
                valueListenable: _service.dataNotifier,
                builder: (context, fatigueData, _) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF050A14),
                          Color(0xFF0A1628),
                          Color(0xFF050A14),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildStatusBar(driver_monitor, esp_connector),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.92,
                              children: [
                                _buildMetricCard(
                                  title: 'Blood Oxygen',
                                  subtitle: 'SpO2',
                                  value: driver_monitor.bloodOxygenLevel
                                      .toStringAsFixed(0),
                                  unit: '%',
                                  icon: Icons.bloodtype,
                                  accentColor: const Color(0xFF00E5A0),
                                  glowColor: const Color(0xFF00E5A0),
                                ),
                                _buildMetricCard(
                                  title: 'Cabin Temp',
                                  subtitle: 'Celsius',
                                  value: driver_monitor.temperature
                                      .toStringAsFixed(0),
                                  unit: '°C',
                                  icon: Icons.thermostat,
                                  accentColor: const Color(0xFFFF8C42),
                                  glowColor: const Color(0xFFFF8C42),
                                ),
                                _buildMetricCard(
                                  title: 'Blood Pressure',
                                  subtitle: 'Heart Rate',
                                  value: driver_monitor.bloodPressure
                                      .toStringAsFixed(0),
                                  unit: 'BPM',
                                  icon: Icons.favorite,
                                  accentColor: const Color(0xFFFF3B6B),
                                  glowColor: const Color(0xFFFF3B6B),
                                ),
                                _buildMetricCard(
                                  title: 'Cabin Noise',
                                  subtitle: 'Decibel',
                                  value: driver_monitor.cabinNoiseLevel
                                      .toStringAsFixed(0),
                                  unit: 'dB',
                                  icon: Icons.graphic_eq,
                                  accentColor: const Color(0xFF4D9FFF),
                                  glowColor: const Color(0xFF4D9FFF),
                                ),

                                _buildMetricCard(
                                  title: 'Drowsiness',
                                  subtitle: 'Score',
                                  value:
                                      fatigueData
                                          ?.rawSensorData
                                          .drowsiness
                                          .confidence
                                          .toStringAsFixed(1) ??
                                      '--',
                                  unit: '%',
                                  icon: Icons.psychology,
                                  accentColor: const Color(0xFFBF6FFF),
                                  glowColor: const Color(0xFFBF6FFF),
                                ),
                                _buildAlertLevelCard(
                                  fatigueData?.rawSensorData.drowsiness.label ??
                                      'Unknown',
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (driver_monitor.isDriverAlert)
                          _buildDriverAlertBanner(driver_monitor),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              ),
            );
          },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    DriverLiveMonitor driver_monitor,
    EspDeviceProvider esp_connector,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF050A14),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF1A3A5C).withOpacity(0.6),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0066FF).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Column(
            children: [
              Text(
                'DRIVER LIVE MONITOR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
              Text(
                'Real-time Vitals Dashboard',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  color: const Color(0xFF4D9FFF).withOpacity(0.8),
                ),
              ),
            ],
          ),
          leading: driver_monitor.isDriverAlert
              ? Blinker.fade(
                  startColor: Colors.transparent,
                  endColor: Colors.red.withOpacity(0.2),
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1A3A5C).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white.withOpacity(0.2),
                    size: 22,
                  ),
                ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () {
                  Provider.of<EspDeviceProvider>(
                    context,
                    listen: false,
                  ).startdrivermonitorScan();
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: esp_connector.isDriverMonitorConnecteed
                            ? const Color(0xFF00E5A0).withOpacity(0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: esp_connector.isDriverMonitorConnecteed
                              ? const Color(
                                  0xFF00E5A0,
                                ).withOpacity(0.4 * _pulseAnimation.value)
                              : const Color(0xFF1A3A5C).withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: esp_connector.isDriverMonitorConnecteed
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00E5A0,
                                  ).withOpacity(0.3 * _pulseAnimation.value),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.bluetooth,
                        color: esp_connector.isDriverMonitorConnecteed
                            ? const Color(0xFF00E5A0)
                            : Colors.white24,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(
    DriverLiveMonitor driver_monitor,
    EspDeviceProvider esp_connector,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0D1F35),
        border: Border.all(
          color: const Color(0xFF1A3A5C).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusDot(
            'BLUETOOTH',
            esp_connector.isDriverMonitorConnecteed,
            const Color(0xFF00E5A0),
          ),
          Container(width: 1, height: 20, color: const Color(0xFF1A3A5C)),
          _buildStatusDot('MONITORING', true, const Color(0xFF4D9FFF)),
          Container(width: 1, height: 20, color: const Color(0xFF1A3A5C)),
          _buildStatusDot(
            'ALERT',
            driver_monitor.isDriverAlert,
            const Color(0xFFFF3B6B),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(String label, bool active, Color color) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color : Colors.white12,
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.6 * _pulseAnimation.value),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: active ? color.withOpacity(0.9) : Colors.white24,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String subtitle,
    required String value,
    required String unit,
    required IconData icon,
    required Color accentColor,
    required Color glowColor,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF0A1628),
            border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background glow blob
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Top accent line
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(2),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        accentColor.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: accentColor.withOpacity(0.12),
                            border: Border.all(
                              color: accentColor.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(icon, size: 20, color: accentColor),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: accentColor.withOpacity(0.1),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: accentColor,
                            shadows: [
                              Shadow(
                                color: accentColor.withOpacity(
                                  0.5 * _pulseAnimation.value,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 3),
                          child: Text(
                            unit,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: accentColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertLevelCard(String alertLabel) {
    final isAlert =
        alertLabel.toLowerCase() != 'safe' &&
        alertLabel.toLowerCase() != 'awake';
    final cardColor = isAlert
        ? const Color(0xFFFF8C42)
        : const Color(0xFF00E5A0);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardColor.withOpacity(0.18), const Color(0xFF0A1628)],
            ),
            border: Border.all(color: cardColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: cardColor.withOpacity(0.12 * _pulseAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 24,
                right: 24,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(2),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        cardColor.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: cardColor.withOpacity(0.15),
                            border: Border.all(
                              color: cardColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isAlert
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            size: 20,
                            color: cardColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: cardColor.withOpacity(0.12),
                          ),
                          child: Text(
                            isAlert ? 'ALERT' : 'OK',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: cardColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'Alert Level',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alertLabel,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: cardColor,
                        shadows: [
                          Shadow(
                            color: cardColor.withOpacity(
                              0.5 * _pulseAnimation.value,
                            ),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverAlertBanner(DriverLiveMonitor driver_monitor) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3D1500), Color(0xFF1A0800)],
            ),
            border: Border.all(
              color: const Color(
                0xFFFF4500,
              ).withOpacity(0.4 + 0.3 * _pulseAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFF4500,
                ).withOpacity(0.2 * _pulseAnimation.value),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4500).withOpacity(0.15),
                  border: Border.all(
                    color: const Color(0xFFFF4500).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 26,
                  color: Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠ DRIVER ALERT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: const Color(0xFFFF6B35).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${driver_monitor.alertMessage}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
