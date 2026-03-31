import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/order.dart';

class NotificationService {
  static Timer? _pollingTimer;
  static int _pendingOrderCount = 0;
  
  // Callback when new pending orders detected
  static VoidCallback? onPendingOrdersUpdated;
  
  static int get pendingOrderCount => _pendingOrderCount;
  
  /// Start polling for pending orders (default 10 seconds)
  static void startPolling({int intervalSeconds = 10}) {
    stopPolling();  // Stop any existing timer
    
    _pollingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _checkPendingOrders(),
    );
  }
  
  /// Stop polling
  static void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  /// Check pending orders from backend
  static Future<void> _checkPendingOrders() async {
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/orders/pending');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final count = (data['count'] ?? 0) as int;
        
        if (count != _pendingOrderCount) {
          _pendingOrderCount = count;
          onPendingOrdersUpdated?.call();
        }
      }
    } catch (e) {
      developer.log('Error checking pending orders: $e', name: 'NotificationService');
    }
  }
  
  /// Get pending orders list
  static Future<List<Order>> getPendingOrders() async {
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/orders/pending');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final list = (data['data'] as List? ?? [])
            .map((o) => Order.fromJson(o))
            .toList();
        
        _pendingOrderCount = list.length;
        return list;
      }
      return [];
    } catch (e) {
      developer.log('Error fetching pending orders: $e', name: 'NotificationService');
      return [];
    }
  }
}

// Typedef for callback
typedef VoidCallback = void Function();
