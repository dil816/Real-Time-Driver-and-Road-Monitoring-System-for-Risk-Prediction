import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:driveguard/http_client/dio_client.dart';
import 'package:driveguard/models/road_sign_model.dart';
import 'package:driveguard/provider/speed_provider/speed_provider.dart';
import 'package:driveguard/provider/weather_service_provider/weather_service_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class RoadProtectionProvider extends ChangeNotifier {
  bool isRoadProtectionActive = false;
  bool isRainProtectionActive = false;
  double roadProtectionSpeedLimit = 0.0;

  double providerSpeed = 0.0;
  double providerRainProbability = 0.0;
  double providerTemperature = 0.0;

  SpeedProvider? speed_provider;
  WeatherServiceProvider? weather_provider;

  RoadSignModel? detected_sign;

  bool get getRoadProtectionStatus => isRoadProtectionActive;

  void checkRoadProtectionStatus(BuildContext context) {
    speed_provider = Provider.of<SpeedProvider>(context, listen: false);
    weather_provider = Provider.of<WeatherServiceProvider>(
      context,
      listen: false,
    );
    providerSpeed = speed_provider!.getSpeed;
    providerRainProbability = double.parse(
      weather_provider!.getRainProbability,
    );
    providerTemperature = double.parse(weather_provider!.getTemperature);

    if ((providerSpeed > roadProtectionSpeedLimit &&
        roadProtectionSpeedLimit > 0.0)) {
      isRoadProtectionActive = true;
    } else {
      isRoadProtectionActive = false;
    }

    if ((providerRainProbability > 50 && providerTemperature < 26)) {
      isRainProtectionActive = true;
    } else {
      isRainProtectionActive = false;
    }
    notifyListeners();
  }

  Future<void> getRoadSignPrediction({required Uint8List imageBytes}) async {
    final dioClient = DioClient().dio;
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/captured_sign.jpg').create();

    await file.writeAsBytes(imageBytes);
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: 'captured_sign.jpg',
      ),
    });

    Response response = await dioClient.post(
      "https://traffic-sign-detection-480905.uc.r.appspot.com/predict?file",
      data: formData,
    );

    if (response.statusCode == 200 && response.data != null) {
      print("Prediction Result: ${response.data}");
      final data = response.data;
      detected_sign = RoadSignModel.fromJson(data);
      if ((detected_sign?.lables ?? []).isNotEmpty) {
        RegExp regExp = RegExp(r'\d+');
        String? match = regExp.stringMatch(detected_sign?.lables?.first ?? "");

        if (match != null) {
          double speedLimit = double.parse(match);
          roadProtectionSpeedLimit = speedLimit;
        }
      }
    } else {
      print("Failed to get prediction. Status code: ${response.statusCode}");
    }
    notifyListeners();
  }
}
