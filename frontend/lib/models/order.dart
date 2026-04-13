import 'dart:convert';

class OrderItem {
  final int? orderItemId;
  final String productName;
  final int? variantId;
  final String variantInfo;
  final int quantity;
  final int price;
  final int? currentStock;
  final bool? enoughStock;

  OrderItem({
    this.orderItemId,
    required this.productName,
    this.variantId,
    required this.variantInfo,
    required this.quantity,
    required this.price,
    this.currentStock,
    this.enoughStock,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        orderItemId: j['order_item_id'],
        productName: j['product_name'] ?? '',
        variantId: j['variant_id'],
        variantInfo: j['variant_info'] ?? '',
        quantity: (j['quantity'] ?? 0) as int,
        price: (j['price'] ?? 0) as int,
        currentStock: j['current_stock'],
        enoughStock: j['enough_stock'],
      );
}

class Order {
  final int id;
  final String createdAt;
  final String customerName;
  final int? customerId;
  final int totalAmount;
  final int totalQty;
  final String status;  // 'pending' | 'approved' | 'assigned' | 'completed'
  final String pickerNote;
  final int? createdByEmployeeId;
  final String createdByEmployeeName;
  final int? assignedPickerId;
  final String assignedPickerName;
  final String assignedAt;
  final int? deliveredById;
  final String deliveredByName;
  final String deliveredAt;
  final String deliveryPhotoPath;
  final List<String> deliveryPhotoPaths;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.createdAt,
    required this.customerName,
    this.customerId,
    required this.totalAmount,
    required this.totalQty,
    required this.status,
    this.pickerNote = '',
    this.createdByEmployeeId,
    this.createdByEmployeeName = '',
    this.assignedPickerId,
    this.assignedPickerName = '',
    this.assignedAt = '',
    this.deliveredById,
    this.deliveredByName = '',
    this.deliveredAt = '',
    this.deliveryPhotoPath = '',
    this.deliveryPhotoPaths = const [],
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        createdAt: j['created_at'] ?? '',
        customerName: j['customer_name'] ?? 'Khách lẻ',
        customerId: j['customer_id'],
        totalAmount: (j['total_amount'] ?? 0) is int ? j['total_amount'] : (j['total_amount'] as num).toInt(),
        totalQty: (j['total_qty'] ?? 0) as int,
        status: j['status'] ?? (j['is_draft'] == 1 ? 'pending' : 'completed'),
        pickerNote: (j['picker_note'] ?? '').toString(),
        createdByEmployeeId: j['created_by_employee_id'],
        createdByEmployeeName: (j['created_by_employee_name'] ?? '').toString(),
        assignedPickerId: j['assigned_picker_id'],
        assignedPickerName: (j['assigned_picker_name'] ?? '').toString(),
        assignedAt: (j['assigned_at'] ?? '').toString(),
        deliveredById: j['delivered_by_id'],
        deliveredByName: (j['delivered_by_name'] ?? '').toString(),
        deliveredAt: (j['delivered_at'] ?? '').toString(),
        deliveryPhotoPath: (j['delivery_photo_path'] ?? '').toString(),
        deliveryPhotoPaths: _parsePhotoPaths(j),
        items: (j['items'] as List? ?? []).map((i) => OrderItem.fromJson(i)).toList(),
      );

  static List<String> _parsePhotoPaths(Map<String, dynamic> j) {
    final rawList = j['delivery_photo_paths'];
    if (rawList is List) {
      return rawList.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    final raw = (j['delivery_photo_path'] ?? '').toString().trim();
    if (raw.isEmpty) return const [];
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        }
      } catch (_) {}
    }
    if (raw.contains('|')) {
      return raw.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [raw];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt,
        'customer_name': customerName,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'total_qty': totalQty,
        'status': status,
        'picker_note': pickerNote,
        'created_by_employee_id': createdByEmployeeId,
        'created_by_employee_name': createdByEmployeeName,
        'assigned_picker_id': assignedPickerId,
        'assigned_picker_name': assignedPickerName,
        'assigned_at': assignedAt,
        'delivered_by_id': deliveredById,
        'delivered_by_name': deliveredByName,
        'delivered_at': deliveredAt,
        'delivery_photo_path': deliveryPhotoPath,
        'items': items
            .map((i) => {
                  'order_item_id': i.orderItemId,
                  'product_name': i.productName,
                  'variant_id': i.variantId,
                  'variant_info': i.variantInfo,
                  'quantity': i.quantity,
                  'price': i.price,
                  'current_stock': i.currentStock,
                  'enough_stock': i.enoughStock,
                })
            .toList(),
      };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isAssigned => status == 'assigned';
  bool get isCompleted => status == 'completed';
  // backward compat
  bool get isAccepted => isApproved;
  int get isDraft => isPending || isApproved || isAssigned ? 1 : 0;
}

class CartItem {
  final int variantId;
  final String productName;
  final String color;
  final String size;
  final int price;
  int quantity;

  CartItem({required this.variantId, required this.productName, required this.color, required this.size, required this.price, required this.quantity});

  Map<String, dynamic> toJson() => {
        'variant_id': variantId,
        'product_name': productName,
        'color': color,
        'size': size,
        'price': price,
        'quantity': quantity,
      };
}
