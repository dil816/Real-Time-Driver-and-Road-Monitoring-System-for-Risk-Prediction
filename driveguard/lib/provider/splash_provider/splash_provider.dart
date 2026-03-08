import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashProvider extends ChangeNotifier{
  bool? isFirstTimeUser;

  Future<bool?> checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    isFirstTimeUser = prefs.getBool('isFirstTimeUser') ?? false;
    return isFirstTimeUser;
  }

  void setFirstTimeUser(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTimeUser', value);
    isFirstTimeUser = value;
    notifyListeners();
  }

}