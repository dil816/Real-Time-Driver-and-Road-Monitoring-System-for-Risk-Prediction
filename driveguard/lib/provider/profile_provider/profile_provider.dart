import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/drive_profile.dart';
import '../../services/api_service.dart';
import '../../services/ws_service.dart';

class ProfileProvider extends ChangeNotifier {
  static const int _maxAlerts = 50;

  String host;
  late WsService _ws;
  late ApiService _api;
  StreamSubscription<DriverProfile>? _sub;

  // State
  Map<String, DriverProfile> profiles = {};
  List<String> alertLog = [];
  List<String> deviceIds = [];
  bool connected = false;
  String? selectedDevice;

  ProfileProvider(this.host) {
    _ws = WsService(host);
    _api = ApiService(host);
    _sub = _ws.stream.listen(_onProfile, onError: (_) => _setConnected(false));
    _setConnected(true);
    _loadDevices();
  }

  void updateHost(String newHost) {
    _sub?.cancel();
    _ws.disconnect();

    host = newHost;
    profiles = {};
    alertLog = [];
    deviceIds = [];
    connected = false;
    selectedDevice = null;

    _ws = WsService(newHost);
    _api = ApiService(newHost);
    _sub = _ws.stream.listen(_onProfile, onError: (_) => _setConnected(false));
    _setConnected(true);
    _loadDevices();

    notifyListeners();
  }

  void _onProfile(DriverProfile p) {
    profiles[p.deviceId] = p;
    _setConnected(true);

    if (!deviceIds.contains(p.deviceId)) {
      deviceIds = [...deviceIds, p.deviceId];
      selectedDevice ??= p.deviceId;
    }

    if (p.alerts.isNotEmpty) {
      final ts = DateTime.now();
      final stamp =
          '[${ts.hour.toString().padLeft(2, '0')}:'
          '${ts.minute.toString().padLeft(2, '0')}:'
          '${ts.second.toString().padLeft(2, '0')}]';
      for (final a in p.alerts) {
        alertLog = ['$stamp [${p.deviceId}] $a', ...alertLog];
        if (alertLog.length > _maxAlerts) {
          alertLog = alertLog.sublist(0, _maxAlerts);
        }
      }
    }

    notifyListeners();
  }

  Future<void> _loadDevices() async {
    try {
      final ids = await _api.fetchDevices();
      if (ids.isNotEmpty) {
        deviceIds = ids;
        selectedDevice ??= ids.first;
        notifyListeners();
      }
    } catch (_) {}
  }

  void selectDevice(String id) {
    selectedDevice = id;
    notifyListeners();
  }

  void _setConnected(bool v) {
    if (connected != v) {
      connected = v;
      notifyListeners();
    }
  }

  DriverProfile? get currentProfile =>
      selectedDevice != null ? profiles[selectedDevice!] : null;

  @override
  void dispose() {
    _sub?.cancel();
    _ws.disconnect();
    super.dispose();
  }
}