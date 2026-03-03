import 'dart:async';
import 'dart:convert';

import 'package:driveguard/constants.dart';
import 'package:driveguard/models/fatigue_data.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ConnectionStateNotifier extends ValueNotifier<bool> {
  ConnectionStateNotifier() : super(false);
}


class FatigueDataNotifier extends ValueNotifier<FatigueData?> {
  FatigueDataNotifier() : super(null);
}

class HistoryNotifier extends ValueNotifier<List<HistoryPoint>> {
  HistoryNotifier() : super(const []);

  void addPoint(FatigueData data) {
    final list = List<HistoryPoint>.from(value);
    list.add(
      HistoryPoint(
        time: DateTime.parse(
          data.timestamp,
        ).toLocal().toString().substring(11, 19),
        score: data.fatigueScore,
        env: data.components.environmental.score,
        phys: data.components.physiological.score,
        behav: data.components.behavioral.score,
      ),
    );
    if (list.length > 20) list.removeAt(0);
    value = list;
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  Timer? _reconnectTimer;

  final connectionNotifier = ConnectionStateNotifier();
  final dataNotifier = FatigueDataNotifier();
  final historyNotifier = HistoryNotifier();

  void connect({String? url}) {
    _reconnectAttempts = 0;
    _connectWebSocket(url ?? AppConfig.wsBaseUrl);
  }

  void _connectWebSocket(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      connectionNotifier.value = true;

      _channel!.stream.listen(
        (message) {
          if (kDebugMode) print("Message received at: ${DateTime.now()}");
          _reconnectAttempts = 0;
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            final data = FatigueData.fromJson(json);
            dataNotifier.value = data;
            historyNotifier.addPoint(data);
          } catch (e) {
            if (kDebugMode) print('Error parsing message: $e');
          }
        },
        onError: (error) {
          if (kDebugMode) print('WebSocket error: $error');
          connectionNotifier.value = false;
          _scheduleReconnect(url);
        },
        onDone: () {
          if (kDebugMode) print('WebSocket closed');
          connectionNotifier.value = false;
          _scheduleReconnect(url);
        },
      );
    } catch (e) {
      if (kDebugMode) print('Error creating WebSocket: $e');
      connectionNotifier.value = false;
    }
  }

  void _scheduleReconnect(String url) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      if (kDebugMode) {
        print('Reconnecting... ($_reconnectAttempts/$_maxReconnectAttempts)');
      }
      _reconnectTimer = Timer(_reconnectDelay, () => _connectWebSocket(url));
    } else {
      if (kDebugMode) print('Max reconnection attempts reached');
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    // TODO: should be removed in follow 3
    connectionNotifier.dispose();
    dataNotifier.dispose();
    historyNotifier.dispose();
  }
}
