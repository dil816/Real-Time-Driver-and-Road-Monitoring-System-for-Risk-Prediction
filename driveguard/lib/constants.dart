import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  static const int port = 8000;

  //static const String lanIp = "192.168.43.211";
  //static const String lanIp = "192.168.43.230";
  //static const String lanIp = "10.66.211.92";
  static const String lanIp = "192.168.8.141";

  static String get wsBaseUrl {
    if (kIsWeb) {
      return "ws://127.0.0.1:$port/predictions";
    }
    if (Platform.isAndroid) {
      return "ws://$lanIp:$port/predictions";
    }
    if (Platform.isIOS) {
      return "ws://127.0.0.1:$port/predictions";
    }
    return "ws://$lanIp:$port/predictions";
  }
}
