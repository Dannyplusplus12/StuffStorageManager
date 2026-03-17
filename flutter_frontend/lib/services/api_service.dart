import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/order.dart';

class ApiService {
  static String get _b => AppConfig.apiUrl;
  static const _timeout = Duration(seconds: 15);
  static final _headers = {'Content-Type': 'application/json'};

  // ── Products ──
  static Future<List<Product>> getProducts({String search = ''}) async {
    final uri = search.isEmpty ? Uri.parse('$_b/products') : Uri.parse('$_b/products?search=${Uri.encodeComponent(search)}');
    final r = await http.get(uri).timeout(_timeout);
    if (r.statusCode == 200) return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => Product.fromJson(e)).toList();
    throw Exception('Lỗi tải sản phẩm: ${r.statusCode}');
  }

  static Future<void> createProduct({required String name, String description = '', required String imagePath, required List<Map<String, dynamic>> variants}) async {
    final r = await http.post(Uri.parse('$_b/products'), headers: _headers, body: jsonEncode({'name': name, 'description': description, 'image_path': imagePath, 'variants': variants}));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi');
  }

  static Future<void> updateProduct(int id, {required String name, required String imagePath, required List<Map<String, dynamic>> variants}) async {
    final r = await http.put(Uri.parse('$_b/products/$id'), headers: _headers, body: jsonEncode({'name': name, 'image_path': imagePath, 'variants': variants}));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi');
  }

  static Future<void> deleteProduct(int id) async {
    await http.delete(Uri.parse('$_b/products/$id'));
  }

  // ── Customers ──
  static Future<List<Customer>> getCustomers() async {
    final r = await http.get(Uri.parse('$_b/customers')).timeout(_timeout);
    if (r.statusCode == 200) return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => Customer.fromJson(e)).toList();
    throw Exception('Lỗi tải khách hàng');
  }

  static Future<Map<String, dynamic>> createCustomer({required String name, String phone = '', int debt = 0}) async {
    final r = await http.post(Uri.parse('$_b/customers'), headers: _headers, body: jsonEncode({'name': name, 'phone': phone, 'debt': debt}));
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw Exception(body['detail'] ?? 'Lỗi');
    return body;
  }

  static Future<void> updateCustomer(int id, {required String name, required String phone, required int debt}) async {
    final r = await http.put(Uri.parse('$_b/customers/$id'), headers: _headers, body: jsonEncode({'name': name, 'phone': phone, 'debt': debt}));
    if (r.statusCode != 200) throw Exception('Lỗi cập nhật');
  }

  static Future<void> deleteCustomer(int id) async {
    await http.delete(Uri.parse('$_b/customers/$id'));
  }

  // ── Customer History ──
  static Future<List<HistoryItem>> getCustomerHistory(int cid) async {
    final r = await http.get(Uri.parse('$_b/customers/$cid/history')).timeout(_timeout);
    if (r.statusCode == 200) return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => HistoryItem.fromJson(e)).toList();
    throw Exception('Lỗi tải lịch sử');
  }

  static Future<void> createDebtLog(int cid, {required int changeAmount, required String note, String? createdAt}) async {
    final payload = <String, dynamic>{'change_amount': changeAmount, 'note': note};
    if (createdAt != null) payload['created_at'] = createdAt;
    final r = await http.post(Uri.parse('$_b/customers/$cid/history'), headers: _headers, body: jsonEncode(payload));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi');
  }

  static Future<void> updateDebtLog(int cid, int logId, {required int changeAmount, required String note, String? createdAt}) async {
    final payload = <String, dynamic>{'change_amount': changeAmount, 'note': note};
    if (createdAt != null) payload['created_at'] = createdAt;
    final r = await http.put(Uri.parse('$_b/customers/$cid/history/$logId'), headers: _headers, body: jsonEncode(payload));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi');
  }

  static Future<void> deleteDebtLog(int cid, int logId) async {
    await http.delete(Uri.parse('$_b/customers/$cid/history/$logId'));
  }

  // ── Orders ──
  static Future<Map<String, dynamic>> getOrders({int page = 1, int limit = 20}) async {
    final r = await http.get(Uri.parse('$_b/orders?page=$page&limit=$limit')).timeout(_timeout);
    if (r.statusCode == 200) {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return {
        'data': (j['data'] as List).map((e) => Order.fromJson(e)).toList(),
        'total': j['total'],
        'page': j['page'],
        'limit': j['limit'],
      };
    }
    throw Exception('Lỗi tải hóa đơn');
  }

  static Future<void> checkout({required String customerName, String customerPhone = '', required List<CartItem> cart}) async {
    final r = await http.post(Uri.parse('$_b/checkout'), headers: _headers, body: jsonEncode({'customer_name': customerName, 'customer_phone': customerPhone, 'cart': cart.map((e) => e.toJson()).toList()}));
    if (r.statusCode != 200) {
      final detail = jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi checkout';
      throw Exception(detail);
    }
  }

  static Future<void> updateOrder(int id, {required String customerName, String customerPhone = '', required List<CartItem> cart}) async {
    final r = await http.put(Uri.parse('$_b/orders/$id'), headers: _headers, body: jsonEncode({'customer_name': customerName, 'customer_phone': customerPhone, 'cart': cart.map((e) => e.toJson()).toList()}));
    if (r.statusCode != 200) {
      final detail = jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi cập nhật đơn';
      throw Exception(detail);
    }
  }

  static Future<void> deleteOrder(int id) async {
    final r = await http.delete(Uri.parse('$_b/orders/$id'));
    if (r.statusCode != 200) throw Exception('Lỗi xóa đơn');
  }

  static Future<void> updateOrderDate(int id, String createdAt) async {
    final r = await http.put(Uri.parse('$_b/orders/$id/date'), headers: _headers, body: jsonEncode({'created_at': createdAt}));
    if (r.statusCode != 200) throw Exception('Lỗi cập nhật ngày');
  }

  // ── Dashboard Stats ──
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final results = await Future.wait([
      getProducts(),
      getCustomers(),
      getOrders(page: 1, limit: 5),
    ]);
    final products = results[0] as List<Product>;
    final customers = results[1] as List<Customer>;
    final ordersMap = results[2] as Map<String, dynamic>;
    final totalDebt = customers.fold<int>(0, (s, c) => s + c.debt);
    return {
      'totalProducts': products.length,
      'totalCustomers': customers.length,
      'totalDebt': totalDebt,
      'totalOrders': ordersMap['total'] as int,
      'recentOrders': ordersMap['data'] as List<Order>,
    };
  }

  // ── Draft Orders (Staff App) ──
  /// Create a DRAFT order (pending approval)
  static Future<Map<String, dynamic>> checkoutDraft({
    required String customerName,
    String customerPhone = '',
    required List<CartItem> cart,
  }) async {
    final r = await http.post(
      Uri.parse('$_b/checkout/draft'),
      headers: _headers,
      body: jsonEncode({
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'cart': cart.map((e) => e.toJson()).toList(),
      }),
    );
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    if (r.statusCode == 404) {
      throw Exception('Server chưa hỗ trợ duyệt nháp (thiếu endpoint /checkout/draft). Cần cập nhật backend mới.');
    }
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi tạo hóa đơn nháp');
  }

  /// Get all pending orders
  static Future<List<Order>> getPendingOrders() async {
    final r = await http.get(Uri.parse('$_b/orders/pending')).timeout(_timeout);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return (data['data'] as List).map((e) => Order.fromJson(e)).toList();
    }
    if (r.statusCode == 404) {
      throw Exception('Server chưa hỗ trợ danh sách đơn chờ duyệt (/orders/pending). Cần cập nhật backend mới.');
    }
    throw Exception('Lỗi tải hóa đơn chờ duyệt');
  }

  /// Approve a draft order
  static Future<Map<String, dynamic>> approveOrder(int orderId) async {
    final r = await http.put(
      Uri.parse('$_b/orders/$orderId/approve'),
      headers: _headers,
    );
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi duyệt hóa đơn');
  }

  /// Reject (delete) a pending order
  static Future<Map<String, dynamic>> rejectOrder(int orderId) async {
    final r = await http.delete(Uri.parse('$_b/orders/$orderId/reject'));
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi từ chối hóa đơn');
  }

  /// Get all accepted orders (for picker)
  static Future<List<Order>> getAcceptedOrders() async {
    final r = await http.get(Uri.parse('$_b/orders/accepted')).timeout(_timeout);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return (data['data'] as List).map((e) => Order.fromJson(e)).toList();
    }
    final body = r.bodyBytes.isNotEmpty ? jsonDecode(utf8.decode(r.bodyBytes)) : null;
    throw Exception(body is Map<String, dynamic> ? (body['detail'] ?? 'Lỗi tải đơn hàng đã tiếp nhận') : 'Lỗi tải đơn hàng đã tiếp nhận');
  }

  /// Picker confirms delivery — deducts stock + records debt
  static Future<Map<String, dynamic>> confirmOrder(int orderId) async {
    final r = await http.put(Uri.parse('$_b/orders/$orderId/confirm'), headers: _headers);
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi xác nhận đơn hàng');
  }

  /// Lightweight status check for orderer polling
  static Future<Map<String, dynamic>?> getOrderStatus(int orderId) async {
    final r = await http.get(Uri.parse('$_b/orders/$orderId/status')).timeout(_timeout);
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode == 404) return null; // rejected/deleted
    throw Exception('Status check failed: ${r.statusCode}');
  }
}
