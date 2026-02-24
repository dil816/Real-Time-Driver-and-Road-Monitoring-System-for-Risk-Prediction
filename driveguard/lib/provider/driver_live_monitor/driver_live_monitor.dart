import 'package:flutter/widgets.dart';

class DriverLiveMonitor extends ChangeNotifier {
  double bloodOxygenLevel = 0;
  double temperature = 0;
  double bloodPreasure = 0;

  bool isDriverAlert = false;

  void setData(List<String> data) {
    bloodPreasure = double.parse(data[0]);
    bloodOxygenLevel = double.parse(data[1]);
    temperature = double.parse(data[2]);
    notifyListeners();
    checkDriverAlert();
  }

  void checkDriverAlert() {
    if (bloodPreasure < 50 || bloodPreasure > 120 || bloodOxygenLevel < 90) {
      isDriverAlert = true;
    } else {
      isDriverAlert = false;
    }
    notifyListeners();
  }
}
