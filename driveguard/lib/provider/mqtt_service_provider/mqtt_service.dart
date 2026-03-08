import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../models/drive_profile.dart';

class MqttService {
  final String broker = 'ws://192.168.8.100'; // WebSockets use ws://
  final int port = 9001;
  final String topic = 'vehicle/+/profile';

  late MqttBrowserClient client;
  final StreamController<DriverProfile> _profileController =
  StreamController<DriverProfile>.broadcast();

  Stream<DriverProfile> get profileStream => _profileController.stream;

  Future<void> connect() async {
    client = MqttBrowserClient(
      broker,
      'flutter_companion_${DateTime.now().millisecondsSinceEpoch}',
    );
    client.port = port;
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.logging(on: false);
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(
      'flutter_companion_${DateTime.now().millisecondsSinceEpoch}',
    )
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      print('MQTT: Connecting to $broker...');
      await client.connect();
    } catch (e) {
      print('MQTT: Exception: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT: Connected to broker.');
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        try {
          final jsonMap = jsonDecode(payload);
          final profile = DriverProfile.fromJson(jsonMap);
          _profileController.add(profile);
        } catch (e) {
          print('Error parsing JSON from MQTT: $e');
        }
      });
    } else {
      print(
        'MQTT: Connection failed. State is: ${client.connectionStatus!.state}',
      );
      client.disconnect();
    }
  }

  void onDisconnected() {
    print('MQTT: Disconnected from broker.');
  }
}