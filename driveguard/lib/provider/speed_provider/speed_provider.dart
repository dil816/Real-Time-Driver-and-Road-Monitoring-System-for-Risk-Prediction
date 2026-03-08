import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class SpeedProvider extends ChangeNotifier {
  double _speed = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _manualMode = false;
  bool _isListening = false;
  String? _lastError;

  double get getSpeed => _speed;
  bool get manualMode => _manualMode;
  bool get isListening => _isListening;
  String? get lastError => _lastError;

  Future<void> getSpeedData() async {
    if (_manualMode) return;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError =
        'Location services are disabled. Please enable them in settings.';
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _lastError = 'Location permissions are denied.';
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _lastError =
        'Location permissions are permanently denied. Please enable them from settings.';
        notifyListeners();
        return;
      }

      _lastError = null;

      await _positionStreamSubscription?.cancel();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );

      _isListening = true;
      notifyListeners();

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
            (Position position) {
          if (_manualMode) return;

          final double speedMps = position.speed;
          final double speedKph = speedMps * 3.6;

          _speed = double.parse(speedKph.toStringAsFixed(1));
          _lastError = null;
          notifyListeners();

          if (kDebugMode) {
            print('Current speed: ${_speed.toStringAsFixed(1)} km/h');
          }
        },
        onError: (error) {
          _lastError = error.toString();
          _isListening = false;
          notifyListeners();

          if (kDebugMode) {
            print('Speed stream error: $error');
          }
        },
      );
    } catch (e) {
      _lastError = e.toString();
      _isListening = false;
      notifyListeners();

      if (kDebugMode) {
        print('Speed provider error: $e');
      }
    }
  }

  void setManualSpeed(double value) {
    _manualMode = true;
    _speed = double.parse(value.toStringAsFixed(1));
    _lastError = null;
    notifyListeners();

    if (kDebugMode) {
      print('Manual speed set: ${_speed.toStringAsFixed(1)} km/h');
    }
  }

  void increaseManualSpeed([double step = 5]) {
    if (!_manualMode) {
      _manualMode = true;
    }

    _speed = double.parse((_speed + step).toStringAsFixed(1));
    notifyListeners();
  }

  void decreaseManualSpeed([double step = 5]) {
    if (!_manualMode) {
      _manualMode = true;
    }

    _speed = _speed - step;
    if (_speed < 0) _speed = 0;
    _speed = double.parse(_speed.toStringAsFixed(1));
    notifyListeners();
  }

  Future<void> disableManualMode() async {
    _manualMode = false;
    notifyListeners();
    await getSpeedData();
  }

  void resetSpeed() {
    _speed = 0.0;
    notifyListeners();
  }

  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isListening = false;
    notifyListeners();
  }

  void disposeStream() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isListening = false;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}