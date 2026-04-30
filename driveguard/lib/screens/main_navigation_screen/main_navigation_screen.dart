import 'package:driveguard/screens/bottom_navbar_pages/driver_monitor/driver_monitor_screen.dart';
import 'package:driveguard/screens/bottom_navbar_pages/fatigue_detection/fatigue_analyze_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/profile_provider/profile_provider.dart';
import '../bottom_navbar_pages/dashboard/dahsboard_page.dart';
import '../bottom_navbar_pages/driver_behaviour_monitor/dashboard_screen.dart';
import '../bottom_navbar_pages/driver_behaviour_monitor/settings_screen.dart';


class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  // String _host = '192.168.1.100:8765';       // ← ADD
  // ProfileProvider? _provider;

  // @override
  // void initState() {                           // ← ADD
  //   super.initState();
  //   _provider = ProfileProvider(_host);
  // }

  // void _onHostChanged(String newHost) {        // ← ADD
  //   _provider?.dispose();
  //   setState(() {
  //     _host = newHost;
  //     _provider = ProfileProvider(newHost);
  //   });
  // }

  void _onHostChanged(String newHost) {
    // Update the GLOBAL provider instead of a local one
    context.read<ProfileProvider>().updateHost(newHost);  // ← reads from MultiProvider
  }


  // final pages = <Widget>[
  //   DahsboardPage(),
  //   DriverMonitorScreen(),
  //   FatigueAnalyzeScreen(),
  // ];

  @override
  Widget build(BuildContext context) {
    final host = context.watch<ProfileProvider>().host;
    final pages = [
      DahsboardPage(),
      DriverMonitorScreen(),
      FatigueAnalyzeScreen(),
      DashboardScreen(),
      SettingsScreen(                            // ← ADD 4th tab
        currentHost: host,
        onHostChanged: _onHostChanged,
      ),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) => setState(() => _index = v),
        backgroundColor: const Color(0xFF0F1216),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_rounded),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: '',
          ),
        ],
      ),
    );
  }
}
