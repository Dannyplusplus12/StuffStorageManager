import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { VIEWER, MANAGER }

class AppModeManager {
  static AppMode _mode = AppMode.VIEWER;
  static const String _staffModeKey = 'is_staff_mode';
  static const String _modeTimestampKey = 'staff_mode_timestamp';
  
  // Valid PIN for staff mode
  static const String _validPin = '1111';
  
  static AppMode get mode => _mode;
  
  static bool get isViewer => _mode == AppMode.VIEWER;
  static bool get isManager => _mode == AppMode.MANAGER;
  
  /// Initialize mode from SharedPreferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    bool saved = prefs.getBool(_staffModeKey) ?? false;
    
    if (saved) {
      _mode = AppMode.MANAGER;
    } else {
      _mode = AppMode.VIEWER;
    }
  }
  
  /// Verify PIN and enable manager mode
  static Future<bool> verifyPin(String pin) async {
    if (pin == _validPin) {
      _mode = AppMode.MANAGER;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_staffModeKey, true);
      await prefs.setInt(_modeTimestampKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    }
    return false;
  }
  
  /// Logout from manager mode
  static Future<void> logout() async {
    _mode = AppMode.VIEWER;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_staffModeKey, false);
  }
}
