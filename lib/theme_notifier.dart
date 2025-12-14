import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  //  Private variable that stores the current state of the theme.
  // false = Light Mode | true = Dark Mode
  bool _isDarkMode = false;

  //  Public getter so other widgets can check which theme is currently active.
  bool get isDarkMode => _isDarkMode;

  //  Depending on the value of _isDarkMode, we return either
  // ThemeData.dark() or ThemeData.light() for the whole app.
  ThemeData get currentTheme =>
      _isDarkMode ? ThemeData.dark() : ThemeData.light();

  //  Constructor runs automatically when the app starts.
  // It loads the last saved theme (dark or light) from SharedPreferences.
  ThemeNotifier() {
    _loadTheme(); //  As soon as the app opens, retrieve the saved value.
  }

  //  This function is called whenever the user toggles the dark mode switch.
  // It flips the value (true <-> false), notifies all listeners,
  // and saves the user’s new preference locally.
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode; // flip the mode
    notifyListeners(); //  rebuilds all widgets that use this notifier

    //  Save the user's choice so that it remains even after restarting the app
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("isDarkMode", _isDarkMode); // ✅ Store the current mode
  }

  //  This function runs once when the ThemeNotifier is created.
  // It reads the stored value ("isDarkMode") from SharedPreferences
  // and updates the theme accordingly.
  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // If there’s no saved value yet, it defaults to false (Light Mode)
    _isDarkMode = prefs.getBool("isDarkMode") ?? false;

    // After loading, notify all screens to refresh with the correct theme
    notifyListeners();
  }
}
