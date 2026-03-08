import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:driveguard/http_client/dio_client.dart';
import 'package:driveguard/models/road_sign_model.dart';
import 'package:driveguard/provider/speed_provider/speed_provider.dart';
import 'package:driveguard/provider/weather_service_provider/weather_service_provider.dart';
import 'package:driveguard/services/app_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class SpeedSignHistoryItem {
  final String label;
  final double speedLimit;
  final DateTime detectedAt;

  const SpeedSignHistoryItem({
    required this.label,
    required this.speedLimit,
    required this.detectedAt,
  });
}

class RoadProtectionProvider extends ChangeNotifier {
  final AudioPlayer _beepPlayer = AudioPlayer();
  Timer? _beepStopTimer;

  bool isSpeedSignAlertOn = false;
  bool isRoadProtectionActive = false;
  bool isRainProtectionActive = false;
  bool isHeavyRainProtectionActive = false;

  bool _continuousBeepActive = false;
  bool _singleBeepActive = false;

  final Map<String, DateTime> _singleBeepHistory = {};

  double roadProtectionSpeedLimit = 0.0;
  double providerSpeed = 0.0;
  double providerRainProbability = 0.0;
  double providerTemperature = 0.0;

  double effectiveSafeSpeed = 0.0;
  String safetyAdvice = 'Safe to drive';

  bool _manualWeatherMode = false;
  double _manualRainProbability = 0.0;
  double _manualTemperature = 28.0;

  double? _weatherReferenceSpeed;

  bool _wasHeavyRainActive = false;
  bool _wasOverspeedNotified = false;
  bool _wasRainNotified = false;
  bool _wasHeavyRainNotified = false;
  double? _lastNotifiedSpeedLimit;

  SpeedProvider? speedProvider;
  WeatherServiceProvider? weatherProvider;
  RoadSignModel? detectedSign;

  final List<SpeedSignHistoryItem> _speedSignHistory = [];

  bool get getRoadProtectionStatus => isRoadProtectionActive;
  bool get manualWeatherMode => _manualWeatherMode;

  double get displayRainProbability =>
      _manualWeatherMode ? _manualRainProbability : providerRainProbability;

  double get displayTemperature =>
      _manualWeatherMode ? _manualTemperature : providerTemperature;

  List<SpeedSignHistoryItem> get speedSignHistory =>
      List.unmodifiable(_speedSignHistory.reversed);

  void setManualSpeedLimit(
      double limit, {
        String label = 'Manual Speed Limit',
      }) {
    roadProtectionSpeedLimit = limit;
    _pushSpeedHistory(
      label: '$label ${limit.toStringAsFixed(0)}',
      speedLimit: limit,
    );
    notifyListeners();
  }

  void setManualWeather({
    required double rainProbability,
    required double temperature,
  }) {
    _manualWeatherMode = true;
    _manualRainProbability = rainProbability;
    _manualTemperature = temperature;
    notifyListeners();
  }

  void disableManualWeather() {
    _manualWeatherMode = false;
    notifyListeners();
  }

  void setManualHeavyRain() {
    _manualWeatherMode = true;
    _manualRainProbability = 90;
    _manualTemperature = 22;
    notifyListeners();
  }

  void setManualNormalRain() {
    _manualWeatherMode = true;
    _manualRainProbability = 60;
    _manualTemperature = 25;
    notifyListeners();
  }

  void setManualClearWeather() {
    _manualWeatherMode = true;
    _manualRainProbability = 10;
    _manualTemperature = 30;
    notifyListeners();
  }

