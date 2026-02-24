import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';

class SpeedProvider extends ChangeNotifier {
  double speed = 0.0;
  StreamSubscription? _positionStreamSubscription;

  double get getSpeed => speed;

  Future<void> getSpeedData() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error(
        'Location services are disabled. Please enable them in settings.',
      );
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied. We cannot request permissions.',
      );
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            double speedMps = position.speed;
            double speedKph = speedMps * 3.6;

            speed = double.parse(speedKph.toStringAsFixed(1));

            print("Current speed: ${speedKph.toStringAsFixed(1)} km/h");
          },
        );
    notifyListeners();
  }

  void disposeStream() {
    _positionStreamSubscription?.cancel();
  }
}
