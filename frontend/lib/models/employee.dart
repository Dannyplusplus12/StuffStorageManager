class Employee {
  final int id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final String role;
  final String pin;
  final bool isActive;
  final String createdAt;
  final int deliveredCount;
  final String lastDeliveredAt;

  Employee({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.notes = '',
    required this.role,
    required this.pin,
    this.isActive = true,
    this.createdAt = '',
    this.deliveredCount = 0,
    this.lastDeliveredAt = '',
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        address: (j['address'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        pin: (j['pin'] ?? '').toString(),
        isActive: ((j['is_active'] ?? 1) as num).toInt() == 1,
        createdAt: (j['created_at'] ?? '').toString(),
        deliveredCount: ((j['delivered_count'] ?? 0) as num).toInt(),
        lastDeliveredAt: (j['last_delivered_at'] ?? '').toString(),
      );
}
