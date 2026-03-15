class OrderItem {
  final String productName;
  final int? variantId;
  final String variantInfo;
  final int quantity;
  final int price;

  OrderItem({required this.productName, this.variantId, required this.variantInfo, required this.quantity, required this.price});

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        productName: j['product_name'] ?? '',
        variantId: j['variant_id'],
        variantInfo: j['variant_info'] ?? '',
        quantity: (j['quantity'] ?? 0) as int,
        price: (j['price'] ?? 0) as int,
      );
}

class Order {
  final int id;
  final String createdAt;
  final String customerName;
  final int? customerId;
  final int totalAmount;
  final int totalQty;
  final int isDraft;  // 1 = PENDING, 0 = APPROVED
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.createdAt,
    required this.customerName,
    this.customerId,
    required this.totalAmount,
    required this.totalQty,
    required this.isDraft,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        createdAt: j['created_at'] ?? '',
        customerName: j['customer_name'] ?? 'Khách lẻ',
        customerId: j['customer_id'],
        totalAmount: (j['total_amount'] ?? 0) is int ? j['total_amount'] : (j['total_amount'] as num).toInt(),
        totalQty: (j['total_qty'] ?? 0) as int,
        isDraft: (j['is_draft'] ?? 0) as int,
        items: (j['items'] as List? ?? []).map((i) => OrderItem.fromJson(i)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_at': createdAt,
        'customer_name': customerName,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'total_qty': totalQty,
        'is_draft': isDraft,
        'items': items.map((i) => {'product_name': i.productName, 'variant_id': i.variantId, 'variant_info': i.variantInfo, 'quantity': i.quantity, 'price': i.price}).toList(),
      };

  bool get isPending => isDraft == 1;
  bool get isApproved => isDraft == 0;
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
