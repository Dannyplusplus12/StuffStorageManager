import 'package:flutter/foundation.dart';
import 'dart:io';

enum DeviceType { mobile, desktop, web }

class DeviceDetector {
  static DeviceType detectDevice() {
    if (kIsWeb) {
      return DeviceType.web;
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      return DeviceType.mobile;
    }
    
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DeviceType.desktop;
    }
    
    return DeviceType.mobile; // Default fallback
  }

  static bool get isMobile => detectDevice() == DeviceType.mobile;
  static bool get isDesktop => detectDevice() == DeviceType.desktop;
  static bool get isWeb => detectDevice() == DeviceType.web;
}
