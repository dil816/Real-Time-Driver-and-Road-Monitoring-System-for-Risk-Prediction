import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_weather_flutter/google_weather_flutter.dart';

class WeatherServiceProvider extends ChangeNotifier {
  final weatherService = WeatherService(
    apiKey: 'AIzaSyAcA81-KG1e5vpHRlKlPfn1UUHZBJAMzTA',
  );

  String temperature = "0";
  String rainProbability = "0";
  String rainProbabilitytype = "";
  String condition = "";
  bool isWeatherConnected = false;
  bool isDayTime = true;

  bool get getWeatherConnected => isWeatherConnected;

  String get getTemperature => temperature;

  String get getRainProbability => rainProbability;

  String get getRainProbabilitytype => rainProbabilitytype;

  String get getCondition => condition;

  Future<void> getCurentWeather() async {
    try {
      final position = await getCurrentLoaction();
      if (position != null) {
        final currentConditions = await weatherService.getCurrentConditions(
          position.latitude,
          position.longitude,
        );
        temperature = currentConditions.feelsLikeTemperature.degrees
            .toStringAsFixed(2);
        rainProbability = currentConditions.precipitation.probability.percent
            .toStringAsFixed(2);
        isDayTime = currentConditions.isDaytime;
        rainProbabilitytype = currentConditions.precipitation.probability.type;
        condition = currentConditions.weatherCondition.description.text;
        isWeatherConnected = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<Position> getCurrentLoaction() async {
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

    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
    return position;
  }
}
