import 'dart:io';
import 'dart:convert';

class AppConfig {
  static String apiUrl = 'https://web-production-fbfbb.up.railway.app';

  static Future<void> load() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final configFile = File('${exeDir.path}${Platform.pathSeparator}config.json');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final url = json['api_url'] as String?;
        if (url != null && url.isNotEmpty) {
          apiUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
        }
      }
    } catch (e) {
      // fallback to default
    }
    // Also try project-level config.json (for development)
    try {
      final devConfig = File('config.json');
      if (await devConfig.exists()) {
        final content = await devConfig.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final url = json['api_url'] as String?;
        if (url != null && url.isNotEmpty) {
          apiUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
        }
      }
    } catch (_) {}
  }
}
