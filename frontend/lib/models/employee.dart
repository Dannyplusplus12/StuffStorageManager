class Employee {
  final int id;
  final String name;
  final String phone;
  final String role;
  final String pin;

  Employee({required this.id, required this.name, required this.phone, required this.role, required this.pin});

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        role: (j['role'] ?? '').toString(),
        pin: (j['pin'] ?? '').toString(),
      );
}