  void checkRoadProtectionStatus(BuildContext context) {
    speedProvider = Provider.of<SpeedProvider>(context, listen: false);
    weatherProvider = Provider.of<WeatherServiceProvider>(
      context,
      listen: false,
    );

    providerSpeed = speedProvider?.getSpeed ?? 0.0;

    final double liveRain =
        double.tryParse(weatherProvider?.getRainProbability ?? '0') ?? 0.0;
    final double liveTemp =
        double.tryParse(weatherProvider?.getTemperature ?? '0') ?? 0.0;

    providerRainProbability =
    _manualWeatherMode ? _manualRainProbability : liveRain;
    providerTemperature = _manualWeatherMode ? _manualTemperature : liveTemp;

    isRainProtectionActive =
        providerRainProbability > 50 && providerTemperature < 26;

    isHeavyRainProtectionActive =
        providerRainProbability >= 75 && providerTemperature < 25;

    if (isRainProtectionActive && _weatherReferenceSpeed == null) {
      _weatherReferenceSpeed =
      roadProtectionSpeedLimit > 0 ? roadProtectionSpeedLimit : providerSpeed;
    }

    if (!isRainProtectionActive) {
      _weatherReferenceSpeed = null;
    }

    double baseSpeed = 0.0;

    if (roadProtectionSpeedLimit > 0) {
      baseSpeed = roadProtectionSpeedLimit;
    } else if (_weatherReferenceSpeed != null) {
      baseSpeed = _weatherReferenceSpeed!;
    }

    if (isHeavyRainProtectionActive) {
      effectiveSafeSpeed = math.max(0, baseSpeed - 20);
    } else if (isRainProtectionActive) {
      effectiveSafeSpeed = math.max(0, baseSpeed - 10);
    } else {
      effectiveSafeSpeed =
      roadProtectionSpeedLimit > 0 ? roadProtectionSpeedLimit : 0;
    }

    isRoadProtectionActive =
        effectiveSafeSpeed > 0 && providerSpeed > effectiveSafeSpeed;

    if (isHeavyRainProtectionActive && !_wasHeavyRainActive) {
      _playSingleBeep(key: 'heavy_rain');
    }
    _wasHeavyRainActive = isHeavyRainProtectionActive;

    if (isRoadProtectionActive) {
      _startContinuousBeep();
    } else {
      _stopContinuousBeep();
    }

    _updateSafetyAdvice();
    _handleNotifications();
    notifyListeners();
  }

  void _handleNotifications() {
    if (isRoadProtectionActive && !_wasOverspeedNotified) {
      AppNotificationService.instance.show(
        id: 1001,
        title: 'Overspeed Alert',
        body: 'Reduce speed to ${effectiveSafeSpeed.toStringAsFixed(0)} km/h',
      );
    }
    _wasOverspeedNotified = isRoadProtectionActive;

    if (isHeavyRainProtectionActive && !_wasHeavyRainNotified) {
      AppNotificationService.instance.show(
        id: 1002,
        title: 'Heavy Rain Alert',
        body:
        'Heavy rain detected. Reduce speed to ${effectiveSafeSpeed.toStringAsFixed(0)} km/h',
      );
    }
    _wasHeavyRainNotified = isHeavyRainProtectionActive;

    if (isRainProtectionActive &&
        !isHeavyRainProtectionActive &&
        !_wasRainNotified) {
      AppNotificationService.instance.show(
        id: 1003,
        title: 'Rain Alert',
        body:
        'Rain detected. Reduce speed to ${effectiveSafeSpeed.toStringAsFixed(0)} km/h',
      );
    }
    _wasRainNotified =
        isRainProtectionActive && !isHeavyRainProtectionActive;
  }

  void _updateSafetyAdvice() {
    if (isRoadProtectionActive && isHeavyRainProtectionActive) {
      safetyAdvice =
      'Heavy rain and overspeed detected — slow down to ${effectiveSafeSpeed.toStringAsFixed(0)} km/h';
    } else if (isRoadProtectionActive && isRainProtectionActive) {
      safetyAdvice =
      'Rain and overspeed detected — slow down to ${effectiveSafeSpeed.toStringAsFixed(0)} km/h';
    } else if (isRoadProtectionActive) {
      safetyAdvice =
      'Overspeed detected — slow down to ${effectiveSafeSpeed.toStringAsFixed(0)} km/h';
    } else if (isHeavyRainProtectionActive) {
      safetyAdvice =
      'Heavy rain detected — recommended safe speed ${effectiveSafeSpeed.toStringAsFixed(0)} km/h';
    } else if (isRainProtectionActive) {
      safetyAdvice =
      'Rain detected — recommended safe speed ${effectiveSafeSpeed.toStringAsFixed(0)} km/h';
    } else if (roadProtectionSpeedLimit > 0) {
      safetyAdvice =
      'Detected speed limit ${roadProtectionSpeedLimit.toStringAsFixed(0)} km/h';
    } else {
      safetyAdvice = 'Safe to drive';
    }
  }

