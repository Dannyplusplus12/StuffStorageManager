import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

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
  final Map<int, String> _historyStatusCache = {};
  final Set<int> _highlightedHistoryOrders = {};

  String _deliveryPhotoUrl(String pathOrUrl) => ApiService.resolveApiUrl(pathOrUrl);

  Future<void> _copyPhotoLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy link ảnh'), backgroundColor: Colors.green),
    );
  }

  Future<void> _openDeliveryPhoto(Order o) async {
    final raw = o.deliveryPhotoPath.trim();
    if (raw.isEmpty) return;
    final url = _deliveryPhotoUrl(raw);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Ảnh giao hàng • Đơn #${o.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: TextButton.icon(
                        onPressed: () => _copyPhotoLink(url),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy link'),
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: kBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InteractiveViewer(
                      minScale: 0.6,
                      maxScale: 4,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Không tải được ảnh giao hàng', style: TextStyle(color: kTextSecondary)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                  Padding(padding: const EdgeInsets.all(6), child: Text('${formatCurrency(r['money'] as int)} k')),
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
      final changedIds = <int>[];
      for (final o in history) {
        final oldStatus = _historyStatusCache[o.id];
        if (oldStatus != null && oldStatus != o.status) {
          changedIds.add(o.id);
        }
      }
      _historyStatusCache
        ..clear()
        ..addEntries(history.map((o) => MapEntry(o.id, o.status)));
      final emps = rs[2] as List<Employee>;
      if (mounted) {
        setState(() {
          _orders = list;
          _historyOrders = history;
          _employees = emps;
        });
      }
      if (changedIds.isNotEmpty) {
        SystemSound.play(SystemSoundType.alert);
        for (final id in changedIds) {
          _highlightedHistoryOrders.add(id);
          Future.delayed(const Duration(seconds: 4), () {
            if (!mounted) return;
            setState(() => _highlightedHistoryOrders.remove(id));
          });
        }
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
    Color statusColor(String status) {
      switch (status) {
        case 'completed':
          return kSuccess;
        case 'assigned':
          return kPrimary;
        case 'approved':
          return const Color(0xFF0284C7);
        case 'pending':
          return const Color(0xFFF59E0B);
        default:
          return kTextSecondary;
      }
    }

    String statusLabel(String status) {
      switch (status) {
        case 'approved':
          return 'Đã duyệt';
        case 'assigned':
          return 'Đã nhận';
        case 'completed':
          return 'Hoàn thành';
        default:
          return status.toUpperCase();
      }
    }

    return Container(
      color: const Color(0xFFF3F6FB),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Quản lý', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: kTextPrimary)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: kBorder),
                      ),
                      child: Text('${_orders.length} chờ duyệt', style: const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Làm mới'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                      boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _orders.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 44, color: kTextSecondary),
                                    SizedBox(height: 8),
                                    Text('Không có hóa đơn chờ duyệt', style: TextStyle(color: kTextSecondary)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _orders.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final o = _orders[i];
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFBFDFF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Đơn #${o.id} • ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('${formatDate(o.createdAt)} • SL ${o.totalQty} • ${formatCurrency(o.totalAmount)} k', style: const TextStyle(color: kTextSecondary)),
                                        const SizedBox(height: 8),
                                        _buildOrderItemsExcelTable(o),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: TextButton(
                                                onPressed: () => _reject(o),
                                                child: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: ElevatedButton.icon(
                                                onPressed: () => _approve(o),
                                                icon: const Icon(Icons.check, size: 16),
                                                label: const Text('Duyệt'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'history', icon: Icon(Icons.history), label: Text('Lịch sử')),
                        ButtonSegment(value: 'staff', icon: Icon(Icons.badge_outlined), label: Text('Nhân viên')),
                      ],
                      selected: {_rightTab},
                      onSelectionChanged: (s) => setState(() => _rightTab = s.first),
                    ),
                  ),
                  Expanded(
                    child: _rightTab == 'history'
                        ? ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                            itemCount: _historyOrders.length,
                            itemBuilder: (_, i) {
                              final o = _historyOrders[i];
                              final c = statusColor(o.status);
                              final isHighlighted = _highlightedHistoryOrders.contains(o.id);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: isHighlighted ? kPrimary : kBorder),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isHighlighted ? const Color(0xFFFFF7E6) : const Color(0xFFFCFDFF),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                                  childrenPadding: EdgeInsets.zero,
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text('Đơn #${o.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: c.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: c.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(statusLabel(o.status), style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${o.customerName} • ${formatDate(o.createdAt)}', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                        if (o.pickerNote.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 3),
                                            child: Text('Ghi chú: ${o.pickerNote}', style: const TextStyle(fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.w600)),
                                          ),
                                        if (o.assignedPickerName.isNotEmpty)
                                          Text('Nhận: ${o.assignedPickerName} ${o.assignedAt.isNotEmpty ? '• ${o.assignedAt}' : ''}', style: const TextStyle(fontSize: 12)),
                                        if (o.deliveredByName.isNotEmpty)
                                          Text('Giao: ${o.deliveredByName} ${o.deliveredAt.isNotEmpty ? '• ${o.deliveredAt}' : ''}', style: const TextStyle(fontSize: 12)),
                                        if (o.deliveryPhotoPath.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _openDeliveryPhoto(o),
                                                  icon: const Icon(Icons.image_outlined, size: 16, color: kPrimary),
                                                  label: const Text('Xem ảnh', style: TextStyle(color: kPrimary)),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: kBorder),
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  children: [_buildOrderItemsExcelTable(o)],
                                ),
                              );
                            },
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: ElevatedButton.icon(onPressed: _createEmployee, icon: const Icon(Icons.add, size: 16), label: const Text('Thêm NV')),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _employees.length,
                                  itemBuilder: (_, i) {
                                    final e = _employees[i];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: kBorder),
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xFFFCFDFF),
                                      ),
                                      child: ListTile(
                                        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        subtitle: Text('${e.role.toUpperCase()} • ${e.phone.isEmpty ? '-' : e.phone} • PIN: ${e.pin}'),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (v) => v == 'edit' ? _editEmployee(e) : _deleteEmployee(e),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                            PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                          ],
                                        ),
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
