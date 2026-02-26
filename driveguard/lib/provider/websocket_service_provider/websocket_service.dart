// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:driveguard/constants.dart';
import 'package:driveguard/models/fatigue_data.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// FIX: Split into 3 separate notifiers so only affected widgets rebuild,
// instead of one ChangeNotifier that rebuilds the entire tree on every message.

/// Notifies only widgets that care about connection status.
class ConnectionStateNotifier extends ValueNotifier<bool> {
  ConnectionStateNotifier() : super(false);
}

/// Notifies only widgets that display the latest fatigue reading.
class FatigueDataNotifier extends ValueNotifier<FatigueData?> {
  FatigueDataNotifier() : super(null);
}

/// Notifies only the line chart when history updates.
class HistoryNotifier extends ValueNotifier<List<HistoryPoint>> {
  HistoryNotifier() : super(const []);

  void addPoint(FatigueData data) {
    // FIX: mutate a fixed-length list instead of spreading a new list every tick
    final list = List<HistoryPoint>.from(value);
    list.add(
      HistoryPoint(
        // FIX: use the server timestamp instead of DateTime.now()
        time: DateTime.parse(
          data.timestamp,
        ).toLocal().toString().substring(11, 19),
        score: data.fatigueScore,
        env: data.components.environmental.score,
        phys: data.components.physiological.score,
        behav: data.components.behavioral.score,
      ),
    );
    if (list.length > 20) list.removeAt(0); // FIX: removeAt avoids sublist copy
    value = list;
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  Timer? _reconnectTimer;

  // Public notifiers — widgets subscribe only to what they need
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
            // FIX: update notifiers independently — only subscribed widgets rebuild
            dataNotifier.value = data;
            historyNotifier.addPoint(data);
          } catch (e) {
            // FIX: only log in debug mode, no debugPrint in production
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
    connectionNotifier.dispose();
    dataNotifier.dispose();
    historyNotifier.dispose();
  }
}
