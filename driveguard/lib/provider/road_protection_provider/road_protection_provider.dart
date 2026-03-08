import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:driveguard/http_client/dio_client.dart';
import 'package:driveguard/models/road_sign_model.dart';
import 'package:driveguard/provider/speed_provider/speed_provider.dart';
import 'package:driveguard/provider/weather_service_provider/weather_service_provider.dart';
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
  Timer? _stopBeepTimer;

  bool isSpeedSignAlertOn = false;
  bool isRoadProtectionActive = false;
  bool isRainProtectionActive = false;

  double roadProtectionSpeedLimit = 0.0;
  double providerSpeed = 0.0;
  double providerRainProbability = 0.0;
  double providerTemperature = 0.0;

  double? _lastSpeedLimitAlerted;
  DateTime? _lastAlertAt;

  SpeedProvider? speedProvider;
  WeatherServiceProvider? weatherProvider;
  RoadSignModel? detectedSign;

  final List<SpeedSignHistoryItem> _speedSignHistory = [];

  bool get getRoadProtectionStatus => isRoadProtectionActive;

  List<SpeedSignHistoryItem> get speedSignHistory =>
      List.unmodifiable(_speedSignHistory.reversed);

  void setManualSpeedLimit(double limit, {String label = 'Manual Speed Limit'}) {
    roadProtectionSpeedLimit = limit;
    _pushSpeedHistory(label: '$label ${limit.toStringAsFixed(0)}', speedLimit: limit);
    notifyListeners();
  }

  void checkRoadProtectionStatus(BuildContext context) {
    speedProvider = Provider.of<SpeedProvider>(context, listen: false);
    weatherProvider = Provider.of<WeatherServiceProvider>(
      context,
      listen: false,
    );

    providerSpeed = speedProvider?.getSpeed ?? 0.0;
    providerRainProbability =
        double.tryParse(weatherProvider?.getRainProbability ?? '0') ?? 0.0;
    providerTemperature =
        double.tryParse(weatherProvider?.getTemperature ?? '0') ?? 0.0;

    isRoadProtectionActive =
        providerSpeed > roadProtectionSpeedLimit && roadProtectionSpeedLimit > 0.0;

    isRainProtectionActive =
        providerRainProbability > 50 && providerTemperature < 26;

    notifyListeners();
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

  Future<void> _triggerSpeedSignBeep(double speedLimit) async {
    final now = DateTime.now();
    final recentlyAlerted = _lastAlertAt != null &&
        now.difference(_lastAlertAt!).inMilliseconds < 2500;

    if (recentlyAlerted && _lastSpeedLimitAlerted == speedLimit) return;

    _lastSpeedLimitAlerted = speedLimit;
    _lastAlertAt = now;

    isSpeedSignAlertOn = true;
    notifyListeners();

    _stopBeepTimer?.cancel();

    try {
      await _beepPlayer.stop();
      await _beepPlayer.setVolume(1.0);
      await _beepPlayer.setReleaseMode(ReleaseMode.loop);
      await _beepPlayer.play(AssetSource('sounds/beep.mp3'));

      _stopBeepTimer = Timer(const Duration(seconds: 2), () async {
        await _beepPlayer.stop();
        isSpeedSignAlertOn = false;
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Beep error: $e');
      }
      isSpeedSignAlertOn = false;
      notifyListeners();
    }
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

            await _triggerSpeedSignBeep(speedLimit);
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
    _stopBeepTimer?.cancel();
    _beepPlayer.dispose();
    super.dispose();
  }
}