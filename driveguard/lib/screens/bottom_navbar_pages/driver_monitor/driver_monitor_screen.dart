import 'package:blinker/blinker.dart';
import 'package:driveguard/provider/driver_live_monitor/driver_live_monitor.dart';
import 'package:driveguard/provider/esp_device_provider/esp_device_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/fatigue_data.dart';
import '../../../provider/websocket_service_provider/websocket_service.dart';
import '../../../theme.dart';
import '../../../widgets/dashboard_card.dart';

class DriverMonitorScreen extends StatefulWidget {
  const DriverMonitorScreen({super.key});

  @override
  State<DriverMonitorScreen> createState() => _DriverMonitorScreenState();
}

class _DriverMonitorScreenState extends State<DriverMonitorScreen> {
  late final WebSocketService _service;

  @override
  void initState() {
    super.initState();
    _service = context.read<WebSocketService>();
    if (!_service.connectionNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _service.connect());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DriverLiveMonitor, EspDeviceProvider>(
      builder: (
          BuildContext context,
          DriverLiveMonitor driver_monitor,
          EspDeviceProvider esp_connector,
          Widget? child,
          ) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: ValueListenableBuilder<FatigueData?>(
            valueListenable: _service.dataNotifier,
            builder: (context, fatigueData, _) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Header
                    _DriverMonitorHeader(
                      espConnector: esp_connector,
                      driverMonitor: driver_monitor,
                    ),
                    const SizedBox(height: 20),

                    // Drowsiness Alert Banner
                    _DrowsinessAlertBanner(fatigueData: fatigueData),

                    // Driver Alert Banner
                    if (driver_monitor.isDriverAlert) ...[
                      const SizedBox(height: 16),
                      _DriverAlertBanner(driverMonitor: driver_monitor),
                    ],

                    const SizedBox(height: 20),

                    // Driver Vitals Grid
                    DashboardCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monitor_heart_rounded,
                                  color: AppColors.blue, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Driver Vitals',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.45,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _VitalTile(
                                icon: Icons.favorite_rounded,
                                iconColor: AppColors.red,
                                label: 'Blood Oxygen',
                                subtitle: 'SpO2',
                                value: driver_monitor.bloodOxygenLevel
                                    .toStringAsFixed(0),
                                unit: '%',
                              ),
                              _VitalTile(
                                icon: Icons.device_thermostat_rounded,
                                iconColor: AppColors.orange,
                                label: 'Cabin Temp',
                                subtitle: 'Interior',
                                value: driver_monitor.temperature
                                    .toStringAsFixed(0),
                                unit: 'C',
                              ),
                              _VitalTile(
                                icon: Icons.monitor_heart_rounded,
                                iconColor: AppColors.pink,
                                label: 'Blood Pressure',
                                subtitle: 'Heart rate',
                                value: driver_monitor.bloodPressure
                                    .toStringAsFixed(0),
                                unit: 'BPM',
                              ),
                              _VitalTile(
                                icon: Icons.graphic_eq_rounded,
                                iconColor: AppColors.cyan,
                                label: 'Cabin Noise',
                                subtitle: 'Ambient',
                                value: driver_monitor.cabinNoiseLevel
                                    .toStringAsFixed(0),
                                unit: 'dB',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Drowsiness Analysis Card
                    DashboardCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology_rounded,
                                  color: AppColors.purple, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Drowsiness Analysis',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _DrowsinessPanel(fatigueData: fatigueData),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Header
class _DriverMonitorHeader extends StatelessWidget {
  final EspDeviceProvider espConnector;
  final DriverLiveMonitor driverMonitor;

  const _DriverMonitorHeader({
    required this.espConnector,
    required this.driverMonitor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Live\nMonitor',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: driverMonitor.isDriverAlert
                          ? AppColors.red
                          : AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      driverMonitor.isDriverAlert
                          ? 'Alert Active'
                          : 'Real-time Analysis',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () =>
              Provider.of<EspDeviceProvider>(context, listen: false)
                  .startdrivermonitorScan(),
          child: Container(
            width: 88,
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: espConnector.isDriverMonitorConnecteed
                  ? AppColors.green.withValues(alpha: 0.15)
                  : AppColors.surfaceVariant,
              border: Border.all(
                color: espConnector.isDriverMonitorConnecteed
                    ? AppColors.green
                    : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bluetooth_rounded,
                  color: espConnector.isDriverMonitorConnecteed
                      ? AppColors.green
                      : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  espConnector.isDriverMonitorConnecteed
                      ? 'CONNECTED'
                      : 'SCAN',
                  style: TextStyle(
                    color: espConnector.isDriverMonitorConnecteed
                        ? AppColors.green
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Drowsiness Alert Banner
class _DrowsinessAlertBanner extends StatelessWidget {
  final FatigueData? fatigueData;

  const _DrowsinessAlertBanner({required this.fatigueData});

  @override
  Widget build(BuildContext context) {
    if (fatigueData == null) return const SizedBox.shrink();
    final drowsiness = fatigueData!.rawSensorData.drowsiness;
    if (drowsiness.label != 'Drowsy' || drowsiness.confidence <= 80) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.alertGradients['CRITICAL'] ??
              [const Color(0xFF2D0A0A), const Color(0xFF1A0505)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.bedtime_rounded, color: Colors.white, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FATIGUE DETECTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fatigue: ${drowsiness.label}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Text',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confidence',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
              Text(
                '${(drowsiness.confidence * 1).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Driver Alert Banner
class _DriverAlertBanner extends StatelessWidget {
  final DriverLiveMonitor driverMonitor;

  const _DriverAlertBanner({required this.driverMonitor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.alertGradients['WARNING'] ??
              [const Color(0xFF2D1A00), const Color(0xFF1A0F00)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Blinker.fade(
              startColor: Colors.transparent,
              endColor: AppColors.orange,
              duration: const Duration(milliseconds: 500),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DRIVER ALERT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${driverMonitor.alertMessage}",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Vital Tile
class _VitalTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final String value;
  final String unit;

  const _VitalTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon + label — Flexible prevents overflow
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),

          // Value — FittedBox scales down if number is too wide
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// Drowsiness Panel
class _DrowsinessPanel extends StatelessWidget {
  final FatigueData? fatigueData;

  const _DrowsinessPanel({required this.fatigueData});

  @override
  Widget build(BuildContext context) {
    if (fatigueData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Waiting for data...',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final drowsiness = fatigueData!.rawSensorData.drowsiness;
    final isDrowsy = drowsiness.label == 'Drowsy';
    final accentColor = isDrowsy ? AppColors.red : AppColors.green;

    return Column(
      children: [
        // Score bar panel
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drowsiness Score',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      drowsiness.label,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${drowsiness.confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: drowsiness.confidence / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Alert',
                    style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  Text(
                    'Drowsy',
                    style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Status chip
        Container(
          width: double.infinity,
          padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: accentColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                isDrowsy
                    ? Icons.bedtime_rounded
                    : Icons.check_circle_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isDrowsy
                      ? 'Driver appears drowsy — take action'
                      : 'Driver is alert and attentive',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}