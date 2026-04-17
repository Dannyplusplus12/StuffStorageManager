import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../models/order.dart';

class ApiService {
  static String get _b => AppConfig.apiUrl;
  static String get baseUrl => _b;
  static const _timeout = Duration(seconds: 15);
  static final _headers = {'Content-Type': 'application/json'};

  static Future<http.Response> _getWithRetry(
    Uri uri, {
    Duration timeout = _timeout,
    int retries = 1,
  }) async {
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await http.get(uri).timeout(timeout + Duration(seconds: attempt * 5));
      } on TimeoutException {
        if (attempt >= retries) rethrow;
      } on SocketException {
        if (attempt >= retries) rethrow;
      }
    }
    throw TimeoutException('Future not completed');
  }

  static String resolveApiUrl(String pathOrUrl) {
    final raw = pathOrUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = _b.endsWith('/') ? _b.substring(0, _b.length - 1) : _b;
    final normalized = raw.replaceAll('\\', '/');
    if (normalized.startsWith('assets/images/')) {
      final fileName = normalized.split('/').last;
      return '$base/product-images/$fileName';
    }
    final path = normalized.startsWith('/') ? normalized : '/$normalized';
    return '$base$path';
  }

  // ── Products ──
  static Future<List<Product>> getProducts({String search = ''}) async {
    final uri = search.isEmpty ? Uri.parse('$_b/products') : Uri.parse('$_b/products?search=${Uri.encodeComponent(search)}');
    final r = await _getWithRetry(uri, retries: 1);
    if (r.statusCode == 200) return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => Product.fromJson(e)).toList();
    throw Exception('Lỗi tải sản phẩm: ${r.statusCode}');
  }

  static Future<void> createProduct({required String code, required String name, String description = '', required String imagePath, required List<Map<String, dynamic>> variants}) async {
    final r = await http.post(Uri.parse('$_b/products'), headers: _headers, body: jsonEncode({'code': code, 'name': name, 'description': description, 'image_path': imagePath, 'variants': variants}));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi');
  }

  static Future<String> uploadProductImage(File imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_b/product-images/upload'));
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final response = await request.send().timeout(_timeout);
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['path'] ?? '').toString();
    }
    throw Exception(jsonDecode(body)['detail'] ?? 'Lỗi upload ảnh sản phẩm');
  }

  static Future<void> updateProduct(int id, {required String code, required String name, required String imagePath, required List<Map<String, dynamic>> variants}) async {
    final r = await http.put(Uri.parse('$_b/products/$id'), headers: _headers, body: jsonEncode({'code': code, 'name': name, 'image_path': imagePath, 'variants': variants}));
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

  static Future<List<AreaSummary>> getAreas() async {
    final r = await http.get(Uri.parse('$_b/areas')).timeout(_timeout);
    if (r.statusCode == 200) return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => AreaSummary.fromJson(e)).toList();
    throw Exception('Lỗi tải khu vực');
  }

  static Future<void> createArea(String name) async {
    final r = await http.post(Uri.parse('$_b/areas'), headers: _headers, body: jsonEncode({'name': name}));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi tạo khu vực');
  }

  static Future<void> updateArea(int id, String name) async {
    final r = await http.put(Uri.parse('$_b/areas/$id'), headers: _headers, body: jsonEncode({'name': name}));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi sửa khu vực');
  }

  static Future<void> deleteArea(int id) async {
    final r = await http.delete(Uri.parse('$_b/areas/$id'));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi xóa khu vực');
  }

  static Future<Map<String, dynamic>> createCustomer({required String name, String phone = '', int debt = 0, required int areaId}) async {
    final r = await http.post(Uri.parse('$_b/customers'), headers: _headers, body: jsonEncode({'name': name, 'phone': phone, 'debt': debt, 'area_id': areaId}));
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode != 200) throw Exception(body['detail'] ?? 'Lỗi');
    return body;
  }

  static Future<void> updateCustomer(int id, {required String name, required String phone, required int debt, required int areaId}) async {
    final r = await http.put(Uri.parse('$_b/customers/$id'), headers: _headers, body: jsonEncode({'name': name, 'phone': phone, 'debt': debt, 'area_id': areaId}));
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

  static Future<void> createDebtLog(
    int cid, {
    required int changeAmount,
    required String note,
    String? createdAt,
    int? actorEmployeeId,
  }) async {
    final payload = <String, dynamic>{'change_amount': changeAmount, 'note': note};
    if (createdAt != null) payload['created_at'] = createdAt;
    if (actorEmployeeId != null) payload['actor_employee_id'] = actorEmployeeId;
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
    int? employeeId,
  }) async {
    final r = await http.post(
      Uri.parse('$_b/checkout/draft'),
      headers: _headers,
      body: jsonEncode({
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'employee_id': employeeId,
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

  /// Desktop dispatch: create order directly for picker (skip approve step)
  static Future<Map<String, dynamic>> checkoutDesktopDispatch({
    required String customerName,
    String customerPhone = '',
    required List<CartItem> cart,
    int? employeeId,
  }) async {
    final r = await http.post(
      Uri.parse('$_b/checkout/desktop-dispatch'),
      headers: _headers,
      body: jsonEncode({
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'employee_id': employeeId,
        'cart': cart.map((e) => e.toJson()).toList(),
      }),
    );
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    final body = r.bodyBytes.isNotEmpty ? jsonDecode(utf8.decode(r.bodyBytes)) : null;
    throw Exception(body is Map<String, dynamic> ? (body['detail'] ?? 'Lỗi gửi đơn cho picker') : 'Lỗi gửi đơn cho picker');
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

  /// Cancel an order in pending/approved/assigned states
  static Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    final r = await http.delete(Uri.parse('$_b/orders/$orderId/cancel'));
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi hủy đơn');
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

  static Future<List<Order>> getApprovedOrders() async {
    final r = await http.get(Uri.parse('$_b/orders/approved')).timeout(_timeout);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return (data['data'] as List).map((e) => Order.fromJson(e)).toList();
    }
    throw Exception('Lỗi tải đơn đã duyệt');
  }

  static Future<List<Order>> getAssignedOrders(int pickerId) async {
    final r = await http.get(Uri.parse('$_b/orders/assigned?picker_id=$pickerId')).timeout(_timeout);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return (data['data'] as List).map((e) => Order.fromJson(e)).toList();
    }
    throw Exception('Lỗi tải đơn đã nhận');
  }

  static Future<Map<String, dynamic>> receiveOrder(int orderId, {required int pickerId}) async {
    final r = await http.put(
      Uri.parse('$_b/orders/$orderId/receive'),
      headers: _headers,
      body: jsonEncode({'picker_id': pickerId}),
    );
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi nhận đơn');
  }

  static Future<Map<String, dynamic>> deliverOrder(
    int orderId, {
    required int pickerId,
    required List<String> photoPaths,
    List<Map<String, dynamic>>? items,
    String pickerNote = '',
  }) async {
    final paths = photoPaths.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (paths.isEmpty) {
      throw Exception('Thiếu ảnh xác nhận giao hàng');
    }
    for (final path in paths) {
      final f = File(path);
      if (!await f.exists()) {
        throw Exception('Không tìm thấy ảnh xác nhận trên thiết bị');
      }
    }

    final req = http.MultipartRequest('PUT', Uri.parse('$_b/orders/$orderId/deliver-with-photo'));
    req.fields['picker_id'] = '$pickerId';
    req.fields['items_json'] = jsonEncode(items ?? const []);
    req.fields['picker_note'] = pickerNote.trim();
    if (paths.isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath('photo', paths.first));
    }
    for (final path in paths) {
      req.files.add(await http.MultipartFile.fromPath('photos', path));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    final body = r.bodyBytes.isNotEmpty ? jsonDecode(utf8.decode(r.bodyBytes)) : null;
    throw Exception(body is Map<String, dynamic> ? (body['detail'] ?? 'Lỗi giao đơn') : 'Lỗi giao đơn');
  }

  static Future<List<Order>> getManagementOrders({int limit = 200}) async {
    final r = await http.get(Uri.parse('$_b/orders/management?limit=$limit')).timeout(_timeout);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      return (data['data'] as List).map((e) => Order.fromJson(e)).toList();
    }
    throw Exception('Lỗi tải lịch sử đơn quản lý');
  }

  static Future<Map<String, dynamic>> loginByPin({required String pin, required String requestedRole}) async {
    final r = await http.post(
      Uri.parse('$_b/auth/pin-login'),
      headers: _headers,
      body: jsonEncode({'pin': pin, 'requested_role': requestedRole}),
    );
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'PIN không hợp lệ');
  }

  static Future<List<Employee>> getEmployees() async {
    final r = await http.get(Uri.parse('$_b/employees')).timeout(_timeout);
    if (r.statusCode == 200) {
      return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => Employee.fromJson(e)).toList();
    }
    throw Exception('Lỗi tải nhân viên');
  }

  static Future<Map<String, dynamic>> createEmployee({
    required String name,
    required String phone,
    required String role,
    String email = '',
    String address = '',
    String notes = '',
  }) async {
    final r = await http.post(
      Uri.parse('$_b/employees'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'role': role,
      }),
    );
    if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi tạo nhân viên');
  }

  static Future<void> updateEmployee(
    int id, {
    required String name,
    required String phone,
    required String role,
    String email = '',
    String address = '',
    String notes = '',
    String? pin,
    bool isActive = true,
  }) async {
    final r = await http.put(
      Uri.parse('$_b/employees/$id'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'role': role,
        'pin': pin,
        'is_active': isActive ? 1 : 0,
      }),
    );
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi cập nhật nhân viên');
  }

  static Future<List<Order>> getEmployeeDeliveries(
    int employeeId, {
    String search = '',
    int days = 0,
    int limit = 200,
  }) async {
    final uri = Uri.parse('$_b/employees/$employeeId/deliveries').replace(queryParameters: {
      'q': search.trim(),
      'days': '$days',
      'limit': '$limit',
    });
    final r = await _getWithRetry(uri, retries: 1);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return (data['data'] as List? ?? const []).map((e) => Order.fromJson(e)).toList();
    }
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi tải lịch sử giao hàng');
  }

  static Future<List<Map<String, dynamic>>> getEmployeeActivities(
    int employeeId, {
    String search = '',
    int days = 0,
    int limit = 300,
  }) async {
    final uri = Uri.parse('$_b/employees/$employeeId/activities').replace(queryParameters: {
      'q': search.trim(),
      'days': '$days',
      'limit': '$limit',
    });
    final r = await http.get(uri).timeout(_timeout);
    if (r.statusCode == 200) {
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return (data['data'] as List? ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi tải lịch sử giao dịch cá nhân');
  }

  static Future<void> deleteEmployee(int id) async {
    final r = await http.delete(Uri.parse('$_b/employees/$id'));
    if (r.statusCode != 200) throw Exception(jsonDecode(utf8.decode(r.bodyBytes))['detail'] ?? 'Lỗi xóa nhân viên');
  }

  /// Picker confirms delivery — deducts stock + records debt
  static Future<Map<String, dynamic>> confirmOrder(int orderId, {List<Map<String, dynamic>>? items}) async {
    final body = items == null ? null : jsonEncode({'items': items});
    final r = await http.put(
      Uri.parse('$_b/orders/$orderId/confirm'),
      headers: _headers,
      body: body,
    );
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
