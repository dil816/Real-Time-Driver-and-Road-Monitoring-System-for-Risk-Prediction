// constants.dart
import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static const int port = 8000;
  static const String lanIp = "192.168.8.141";

  static String get wsBaseUrl {
    if (kIsWeb) {
      return "ws://127.0.0.1:$port/ws";
    }
    if (Platform.isAndroid) {
      return "ws://$lanIp:$port/ws";
    }
    if (Platform.isIOS) {
      return "ws://127.0.0.1:$port/ws";
    }
    return "ws://$lanIp:$port/ws";
  }
}
