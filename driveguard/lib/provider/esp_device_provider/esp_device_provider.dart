

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:driveguard/provider/driver_live_monitor/driver_live_monitor.dart';
import 'package:driveguard/provider/road_protection_provider/road_protection_provider.dart';

import '../../main.dart';

class EspDeviceProvider extends ChangeNotifier{
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? imgCharacteristic;
  BluetoothDevice? targetDevice2;
  BluetoothCharacteristic? targetCharacteristic;

  List<int> _accumulatedBytes = [];
  Uint8List? completedImage;

  bool isConnecting = false;
  bool isDriverMonitorConnecteed = false;

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  void startScan() async {
    bool granted = await requestBluetoothPermissions();

    if (!granted) {
      print("Bluetooth permission not granted");
      return;
    }

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      print(e);
    }

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == "ESP32-CAM-IMAGE") {
          FlutterBluePlus.stopScan();
          connect(r.device);
          break;
        }
      }
    });
  }

  void connect(BluetoothDevice device) async {
    isConnecting = true;
    notifyListeners();
    await device.connect();

    try {
      await device.requestMtu(255);
    }
    catch (e) {
      print(e);
    }

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (var char in service.characteristics) {
          if (char.uuid.toString() == charUuid) {
            imgCharacteristic = char;
            _listenForChunks();
          }
        }
      }
    }
    isConnecting = false;
    targetDevice = device;
    notifyListeners();
  }

  void _listenForChunks() async {
    await imgCharacteristic!.setNotifyValue(true);
    imgCharacteristic!.lastValueStream.listen((value) {
      if (value.isEmpty) return;
      if (value.length == 2 && value[0] == 0xFF && value[1] == 0xD9) {
        completedImage = Uint8List.fromList(_accumulatedBytes);
        _accumulatedBytes.clear();
        notifyListeners();
        final context = Globals.navigatorKey.currentContext;
        if (context != null) {
          Provider.of<RoadProtectionProvider>(context, listen: false)
              .getRoadSignPrediction(imageBytes: completedImage!);
        }
        _accumulatedBytes.clear();
      } else {
        _accumulatedBytes.addAll(value);
      }
    });
  }

  void startdrivermonitorScan() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == "HumanMonitor-BLE") {
            FlutterBluePlus.stopScan();
            connectToDevice(r.device);
          }
        }
      });
    }else{
      print("Bluetooth permissions are not granted.");
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect().then((onValue) async {
      List<BluetoothService> services = await device.discoverServices();
      isDriverMonitorConnecteed = true;
      notifyListeners();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == CHARACTERISTIC_UUID) {
              targetCharacteristic = char;
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                String raw = utf8.decode(value);
                List<String> parts = raw.split(',');
                final context = Globals.navigatorKey.currentContext;
                if (context != null) {
                  Provider.of<DriverLiveMonitor>(context, listen: false).setData(parts);
                }
              });
            }
          }
        }
      }
    }).catchError((onError){
      isDriverMonitorConnecteed = false;
      notifyListeners();
    });
  }

  Future<bool> requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      var statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses[Permission.bluetoothScan]?.isGranted == true &&
          statuses[Permission.bluetoothConnect]?.isGranted == true;
    }

    if (Platform.isIOS) {
      var status = await Permission.bluetooth.request();
      return status.isGranted;
    }

    return false;
  }



}