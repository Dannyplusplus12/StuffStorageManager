import 'dart:io';
import 'dart:convert';

class AppConfig {
  static String apiUrl = 'https://web-production-e5558.up.railway.app';

  static Future<void> _tryLoadFromFile(File file) async {
    if (!await file.exists()) return;
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final url = (json['api_url'] as String?)?.trim();
    if (url != null && url.isNotEmpty) {
      apiUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
  }

  static Future<void> load() async {
    // Priority 1: config cạnh file exe
    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      await _tryLoadFromFile(File('${exeDir.path}${Platform.pathSeparator}config.json'));

      // Priority 2: tìm config.json ở các thư mục cha của exe (hữu ích khi chạy trực tiếp từ build/windows/...)
      Directory cursor = exeDir;
      for (int i = 0; i < 7; i++) {
        await _tryLoadFromFile(File('${cursor.path}${Platform.pathSeparator}config.json'));
        final parent = cursor.parent;
        if (parent.path == cursor.path) break;
        cursor = parent;
      }
    } catch (_) {}

    // Priority 3: config theo current working directory
    try {
      await _tryLoadFromFile(File('config.json'));
    } catch (_) {}

    // Priority 4: config cố định trong project frontend khi chạy local từ workspace root
    try {
      await _tryLoadFromFile(File('frontend/config.json'));
    } catch (_) {}

    // Normalize url
    final normalized = apiUrl.trim();
    if (normalized.isNotEmpty) {
      apiUrl = normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
    }
  }
}
