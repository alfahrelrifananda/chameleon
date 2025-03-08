import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _isDynamicKey = 'is_dynamic';
  static const _colorKey = 'primary_color';

  late SharedPreferences _prefs;
  bool _initialized = false;
  ThemeMode _themeMode = ThemeMode.system;
  late bool _isDynamic;
  Color _primaryColor = Colors.cyanAccent;

  ThemeProvider() {
    _isDynamic = !kIsWeb; // Set default berdasarkan platform
    initialize();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDynamic => _isDynamic;
  Color get primaryColor => _primaryColor;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      await _loadPreferences();
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    final savedThemeMode = _prefs.getString(_themeKey);
    if (savedThemeMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedThemeMode,
        orElse: () => ThemeMode.system,
      );
    }

    // Load isDynamic dengan default value sesuai platform
    _isDynamic = _prefs.getBool(_isDynamicKey) ?? !kIsWeb;

    final savedColor = _prefs.getInt(_colorKey);
    if (savedColor != null) {
      _primaryColor = Color(savedColor);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _prefs.setString(_themeKey, mode.toString());
      notifyListeners();
    }
  }

  Future<void> setIsDynamic(bool value) async {
    if (_isDynamic != value) {
      _isDynamic = value;
      await _prefs.setBool(_isDynamicKey, value);
      notifyListeners();
    }
  }

  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor != color) {
      _primaryColor = color;
      await _prefs.setInt(_colorKey, color.value);
      notifyListeners();
    }
  }
}

class ViewStyleProvider with ChangeNotifier {
  bool _isGridStyle = true;
  late SharedPreferences _prefs;
  static const String _gridStyleKey = 'isGridStyle';
  bool _isFloatingNavbar = true;

  ViewStyleProvider() {
    _loadPreference();
  }

  bool get isGridStyle => _isGridStyle;
  bool get isFloatingNavbar => _isFloatingNavbar;

  Future<void> _loadPreference() async {
    _prefs = await SharedPreferences.getInstance();
    _isGridStyle = _prefs.getBool(_gridStyleKey) ?? true;
    _isFloatingNavbar = _prefs.getBool('isFloatingNavbar') ?? true;
    notifyListeners();
  }

  Future<void> setGridStyle(bool value) async {
    if (_isGridStyle != value) {
      _isGridStyle = value;
      await _prefs.setBool(_gridStyleKey, value);
      notifyListeners();
    }
  }

  // Add method to toggle grid style
  Future<void> toggleGridStyle() async {
    await setGridStyle(!_isGridStyle);
  }

  // Add method to initialize with specific value
  Future<void> initializeGridStyle(bool value) async {
    if (_isGridStyle != value) {
      _isGridStyle = value;
      await _prefs.setBool(_gridStyleKey, value);
      notifyListeners();
    }
  }

  void setFloatingNavbar(bool value) async {
    _isFloatingNavbar = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFloatingNavbar', value);
    notifyListeners();
  }
}
