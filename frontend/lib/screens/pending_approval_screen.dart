import 'package:flutter/material.dart';
import 'dart:async';

import '../models/order.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils.dart';

class PendingApprovalScreen extends StatefulWidget {
  final VoidCallback? onChanged;
  const PendingApprovalScreen({super.key, this.onChanged});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _loading = true;
  List<Order> _orders = [];
  List<Order> _historyOrders = [];
  List<Employee> _employees = [];
  String _rightTab = 'history';
  Timer? _refreshTimer;

  DateTime? _parseApiDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t.replaceFirst(' ', 'T'));
  }

  int _historySortTs(Order o) {
    final candidates = <DateTime?>[
      _parseApiDate(o.deliveredAt),
      _parseApiDate(o.assignedAt),
      _parseApiDate(o.createdAt),
    ].whereType<DateTime>().toList();
    if (candidates.isEmpty) return o.id;
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.first.millisecondsSinceEpoch;
  }

  ({String color, String size}) _splitVariantInfo(String raw) {
    if (raw.contains('-')) {
      final p = raw.split('-');
      return (color: p.first.trim(), size: p.sublist(1).join('-').trim());
    }
    if (raw.contains('/')) {
      final p = raw.split('/');
      return (color: p.first.trim(), size: p.sublist(1).join('/').trim());
    }
    return (color: raw.trim(), size: '');
  }

  Widget _buildOrderItemsExcelTable(Order o) {
    if (o.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Text('- Không có chi tiết mặt hàng', style: TextStyle(color: kTextSecondary)),
      );
    }

    final grouped = <String, Map<String, dynamic>>{};
    for (final item in o.items) {
      final product = item.productName.trim();
      final parsed = _splitVariantInfo(item.variantInfo);
      final color = parsed.color.isEmpty ? 'Khác' : parsed.color;
      grouped.putIfAbsent(product, () => {'colors': <String, Map<String, int>>{}});
      final colors = grouped[product]!['colors'] as Map<String, Map<String, int>>;
      colors.putIfAbsent(color, () => {'qty': 0, 'money': 0});
      colors[color]!['qty'] = (colors[color]!['qty'] ?? 0) + item.quantity;
      colors[color]!['money'] = (colors[color]!['money'] ?? 0) + (item.quantity * item.price);
    }

    final rows = <Map<String, dynamic>>[];
    grouped.forEach((product, val) {
      final colors = val['colors'] as Map<String, Map<String, int>>;
      colors.forEach((color, cm) {
        rows.add({
          'product': product,
          'color': color,
          'qty': cm['qty'] ?? 0,
          'money': cm['money'] ?? 0,
        });
      });
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFFF8FAFC),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1.5),
          },
          border: const TableBorder.symmetric(inside: BorderSide(color: kBorder)),
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFEFF3F8)),
              children: [
                Padding(padding: EdgeInsets.all(6), child: Text('Mẫu', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(6), child: Text('Màu', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(6), child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(padding: EdgeInsets.all(6), child: Text('Tiền', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            ...rows.map((r) => TableRow(children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text(r['product'].toString())),
                  Padding(padding: const EdgeInsets.all(6), child: Text(r['color'].toString())),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${r['qty']}')),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${formatCurrency(r['money'] as int)} đ')),
                ])),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rs = await Future.wait([
        ApiService.getPendingOrders(),
        ApiService.getManagementOrders(limit: 200),
        ApiService.getEmployees(),
      ]);
      final list = rs[0] as List<Order>;
      final history = (rs[1] as List<Order>)
        ..sort((a, b) {
          final t = _historySortTs(b).compareTo(_historySortTs(a));
          if (t != 0) return t;
          return b.id.compareTo(a.id);
        });
      final emps = rs[2] as List<Employee>;
      if (mounted) {
        setState(() {
          _orders = list;
          _historyOrders = history;
          _employees = emps;
        });
      }
      await NotificationService.getPendingOrders();
      widget.onChanged?.call();
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải đơn chờ duyệt: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _approve(Order order) async {
    try {
      await ApiService.approveOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã duyệt hóa đơn #${order.id}'), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duyệt thất bại: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject(Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Từ chối hóa đơn'),
        content: Text('Xóa hóa đơn nháp #${order.id}?'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Từ chối'),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService.rejectOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã từ chối hóa đơn #${order.id}'), backgroundColor: Colors.orange),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Từ chối thất bại: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createEmployee() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'picker';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm nhân viên'),
        content: StatefulBuilder(
          builder: (_, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'SĐT')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'orderer', child: Text('Orderer')),
                  DropdownMenuItem(value: 'picker', child: Text('Picker')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (v) => setLocal(() => role = v ?? 'picker'),
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ApiService.createEmployee(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), role: role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tạo. PIN: ${res['pin']}'), backgroundColor: Colors.green));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editEmployee(Employee e) async {
    final nameCtrl = TextEditingController(text: e.name);
    final phoneCtrl = TextEditingController(text: e.phone);
    String role = e.role;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sửa nhân viên #${e.id}'),
        content: StatefulBuilder(
          builder: (_, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'SĐT')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                items: const [
                  DropdownMenuItem(value: 'orderer', child: Text('Orderer')),
                  DropdownMenuItem(value: 'picker', child: Text('Picker')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (v) => setLocal(() => role = v ?? e.role),
                decoration: const InputDecoration(labelText: 'Vai trò'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.updateEmployee(e.id, name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), role: role);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteEmployee(Employee e) async {
    try {
      await ApiService.deleteEmployee(e.id);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Quản lý', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
                      child: Text('${_orders.length} chờ duyệt', style: const TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Làm mới')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _orders.isEmpty
                          ? const Center(child: Text('Không có hóa đơn chờ duyệt', style: TextStyle(color: kTextSecondary)))
                          : ListView.separated(
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final o = _orders[i];
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Đơn #${o.id} • ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('${formatDate(o.createdAt)} • SL ${o.totalQty} • ${formatCurrency(o.totalAmount)} đ'),
                                       const SizedBox(height: 6),
                                       _buildOrderItemsExcelTable(o),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(onPressed: () => _reject(o), child: const Text('Từ chối', style: TextStyle(color: Colors.red))),
                                          const SizedBox(width: 6),
                                          ElevatedButton(onPressed: () => _approve(o), child: const Text('Duyệt')),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'history', icon: Icon(Icons.history), label: Text('Lịch sử')),
                              ButtonSegment(value: 'staff', icon: Icon(Icons.badge_outlined), label: Text('Nhân viên')),
                            ],
                            selected: {_rightTab},
                            onSelectionChanged: (s) => setState(() => _rightTab = s.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _rightTab == 'history'
                        ? ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: _historyOrders.length,
                            itemBuilder: (_, i) {
                              final o = _historyOrders[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  childrenPadding: EdgeInsets.zero,
                                  title: Text('Đơn #${o.id} • ${o.status.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${o.customerName} • ${formatDate(o.createdAt)}', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                      if (o.assignedPickerName.isNotEmpty)
                                        Text('Nhận: ${o.assignedPickerName} ${o.assignedAt.isNotEmpty ? '• ${o.assignedAt}' : ''}', style: const TextStyle(fontSize: 12)),
                                      if (o.deliveredByName.isNotEmpty)
                                        Text('Giao: ${o.deliveredByName} ${o.deliveredAt.isNotEmpty ? '• ${o.deliveredAt}' : ''}', style: const TextStyle(fontSize: 12)),
                                      if (o.deliveryPhotoPath.isNotEmpty)
                                        Text('Ảnh: ${o.deliveryPhotoPath}', style: const TextStyle(fontSize: 12, color: kPrimary)),
                                    ],
                                  ),
                                  children: [_buildOrderItemsExcelTable(o)],
                                ),
                              );
                            },
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton.icon(onPressed: _createEmployee, icon: const Icon(Icons.add, size: 16), label: const Text('Thêm NV')),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(10),
                                  itemCount: _employees.length,
                                  itemBuilder: (_, i) {
                                    final e = _employees[i];
                                    return ListTile(
                                      title: Text('${e.name} (${e.role})'),
                                      subtitle: Text('${e.phone.isEmpty ? '-' : e.phone} • PIN: ${e.pin}'),
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            _editEmployee(e);
                                          } else {
                                            _deleteEmployee(e);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
