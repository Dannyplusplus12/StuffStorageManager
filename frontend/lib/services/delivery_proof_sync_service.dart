import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/device_detector.dart';
import 'api_service.dart';

class DeliveryProofSyncService {
  static Timer? _timer;
  static bool _running = false;

  static void startAutoSync({int intervalSeconds = 10}) {
    stop();
    unawaited(syncOnce());
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      unawaited(syncOnce());
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> syncOnce() async {
    if (_running) return;
    if (DeviceDetector.isMobile || DeviceDetector.isWeb) return;

    _running = true;
    try {
      final outDir = _resolveOutputDir();
      await outDir.create(recursive: true);

      final stateFile = File('${outDir.path}${Platform.pathSeparator}.delivery_sync_state.json');
      final lastOrderId = await _loadState(stateFile);

      final uri = Uri.parse('${ApiService.baseUrl}/delivery-proofs/pending')
          .replace(queryParameters: {
        'since_order_id': '$lastOrderId',
        'limit': '300',
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        developer.log('Delivery proof sync failed list: ${resp.statusCode}', name: 'DeliveryProofSyncService');
        return;
      }

      final body = jsonDecode(utf8.decode(resp.bodyBytes));
      final rows = body is Map<String, dynamic> ? (body['data'] as List? ?? const []) : const [];
      if (rows.isEmpty) return;

      var maxSeen = lastOrderId;
      var downloaded = 0;
      var missing = 0;
      final syncedByOrder = <int, Set<String>>{};

      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;

        final orderId = _toInt(row['order_id']);
        final fileName = (row['file_name'] ?? '').toString().trim();
        final downloadUrl = (row['download_url'] ?? '').toString().trim();
        final downloadUrls = (row['download_urls'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [];
        final fileNames = (row['file_names'] as List?)
                ?.map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList() ??
            const [];
        if (orderId <= 0 || (downloadUrls.isEmpty && (fileName.isEmpty || downloadUrl.isEmpty))) continue;

        if (orderId > maxSeen) maxSeen = orderId;

        final urlsToFetch = downloadUrls.isNotEmpty ? downloadUrls : [downloadUrl];
        final namesToUse = fileNames.isNotEmpty ? fileNames : [fileName];
        for (var i = 0; i < urlsToFetch.length; i++) {
          final url = urlsToFetch[i];
          final name = i < namesToUse.length && namesToUse[i].trim().isNotEmpty
              ? namesToUse[i]
              : fileName;
          if (url.trim().isEmpty || name.trim().isEmpty) continue;

          final localName = 'order_${orderId}_$name';
          final target = File('${outDir.path}${Platform.pathSeparator}$localName');
          syncedByOrder.putIfAbsent(orderId, () => <String>{}).add(localName);
          if (await target.exists() && await target.length() > 0) continue;

          final resolved = ApiService.resolveApiUrl(url);
          final photoResp = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 60));

          if (photoResp.statusCode == 404) {
            missing += 1;
            continue;
          }

          if (photoResp.statusCode != 200) {
            developer.log(
              'Delivery proof download failed #$orderId (${photoResp.statusCode})',
              name: 'DeliveryProofSyncService',
            );
            continue;
          }

          await target.writeAsBytes(photoResp.bodyBytes, flush: true);
          downloaded += 1;
        }
      }

      for (final entry in syncedByOrder.entries) {
        final orderId = entry.key;
        final names = entry.value.toList();
        var hasAll = names.isNotEmpty;
        for (final name in names) {
          final f = File('${outDir.path}${Platform.pathSeparator}$name');
          if (!await f.exists() || await f.length() <= 0) {
            hasAll = false;
            break;
          }
        }
        if (!hasAll) continue;
        await _ackLocalProof(orderId: orderId, fileNames: names);
      }

      if (maxSeen > lastOrderId) {
        await _saveState(stateFile, maxSeen);
      }

      developer.log(
        'Delivery proof sync done. downloaded=$downloaded missing=$missing last_order_id=$maxSeen',
        name: 'DeliveryProofSyncService',
      );
    } catch (e) {
      developer.log('Delivery proof sync error: $e', name: 'DeliveryProofSyncService');
    } finally {
      _running = false;
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Directory _resolveOutputDir() {
    try {
      final exePath = Platform.resolvedExecutable.toLowerCase();
      if (exePath.endsWith('.exe') && !exePath.contains('flutter_tester')) {
        final exeDir = File(Platform.resolvedExecutable).parent;
        return Directory('${exeDir.path}${Platform.pathSeparator}delivery_proofs');
      }
    } catch (_) {}
    return Directory('${Directory.current.path}${Platform.pathSeparator}delivery_proofs');
  }

  static Future<int> _loadState(File file) async {
    if (!await file.exists()) return 0;
    try {
      final body = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _toInt(body['last_order_id']);
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _saveState(File file, int lastOrderId) async {
    final payload = jsonEncode({'last_order_id': lastOrderId});
    await file.writeAsString(payload, flush: true);
  }

  static Future<void> _ackLocalProof({required int orderId, required List<String> fileNames}) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/delivery-proofs/ack-local');
      final resp = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'order_id': orderId, 'local_file_names': fileNames}),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 404) {
        developer.log('Ack endpoint not available yet on server', name: 'DeliveryProofSyncService');
        return;
      }
      if (resp.statusCode != 200) {
        developer.log('Ack local proof failed #$orderId (${resp.statusCode})', name: 'DeliveryProofSyncService');
      }
    } catch (e) {
      developer.log('Ack local proof error #$orderId: $e', name: 'DeliveryProofSyncService');
    }
  }
}
