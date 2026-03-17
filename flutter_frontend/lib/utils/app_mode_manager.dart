import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { none, orderer, picker }

class AppModeManager {
  static AppMode _mode = AppMode.none;
  static const String _modeKey = 'app_mode';

  static const String _ordererPin = '0000';
  static const String _pickerPin = '1111';

  static AppMode get mode => _mode;

  static bool get isNone => _mode == AppMode.none;
  static bool get isOrderer => _mode == AppMode.orderer;
  static bool get isPicker => _mode == AppMode.picker;
  static bool get isManager => _mode != AppMode.none;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_modeKey) ?? 'none';
    switch (saved) {
      case 'orderer':
        _mode = AppMode.orderer;
        break;
      case 'picker':
        _mode = AppMode.picker;
        break;
      default:
        _mode = AppMode.none;
    }
  }

  static Future<bool> verifyPin(String pin, AppMode requestedMode) async {
    final expected = requestedMode == AppMode.orderer ? _ordererPin : _pickerPin;
    if (pin == expected) {
      _mode = requestedMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, requestedMode == AppMode.orderer ? 'orderer' : 'picker');
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    _mode = AppMode.none;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, 'none');
  }
}
