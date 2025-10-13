import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme => _isDarkMode ? ThemeData.dark() : ThemeData.light();

  ThemeNotifier() {
    _loadTheme(); // ✅ أول ما يفتح التطبيق يجيب القيمة المخزنة
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("isDarkMode", _isDarkMode); // ✅ نخزن الاختيار
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool("isDarkMode") ?? false;
    notifyListeners(); // ✅ نحدّث كل الصفحات بعد ما نحمل القيمة
  }
}