  void _pushSpeedHistory({
    required String label,
    required double speedLimit,
  }) {
    _speedSignHistory.add(
      SpeedSignHistoryItem(
        label: label,
        speedLimit: speedLimit,
        detectedAt: DateTime.now(),
      ),
    );

    if (_speedSignHistory.length > 10) {
      _speedSignHistory.removeAt(0);
    }
  }

  Future<void> _playSingleBeep({
    required String key,
    Duration duration = const Duration(seconds: 2),
  }) async {
    if (_continuousBeepActive) return;

    final now = DateTime.now();
    final lastPlayed = _singleBeepHistory[key];

    if (lastPlayed != null &&
        now.difference(lastPlayed).inMilliseconds < 2500) {
      return;
    }

    _singleBeepHistory[key] = now;
    _singleBeepActive = true;
    isSpeedSignAlertOn = true;
    notifyListeners();

    _beepStopTimer?.cancel();

    try {
      await _beepPlayer.stop();
      await _beepPlayer.setVolume(1.0);
      await _beepPlayer.setReleaseMode(ReleaseMode.loop);
      await _beepPlayer.play(AssetSource('sounds/beep.mp3'));

      _beepStopTimer = Timer(duration, () async {
        if (_continuousBeepActive) return;
        await _beepPlayer.stop();
        _singleBeepActive = false;
        isSpeedSignAlertOn = false;
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Single beep error: $e');
      }
      _singleBeepActive = false;
      isSpeedSignAlertOn = false;
      notifyListeners();
    }
  }

  Future<void> _startContinuousBeep() async {
    if (_continuousBeepActive) return;

    _continuousBeepActive = true;
    isSpeedSignAlertOn = true;
    _beepStopTimer?.cancel();

    try {
      await _beepPlayer.stop();
      await _beepPlayer.setVolume(1.0);
      await _beepPlayer.setReleaseMode(ReleaseMode.loop);
      await _beepPlayer.play(AssetSource('sounds/beep.mp3'));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Continuous beep error: $e');
      }
      _continuousBeepActive = false;
      isSpeedSignAlertOn = false;
      notifyListeners();
    }
  }

  Future<void> _stopContinuousBeep() async {
    if (!_continuousBeepActive) return;

    try {
      await _beepPlayer.stop();
    } catch (_) {}

    _continuousBeepActive = false;
    if (!_singleBeepActive) {
      isSpeedSignAlertOn = false;
    }
    notifyListeners();
  }

  Future<void> getRoadSignPrediction({required Uint8List imageBytes}) async {
    try {
      final dioClient = DioClient().dio;
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/captured_sign.jpg').create();

      await file.writeAsBytes(imageBytes);

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: 'captured_sign.jpg',
        ),
      });

      final response = await dioClient.post(
        'https://traffic-sign-detection-480905.uc.r.appspot.com/predict',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        if (kDebugMode) {
          print('Prediction Result: ${response.data}');
        }

        final data = response.data;
        detectedSign = RoadSignModel.fromJson(data);

        final labels = detectedSign?.lables ?? [];
        if (labels.isNotEmpty) {
          final firstLabel = labels.first;
          final regExp = RegExp(r'\d+');
          final match = regExp.stringMatch(firstLabel);

          if (match != null) {
            final speedLimit = double.parse(match);
            roadProtectionSpeedLimit = speedLimit;

            _pushSpeedHistory(
              label: firstLabel,
              speedLimit: speedLimit,
            );

            if (_lastNotifiedSpeedLimit != speedLimit) {
              _lastNotifiedSpeedLimit = speedLimit;
              await AppNotificationService.instance.show(
                id: 1000,
                title: 'Speed Sign Detected',
                body:
                'Detected speed limit ${speedLimit.toStringAsFixed(0)} km/h',
              );
            }

            await _playSingleBeep(
              key: 'speed_limit_${speedLimit.toStringAsFixed(0)}',
            );
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to get prediction. Status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Prediction error: $e');
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _beepStopTimer?.cancel();
    _beepPlayer.dispose();
    super.dispose();
  }
}