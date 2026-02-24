import 'package:blinker/blinker.dart';
import 'package:driveguard/provider/driver_live_monitor/driver_live_monitor.dart';
import 'package:driveguard/provider/esp_device_provider/esp_device_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DriverMonitorScreen extends StatefulWidget {
  const DriverMonitorScreen({super.key});

  @override
  State<DriverMonitorScreen> createState() => _DriverMonitorScreenState();
}

class _DriverMonitorScreenState extends State<DriverMonitorScreen> {
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
              appBar: AppBar(
                surfaceTintColor: Colors.black,
                title: Text(
                  'Driver Live Monitor',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: IconButton(
                      icon: Icon(
                        Icons.bluetooth,
                        color: esp_connector.isDriverMonitorConnecteed
                            ? Colors.green
                            : Colors.grey,
                        size: 30,
                      ),
                      onPressed: () {
                        Provider.of<EspDeviceProvider>(
                          context,
                          listen: false,
                        ).startdrivermonitorScan();
                      },
                    ),
                  ),
                ],
                centerTitle: true,
                leading: driver_monitor.isDriverAlert
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
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _buildMonitorCard(
                      title: 'Blood Oxygen (SpO2)',
                      value: driver_monitor.bloodOxygenLevel.toStringAsFixed(0),
                      unit: '%',
                      icon: Icons.bloodtype,
                      color: Colors.green,
                    ),

                    const SizedBox(height: 16),

                    _buildMonitorCard(
                      title: 'Cabin Temperature',
                      value: driver_monitor.temperature.toStringAsFixed(0),
                      unit: '°C',
                      icon: Icons.thermostat,
                      color: Colors.orangeAccent,
                    ),

                    const SizedBox(height: 16),

                    _buildMonitorCard(
                      title: 'Blood Preasure',
                      value: driver_monitor.bloodPreasure.toStringAsFixed(0),
                      unit: 'BPM',
                      icon: Icons.bloodtype_outlined,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _buildMonitorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(10),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
