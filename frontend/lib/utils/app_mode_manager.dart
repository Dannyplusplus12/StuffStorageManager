import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { none, orderer, picker }

class AppModeManager {
  static AppMode _mode = AppMode.none;
  static const String _modeKey = 'app_mode';
  static const String _employeeIdKey = 'employee_id';
  static const String _employeeNameKey = 'employee_name';
  static const String _employeeRoleKey = 'employee_role';
  static int? _employeeId;
  static String _employeeName = '';
  static String _employeeRole = '';

  static AppMode get mode => _mode;

  static bool get isNone => _mode == AppMode.none;
  static bool get isOrderer => _mode == AppMode.orderer;
  static bool get isPicker => _mode == AppMode.picker;
  static bool get isManager => _employeeRole == 'manager';
  static int? get employeeId => _employeeId;
  static String get employeeName => _employeeName;
  static String get employeeRole => _employeeRole;

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
    _employeeId = prefs.getInt(_employeeIdKey);
    _employeeName = prefs.getString(_employeeNameKey) ?? '';
    _employeeRole = prefs.getString(_employeeRoleKey) ?? '';
  }

  static Future<void> setSession(
    AppMode requestedMode, {
    required int employeeId,
    required String employeeName,
    required String employeeRole,
  }) async {
    _mode = requestedMode;
    _employeeId = employeeId;
    _employeeName = employeeName;
    _employeeRole = employeeRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, requestedMode == AppMode.orderer ? 'orderer' : 'picker');
    await prefs.setInt(_employeeIdKey, employeeId);
    await prefs.setString(_employeeNameKey, employeeName);
    await prefs.setString(_employeeRoleKey, employeeRole);
  }

  static Future<void> logout() async {
    _mode = AppMode.none;
    _employeeId = null;
    _employeeName = '';
    _employeeRole = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, 'none');
    await prefs.remove(_employeeIdKey);
    await prefs.remove(_employeeNameKey);
    await prefs.remove(_employeeRoleKey);
  }
}
