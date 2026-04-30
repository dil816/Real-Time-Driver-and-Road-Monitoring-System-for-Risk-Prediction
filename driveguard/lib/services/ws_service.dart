import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/drive_profile.dart';

/// Manages a persistent WebSocket connection to the Python aiohttp server.
/// Emits [DriverProfile] objects whenever the server pushes a new update.
/// Auto-reconnects on disconnect with exponential back-off.
class WsService {
  final String host; // e.g. "192.168.1.100:8765"

  WsService(this.host);

  WebSocketChannel? _channel;
  StreamController<DriverProfile>? _controller;
  bool _disposed = false;
  int _retryDelay = 2; // seconds

  Stream<DriverProfile> get stream {
    _controller ??= StreamController<DriverProfile>.broadcast(
      onListen: _connect,
      onCancel: _dispose,
    );
    return _controller!.stream;
  }

  void _connect() async {
    _disposed = false;
    while (!_disposed) {
      try {
        final uri = Uri.parse('ws://$host/ws');
        _channel = WebSocketChannel.connect(uri);
        await _channel!.ready;
        _retryDelay = 2; // reset back-off on success

        await for (final raw in _channel!.stream) {
          if (_disposed) break;
          _handleMessage(raw as String);
        }
      } catch (_) {
        // ignore connection errors — retry below
      }

      if (!_disposed) {
        await Future.delayed(Duration(seconds: _retryDelay));
        _retryDelay = (_retryDelay * 2).clamp(2, 30);
      }
    }
  }

  void _handleMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;

      // On connect the server sends a snapshot of ALL profiles
      if (data['type'] == 'snapshot') {
        final profiles = data['profiles'] as List;
        for (final p in profiles) {
          _controller?.add(DriverProfile.fromJson(p as Map<String, dynamic>));
        }
        return;
      }

      // Regular per-device update
      _controller?.add(DriverProfile.fromJson(data));
    } catch (_) {}
  }

  void _dispose() {
    _disposed = true;
    _channel?.sink.close();
    _channel = null;
  }

  void disconnect() => _dispose();
}
