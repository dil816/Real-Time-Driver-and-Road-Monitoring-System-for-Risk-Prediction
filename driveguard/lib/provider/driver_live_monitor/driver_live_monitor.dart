import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class DriverLiveMonitor extends ChangeNotifier {

  double bloodOxygenLevel = 0;
  double temperature = 0;
  double bloodPressure = 0;
  double cabinNoiseLevel = 0;

  static const double oxygenWarningThreshold = 90;
  static const double highBloodPressureThreshold = 120;
  static const double lowBloodPressureThreshold = 50;
  static const double temperatureWarningThreshold = 27;
  static const double highNoiseThreshold = 85;
  static const double lowNoiseThreshold = 30;


  bool oxygenWarning = false;
  bool bloodPressureWarning = false;
  bool temperatureWarning = false;
  bool highNoiseWarning = false;
  bool lowNoiseWarning = false;

  bool isDriverAlert = false;
  String? alertMessage;

  final AudioPlayer audioPlayer = AudioPlayer();

  void setData(List<String> data) {
    bloodPressure = double.parse(data[0]);
    bloodOxygenLevel = double.parse(data[1]);
    temperature = double.parse(data[2]);
    cabinNoiseLevel = double.parse(data[3]);

    notifyListeners();
    evaluateDriverCondition();

  }

  void evaluateDriverCondition() {

    oxygenWarning = false;
    bloodPressureWarning = false;
    temperatureWarning = false;
    highNoiseWarning = false;
    lowNoiseWarning = false;

    if (bloodOxygenLevel <= oxygenWarningThreshold) {
      oxygenWarning = true;
    }

    if (bloodPressure > highBloodPressureThreshold ||
        bloodPressure < lowBloodPressureThreshold) {
      bloodPressureWarning = true;
    }

    if (temperature > temperatureWarningThreshold) {
      temperatureWarning = true;
    }

    if (cabinNoiseLevel > highNoiseThreshold) {
      highNoiseWarning = true;
    }

    if (cabinNoiseLevel < lowNoiseThreshold) {
      lowNoiseWarning = true;
    }

    isDriverAlert = oxygenWarning ||
        bloodPressureWarning ||
        temperatureWarning ||
        highNoiseWarning ||
        lowNoiseWarning;

    if (isDriverAlert) {
      alertMessage = buildAlertMessage();
      // playAlertSound();
    } else {
      alertMessage = "Driver Condition Normal";
      stopAlertSound();
    }
  }

  String buildAlertMessage() {
    List<String> issues = [];

    if (oxygenWarning) issues.add("Low Oxygen");
    if (bloodPressureWarning) issues.add("Abnormal Blood Pressure");
    if (temperatureWarning) issues.add("High Temperature");
    if (highNoiseWarning) issues.add("High Cabin Noise");
    if (lowNoiseWarning) issues.add("Low Cabin Noise");

    return "ALERT: ${issues.join(', ')}. Please take rest.";
  }

  void playAlertSound() async {
    audioPlayer.setReleaseMode(ReleaseMode.loop);
    await audioPlayer.play(AssetSource('audio/warning.mp3'));
  }

  void stopAlertSound() async {
    await audioPlayer.stop();
  }
}