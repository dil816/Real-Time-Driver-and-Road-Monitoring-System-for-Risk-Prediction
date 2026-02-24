import 'package:driveguard/provider/driver_live_monitor/driver_live_monitor.dart';
import 'package:driveguard/provider/esp_device_provider/esp_device_provider.dart';
import 'package:driveguard/provider/road_protection_provider/road_protection_provider.dart';
import 'package:driveguard/provider/speed_provider/speed_provider.dart';
import 'package:driveguard/provider/weather_service_provider/weather_service_provider.dart';
import 'package:driveguard/screens/main_navigation_screen/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => WeatherServiceProvider()),
        ChangeNotifierProvider(create: (context) => SpeedProvider()),
        ChangeNotifierProvider(create: (context) => RoadProtectionProvider()),
        ChangeNotifierProvider(create: (context) => EspDeviceProvider()),
        ChangeNotifierProvider(create: (context) => DriverLiveMonitor()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF14171C);

    return MaterialApp(
      navigatorKey: Globals.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Fleet Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF57D163),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 64, fontWeight: FontWeight.w700),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class Globals {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
