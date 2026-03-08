import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:driveguard/provider/driver_live_monitor/driver_live_monitor.dart';
import 'package:driveguard/provider/road_protection_provider/road_protection_provider.dart';
import 'package:driveguard/provider/speed_provider/speed_provider.dart';
import 'package:driveguard/provider/weather_service_provider/weather_service_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../main.dart';

class EspDeviceProvider extends ChangeNotifier {
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? imgCharacteristic;

  BluetoothDevice? targetDevice2;
  BluetoothCharacteristic? targetCharacteristic;

  final List<int> _accumulatedBytes = [];
  Uint8List? completedImage;

  bool isConnecting = false;
  bool isDriverMonitorConnecteed = false;
  bool _isScanning = false;
  bool _isDriverScanning = false;

  bool get isScanning => _isScanning;
  bool get isDriverScanning => _isDriverScanning;

  final String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  final String charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  final String driverServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  final String driverCharacteristicUuid =
      'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  StreamSubscription<List<ScanResult>>? _espScanSubscription;
  StreamSubscription<List<ScanResult>>? _driverScanSubscription;
  StreamSubscription<List<int>>? _imageSubscription;
  StreamSubscription<List<int>>? _driverSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<BluetoothConnectionState>? _driverStateSubscription;

  Future<void> _stopEspScanListener() async {
    await _espScanSubscription?.cancel();
    _espScanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  Future<void> _stopDriverScanListener() async {
    await _driverScanSubscription?.cancel();
    _driverScanSubscription = null;
    _isDriverScanning = false;
    notifyListeners();
  }

  Future<void> startScan() async {
    final granted = await requestBluetoothPermissions();

    if (!granted) {
      if (kDebugMode) {
        print('Bluetooth permission not granted');
      }
      return;
    }

    await _stopEspScanListener();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    _isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      _espScanSubscription = FlutterBluePlus.scanResults.listen(
            (results) async {
          for (final r in results) {
            if (r.device.platformName == 'ESP32-CAM-IMAGE') {
              try {
                await FlutterBluePlus.stopScan();
              } catch (_) {}

              await _stopEspScanListener();
              await connect(r.device);
              break;
            }
          }
        },
        onError: (error) async {
          _isScanning = false;
          notifyListeners();
          if (kDebugMode) {
            print('ESP scan error: $error');
          }
        },
      );
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      if (kDebugMode) {
        print('ESP start scan error: $e');
      }
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      isConnecting = true;
      notifyListeners();

      await _imageSubscription?.cancel();
      _imageSubscription = null;

      await _deviceStateSubscription?.cancel();
      _deviceStateSubscription = null;

      try {
        await targetDevice?.disconnect();
      } catch (_) {}

      await device.connect();

      try {
        await device.requestMtu(255);
      } catch (e) {
        if (kDebugMode) {
          print('MTU request error: $e');
        }
      }

      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString() == charUuid) {
              imgCharacteristic = char;
              await _listenForChunks();
            }
          }
        }
      }

      targetDevice = device;

      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          targetDevice = null;
          imgCharacteristic = null;
          completedImage = null;
          notifyListeners();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('ESP connect error: $e');
      }
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _listenForChunks() async {
    if (imgCharacteristic == null) return;

    await imgCharacteristic!.setNotifyValue(true);

    await _imageSubscription?.cancel();
    _imageSubscription = imgCharacteristic!.lastValueStream.listen(
          (value) async {
        if (value.isEmpty) return;

        if (value.length == 2 && value[0] == 0xFF && value[1] == 0xD9) {
          completedImage = Uint8List.fromList(_accumulatedBytes);
          _accumulatedBytes.clear();
          notifyListeners();

          final context = Globals.navigatorKey.currentContext;
          if (context != null && completedImage != null) {
            final roadProvider =
            Provider.of<RoadProtectionProvider>(context, listen: false);
            final speedProvider =
            Provider.of<SpeedProvider>(context, listen: false);
            final weatherProvider =
            Provider.of<WeatherServiceProvider>(context, listen: false);

            await roadProvider.getRoadSignPrediction(
              imageBytes: completedImage!,
            );

            roadProvider.updateProtectionStatus(
              speed: speedProvider.getSpeed,
              rainProbability:
              double.tryParse(weatherProvider.getRainProbability) ?? 0.0,
              temperature:
              double.tryParse(weatherProvider.getTemperature) ?? 0.0,
            );
          }
        } else {
          _accumulatedBytes.addAll(value);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Image notify error: $error');
        }
      },
    );
  }

  Future<void> startdrivermonitorScan() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (!(statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true)) {
      if (kDebugMode) {
        print('Bluetooth permissions are not granted.');
      }
      return;
    }

    await _stopDriverScanListener();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    _isDriverScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      _driverScanSubscription = FlutterBluePlus.scanResults.listen(
            (results) async {
          for (final r in results) {
            if (r.device.platformName == 'HumanMonitor-BLE') {
              try {
                await FlutterBluePlus.stopScan();
              } catch (_) {}

              await _stopDriverScanListener();
              await connectToDevice(r.device);
              break;
            }
          }
        },
        onError: (error) {
          _isDriverScanning = false;
          notifyListeners();
          if (kDebugMode) {
            print('Driver monitor scan error: $error');
          }
        },
      );
    } catch (e) {
      _isDriverScanning = false;
      notifyListeners();
      if (kDebugMode) {
        print('Driver monitor start scan error: $e');
      }
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await _driverSubscription?.cancel();
      _driverSubscription = null;

      await _driverStateSubscription?.cancel();
      _driverStateSubscription = null;

      try {
        await targetDevice2?.disconnect();
      } catch (_) {}

      await device.connect();

      final services = await device.discoverServices();
      isDriverMonitorConnecteed = true;
      targetDevice2 = device;
      notifyListeners();

      for (final service in services) {
        if (service.uuid.toString() == driverServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString() == driverCharacteristicUuid) {
              targetCharacteristic = char;
              await char.setNotifyValue(true);

              await _driverSubscription?.cancel();
              _driverSubscription = char.onValueReceived.listen(
                    (value) {
                  final raw = utf8.decode(value);
                  final parts = raw.split(',');

                  final context = Globals.navigatorKey.currentContext;
                  if (context != null) {
                    Provider.of<DriverLiveMonitor>(context, listen: false)
                        .setData(parts);
                  }
                },
                onError: (error) {
                  if (kDebugMode) {
                    print('Driver monitor notify error: $error');
                  }
                },
              );
            }
          }
        }
      }

      _driverStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          isDriverMonitorConnecteed = false;
          targetDevice2 = null;
          targetCharacteristic = null;
          notifyListeners();
        }
      });
    } catch (e) {
      isDriverMonitorConnecteed = false;
      notifyListeners();
      if (kDebugMode) {
        print('Driver monitor connect error: $e');
      }
    }
  }

  Future<bool> requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses[Permission.bluetoothScan]?.isGranted == true &&
          statuses[Permission.bluetoothConnect]?.isGranted == true;
    }

    if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }

    return false;
  }

  @override
  void dispose() {
    _espScanSubscription?.cancel();
    _driverScanSubscription?.cancel();
    _imageSubscription?.cancel();
    _driverSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _driverStateSubscription?.cancel();

    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}

    try {
      targetDevice?.disconnect();
    } catch (_) {}

    try {
      targetDevice2?.disconnect();
    } catch (_) {}

    super.dispose();
  }
}