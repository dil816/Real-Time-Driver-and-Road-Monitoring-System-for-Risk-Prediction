import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

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
  bool _didVibrate = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      periodicTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (!mounted) return;

        context.read<WeatherServiceProvider>().getCurentWeather();
        context.read<RoadProtectionProvider>().checkRoadProtectionStatus(context);
      });

      context.read<SpeedProvider>().getSpeedData();
      WakelockPlus.enable();
    });
  }

  @override
  void dispose() {
    periodicTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  void _handleHaptic(bool shouldAlert) {
    if (shouldAlert && !_didVibrate) {
      _didVibrate = true;
      Haptics.vibrate(HapticsType.error);
    } else if (!shouldAlert) {
      _didVibrate = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<
        WeatherServiceProvider,
        SpeedProvider,
        RoadProtectionProvider,
        EspDeviceProvider>(
      builder: (
          BuildContext context,
          WeatherServiceProvider weatherProvider,
          SpeedProvider speedProvider,
          RoadProtectionProvider roadProvider,
          EspDeviceProvider espProvider,
          Widget? child,
          ) {
        final double currentSpeed = speedProvider.getSpeed;
        final double detectedLimit = roadProvider.roadProtectionSpeedLimit;
        final double safeSpeed = roadProvider.effectiveSafeSpeed;

        final bool overSpeed =
            roadProvider.isRoadProtectionActive && safeSpeed > 0;
        final bool heavyRain = roadProvider.isHeavyRainProtectionActive;

        _handleHaptic(overSpeed || heavyRain);

        return Scaffold(
          backgroundColor: const Color(0xFF071224),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF071224),
                  Color(0xFF09172C),
                  Color(0xFF0B1D36),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  const _TopBar(),
                  const SizedBox(height: 20),
                  const Text(
                    'Road Safety Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Live speed monitoring, sign detection, weather risk and camera feed.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const ManualSpeedTestCard(),
                  const SizedBox(height: 18),

                  _AlertHeroCard(
                    currentSpeed: currentSpeed,
                    detectedLimit: detectedLimit,
                    safeSpeed: safeSpeed,
                    overSpeed: overSpeed,
                    isRainAlert: roadProvider.isRainProtectionActive,
                    isHeavyRainAlert: roadProvider.isHeavyRainProtectionActive,
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Current Speed',
                          value: currentSpeed.toStringAsFixed(0),
                          suffix: 'km/h',
                          icon: Icons.speed_rounded,
                          accent: Colors.lightBlueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Detected Limit',
                          value: detectedLimit > 0
                              ? detectedLimit.toStringAsFixed(0)
                              : '--',
                          suffix: 'km/h',
                          icon: Icons.traffic_rounded,
                          accent: Colors.redAccent,
                          highlighted: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Safe Speed',
                          value:
                          safeSpeed > 0 ? safeSpeed.toStringAsFixed(0) : '--',
                          suffix: 'km/h',
                          icon: Icons.shield_outlined,
                          accent: Colors.greenAccent,
                          highlighted: roadProvider.isRainProtectionActive ||
                              roadProvider.isHeavyRainProtectionActive,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniStatCard(
                          title: 'Rain Risk',
                          value:
                          roadProvider.displayRainProbability.toStringAsFixed(0),
                          suffix: '%',
                          icon: Icons.water_drop_outlined,
                          accent: Colors.cyanAccent,
                          highlighted: heavyRain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _StatusBanner(
                    roadProvider: roadProvider,
                    overSpeed: overSpeed,
                    safeSpeed: safeSpeed,
                  ),
                  const SizedBox(height: 18),

                  const _DetectedSignCard(),
                  const SizedBox(height: 18),

                  const _SpeedSignHistoryCard(),
                  const SizedBox(height: 18),

                  const _SensorDeviceCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ManualSpeedTestCard extends StatefulWidget {
  const ManualSpeedTestCard({super.key});

  @override
  State<ManualSpeedTestCard> createState() => _ManualSpeedTestCardState();
}

class _ManualSpeedTestCardState extends State<ManualSpeedTestCard> {
  final TextEditingController _speedController =
  TextEditingController(text: '60');
  final TextEditingController _limitController =
  TextEditingController(text: '60');
  final TextEditingController _rainController =
  TextEditingController(text: '80');
  final TextEditingController _tempController =
  TextEditingController(text: '22');

  bool _expanded = false;

  @override
  void dispose() {
    _speedController.dispose();
    _limitController.dispose();
    _rainController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  void _applySpeed(BuildContext context) {
    final double value = double.tryParse(_speedController.text.trim()) ?? 0;
    context.read<SpeedProvider>().setManualSpeed(value);
    context.read<RoadProtectionProvider>().checkRoadProtectionStatus(context);
  }

  void _applyLimit(BuildContext context) {
    final double value = double.tryParse(_limitController.text.trim()) ?? 0;
    context.read<RoadProtectionProvider>().setManualSpeedLimit(
      value,
      label: 'Manual Limit',
    );
    context.read<RoadProtectionProvider>().checkRoadProtectionStatus(context);
  }

  void _applyWeather(BuildContext context) {
    final double rain = double.tryParse(_rainController.text.trim()) ?? 0;
    final double temp = double.tryParse(_tempController.text.trim()) ?? 30;

    context.read<RoadProtectionProvider>().setManualWeather(
      rainProbability: rain,
      temperature: temp,
    );
    context.read<RoadProtectionProvider>().checkRoadProtectionStatus(context);
  }

  void _setQuickSpeed(BuildContext context, double speed) {
    _speedController.text = speed.toStringAsFixed(0);
    context.read<SpeedProvider>().setManualSpeed(speed);
    context.read<RoadProtectionProvider>().checkRoadProtectionStatus(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SpeedProvider, RoadProtectionProvider>(
      builder: (context, speedProvider, roadProvider, child) {
        return _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manual Test Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              speedProvider.manualMode ||
                                  roadProvider.manualWeatherMode
                                  ? 'Manual testing enabled'
                                  : 'Using live GPS and live weather',
                              style: TextStyle(
                                color: speedProvider.manualMode ||
                                    roadProvider.manualWeatherMode
                                    ? Colors.orangeAccent
                                    : const Color(0xFF2BD576),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),

                    const Text(
                      'Test Current Speed',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _speedController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Enter speed in km/h'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _applySpeed(context),
                          child: const Text('Set Speed'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<SpeedProvider>().increaseManualSpeed(5);
                            context
                                .read<RoadProtectionProvider>()
                                .checkRoadProtectionStatus(context);
                            _speedController.text = context
                                .read<SpeedProvider>()
                                .getSpeed
                                .toStringAsFixed(0);
                          },
                          child: const Text('+5'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<SpeedProvider>().decreaseManualSpeed(5);
                            context
                                .read<RoadProtectionProvider>()
                                .checkRoadProtectionStatus(context);
                            _speedController.text = context
                                .read<SpeedProvider>()
                                .getSpeed
                                .toStringAsFixed(0);
                          },
                          child: const Text('-5'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await context.read<SpeedProvider>().disableManualMode();
                            if (mounted) {
                              context
                                  .read<RoadProtectionProvider>()
                                  .checkRoadProtectionStatus(context);
                            }
                          },
                          child: const Text('Live Speed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _quickButton(context, 20),
                        _quickButton(context, 40),
                        _quickButton(context, 60),
                        _quickButton(context, 80),
                        _quickButton(context, 100),
                        _quickButton(context, 120),
                      ],
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Test Detected Speed Limit',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _limitController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Enter speed limit'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _applyLimit(context),
                          child: const Text('Set Limit'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            _limitController.text = '40';
                            _applyLimit(context);
                          },
                          child: const Text('40'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            _limitController.text = '60';
                            _applyLimit(context);
                          },
                          child: const Text('60'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            _limitController.text = '80';
                            _applyLimit(context);
                          },
                          child: const Text('80'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    const Text(
                      'Test Rain / Heavy Rain',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _rainController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Rain probability %'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tempController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Temperature °C'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _applyWeather(context),
                          child: const Text('Set Weather'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _rainController.text = '60';
                            _tempController.text = '25';
                            context.read<RoadProtectionProvider>().setManualNormalRain();
                            context
                                .read<RoadProtectionProvider>()
                                .checkRoadProtectionStatus(context);
                          },
                          child: const Text('Rain Test'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _rainController.text = '90';
                            _tempController.text = '22';
                            context.read<RoadProtectionProvider>().setManualHeavyRain();
                            context
                                .read<RoadProtectionProvider>()
                                .checkRoadProtectionStatus(context);
                          },
                          child: const Text('Heavy Rain'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _rainController.text = '10';
                            _tempController.text = '30';
                            context.read<RoadProtectionProvider>().setManualClearWeather();
                            context
                                .read<RoadProtectionProvider>()
                                .checkRoadProtectionStatus(context);
                          },
                          child: const Text('Clear'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<RoadProtectionProvider>().disableManualWeather();
                            context
                                .read<RoadProtectionProvider>()
                                .checkRoadProtectionStatus(context);
                          },
                          child: const Text('Live Weather'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Current Speed: ${speedProvider.getSpeed.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Detected Limit: ${roadProvider.roadProtectionSpeedLimit.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Safe Speed: ${roadProvider.effectiveSafeSpeed.toStringAsFixed(1)} km/h',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rain: ${roadProvider.displayRainProbability.toStringAsFixed(0)}% | Temp: ${roadProvider.displayTemperature.toStringAsFixed(0)}°C',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (speedProvider.lastError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        speedProvider.lastError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  Widget _quickButton(BuildContext context, double speed) {
    return OutlinedButton(
      onPressed: () => _setQuickSpeed(context, speed),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.white.withOpacity(0.20)),
      ),
      child: Text(
        speed.toStringAsFixed(0),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Consumer2<RoadProtectionProvider, WeatherServiceProvider>(
      builder: (
          BuildContext context,
          RoadProtectionProvider roadProvider,
          WeatherServiceProvider weatherProvider,
          Widget? child,
          ) {
        final String tempText =
            '${roadProvider.displayTemperature.toStringAsFixed(0)}°C';
        final String rainText =
            '${roadProvider.displayRainProbability.toStringAsFixed(0)}% rain';

        return Row(
          children: [
            roadProvider.isRoadProtectionActive ||
                roadProvider.isHeavyRainProtectionActive
                ? Blinker.fade(
              startColor: Colors.orangeAccent,
              endColor: Colors.redAccent,
              duration: const Duration(milliseconds: 600),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 28,
              ),
            )
                : const Icon(
              Icons.shield_outlined,
              color: Colors.white70,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'DriveGuard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        weatherProvider.isDayTime
                            ? Icons.wb_sunny_outlined
                            : Icons.nights_stay_rounded,
                        color: Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tempText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rainText,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertHeroCard extends StatelessWidget {
  final double currentSpeed;
  final double detectedLimit;
  final double safeSpeed;
  final bool overSpeed;
  final bool isRainAlert;
  final bool isHeavyRainAlert;

  const _AlertHeroCard({
    required this.currentSpeed,
    required this.detectedLimit,
    required this.safeSpeed,
    required this.overSpeed,
    required this.isRainAlert,
    required this.isHeavyRainAlert,
  });

  @override
  Widget build(BuildContext context) {
    final Color alertColor = overSpeed
        ? Colors.redAccent
        : isHeavyRainAlert
        ? Colors.deepOrangeAccent
        : isRainAlert
        ? Colors.orangeAccent
        : const Color(0xFF2BD576);

    final String statusText = overSpeed
        ? 'Overspeed detected'
        : isHeavyRainAlert
        ? 'Heavy rain danger'
        : isRainAlert
        ? 'Weather caution'
        : 'Safe driving';

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live Speed Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: alertColor.withOpacity(0.35)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: alertColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 290,
              height: 320,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(290, 290),
                    painter: GaugePainter(
                      speed: currentSpeed,
                      safeSpeed: safeSpeed,
                      maxSpeed: 120,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSpeed.toStringAsFixed(0),
                        style: TextStyle(
                          color: overSpeed ? Colors.redAccent : Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'KM / H',
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    child: _DetectedSpeedBadge(
                      value: detectedLimit,
                      alert: overSpeed,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        safeSpeed > 0
                            ? 'Safe speed ${safeSpeed.toStringAsFixed(0)} km/h'
                            : 'No safe speed available',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedSpeedBadge extends StatelessWidget {
  final double value;
  final bool alert;

  const _DetectedSpeedBadge({
    required this.value,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: alert ? Colors.redAccent : const Color(0xFFFF5656),
          width: 6,
        ),
        boxShadow: [
          BoxShadow(
            color: (alert ? Colors.redAccent : Colors.black).withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        value > 0 ? value.toStringAsFixed(0) : '--',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final Color accent;
  final bool highlighted;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.accent,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: highlighted ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
                TextSpan(
                  text: ' $suffix',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final RoadProtectionProvider roadProvider;
  final bool overSpeed;
  final double safeSpeed;

  const _StatusBanner({
    required this.roadProvider,
    required this.overSpeed,
    required this.safeSpeed,
  });

  @override
  Widget build(BuildContext context) {
    late final String message;
    late final Color color;
    late final IconData icon;

    if (overSpeed) {
      message =
      'Overspeed detected — reduce speed to ${safeSpeed.toStringAsFixed(0)} km/h';
      color = Colors.redAccent;
      icon = Icons.crisis_alert_rounded;
    } else if (roadProvider.isHeavyRainProtectionActive) {
      message =
      'Heavy rain detected — reduce speed to ${safeSpeed.toStringAsFixed(0)} km/h';
      color = Colors.deepOrangeAccent;
      icon = Icons.thunderstorm_rounded;
    } else if (roadProvider.isRainProtectionActive) {
      message =
      'Rain detected — reduce speed to ${safeSpeed.toStringAsFixed(0)} km/h';
      color = Colors.orangeAccent;
      icon = Icons.grain_rounded;
    } else {
      message = roadProvider.safetyAdvice;
      color = const Color(0xFF2BD576);
      icon = Icons.verified_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.22),
            color.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedSignCard extends StatelessWidget {
  const _DetectedSignCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<RoadProtectionProvider>(
      builder: (
          BuildContext context,
          RoadProtectionProvider roadProvider,
          Widget? child,
          ) {
        final String detectedLabel =
        (roadProvider.detectedSign?.lables ?? []).isNotEmpty
            ? roadProvider.detectedSign!.lables!.first
            : 'No traffic sign detected yet';

        return _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.traffic_rounded, color: Colors.deepOrangeAccent),
                  SizedBox(width: 10),
                  Text(
                    'Detected Traffic Sign',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepOrangeAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.deepOrangeAccent.withOpacity(0.30),
                  ),
                ),
                child: Text(
                  detectedLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
}

class _SpeedSignHistoryCard extends StatelessWidget {
  const _SpeedSignHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<RoadProtectionProvider>(
      builder: (
          BuildContext context,
          RoadProtectionProvider roadProvider,
          Widget? child,
          ) {
        final history = roadProvider.speedSignHistory;

        return _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: Colors.purpleAccent),
                  SizedBox(width: 10),
                  Text(
                    'Traffic Speed Sign History',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: history.isEmpty
                    ? Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'No speed sign history yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : CustomPaint(
                  painter: _HistoryChartPainter(
                    values: history.map((e) => e.speedLimit).toList(),
                  ),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 14),
              ...history.take(5).map(
                    (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              item.speedLimit.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${item.detectedAt.hour.toString().padLeft(2, '0')}:${item.detectedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SensorDeviceCard extends StatelessWidget {
  const _SensorDeviceCard();

  @override
  Widget build(BuildContext context) {
    return Consumer<EspDeviceProvider>(
      builder: (
          BuildContext context,
          EspDeviceProvider espProvider,
          Widget? child,
          ) {
        final bool connected = espProvider.targetDevice != null;

        return _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_alt_outlined, color: Colors.cyanAccent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Road Monitoring Device',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: connected
                          ? const Color(0xFF2BD576).withOpacity(0.12)
                          : Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: connected
                            ? const Color(0xFF2BD576).withOpacity(0.30)
                            : Colors.redAccent.withOpacity(0.30),
                      ),
                    ),
                    child: Text(
                      connected ? 'CONNECTED' : 'OFFLINE',
                      style: TextStyle(
                        color: connected
                            ? const Color(0xFF2BD576)
                            : Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (!connected)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      espProvider.startScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.withOpacity(0.12),
                      foregroundColor: Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.cyanAccent.withOpacity(0.25),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.bluetooth_searching_rounded),
                    label: const Text(
                      'Connect Camera Device',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              else
                _PreviewImageCard(imageBytes: espProvider.completedImage),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewImageCard extends StatelessWidget {
  final Uint8List? imageBytes;

  const _PreviewImageCard({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.memory(
        imageBytes!,
        width: double.infinity,
        height: 240,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1A30).withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
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
    final radius = math.min(size.width, size.height) / 2 - 16;

    const startAngle = -math.pi * 0.85;
    const sweepAngle = math.pi * 1.7;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = Colors.white.withOpacity(0.08)
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    final segments = 48;
    final gap = sweepAngle * 0.008;
    final segSweep = (sweepAngle / segments) - gap;

    final safeRatio =
    safeSpeed <= 0 ? 0.0 : (safeSpeed / maxSpeed).clamp(0.0, 1.0);
    final speedRatio = (speed / maxSpeed).clamp(0.0, 1.0);

    final safeSegs = (segments * safeRatio).round();
    final activeSegs = (segments * speedRatio).round();

    for (int i = 0; i < segments; i++) {
      final angle = startAngle + (sweepAngle / segments) * i;

      Color color;
      if (i < activeSegs) {
        color = i <= safeSegs ? const Color(0xFF2BD576) : Colors.redAccent;
      } else {
        color = Colors.white.withOpacity(0.06);
      }

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i == safeSegs && safeSegs > 0 ? 18 : 13
        ..color = i == safeSegs && safeSegs > 0 ? Colors.orangeAccent : color;

      canvas.drawArc(rect, angle, segSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return speed != oldDelegate.speed ||
        safeSpeed != oldDelegate.safeSpeed ||
        maxSpeed != oldDelegate.maxSpeed;
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<double> values;

  _HistoryChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final double left = 14;
    final double top = 14;
    final double width = size.width - 28;
    final double height = size.height - 28;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = top + (height / 3) * i;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + width, y),
        gridPaint,
      );
    }

    if (values.isEmpty) return;

    final double maxValue = values.reduce(math.max).clamp(20, 120).toDouble();
    const double minValue = 0;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = left + (width / math.max(values.length - 1, 1)) * i;
      final normalized =
          (values[i] - minValue) /
              ((maxValue - minValue) == 0 ? 1 : (maxValue - minValue));
      final y = top + height - (normalized * height);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final linePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, top + height)
      ..lineTo(points.first.dx, top + height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.redAccent.withOpacity(0.25),
          Colors.redAccent.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(left, top, width, height));

    canvas.drawPath(fillPath, fillPaint);

    final pointPaint = Paint()..color = Colors.white;
    for (final p in points) {
      canvas.drawCircle(p, 4, pointPaint);
      canvas.drawCircle(
        p,
        7,
        Paint()..color = Colors.redAccent.withOpacity(0.20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}