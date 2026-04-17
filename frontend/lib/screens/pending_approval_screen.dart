import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
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
  String _employeeSearch = '';
  String _employeeRoleFilter = 'all';
  Timer? _refreshTimer;
  final Map<int, String> _historyStatusCache = {};
  final Set<int> _highlightedHistoryOrders = {};

  String _deliveryPhotoUrl(String pathOrUrl) => ApiService.resolveApiUrl(pathOrUrl);
  File? _deliveryPhotoFile(String pathOrUrl) => resolveLocalDeliveryProofFile(pathOrUrl);

  Future<void> _copyPhotoLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã copy link ảnh'), backgroundColor: Colors.green),
    );
  }

  Future<void> _openDeliveryPhoto(Order o) async {
    final paths = o.deliveryPhotoPaths.isNotEmpty
        ? o.deliveryPhotoPaths
        : (o.deliveryPhotoPath.trim().isEmpty ? const <String>[] : [o.deliveryPhotoPath.trim()]);
    if (paths.isEmpty) return;
    final assets = paths
        .map((p) => (file: _deliveryPhotoFile(p), url: _deliveryPhotoUrl(p)))
        .toList();
    final pageController = PageController();
    var currentIndex = 0;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => Dialog(
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
                        child: Text(
                          'Ảnh giao hàng • Đơn #${o.id}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (assets.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text('Ảnh ${currentIndex + 1}/${assets.length}', style: const TextStyle(color: kTextSecondary)),
                        ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: TextButton.icon(
                          onPressed: () => _copyPhotoLink(assets[currentIndex].file?.path ?? assets[currentIndex].url),
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
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: assets.length,
                          onPageChanged: (index) => setState(() => currentIndex = index),
                          itemBuilder: (_, i) {
                            final file = assets[i].file;
                            if (file != null) {
                              return Image.file(
                                file,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Text('Không tải được ảnh giao hàng', style: TextStyle(color: kTextSecondary)),
                                ),
                              );
                            }
                            return Image.network(
                              assets[i].url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('Không tải được ảnh giao hàng', style: TextStyle(color: kTextSecondary)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (assets.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: assets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final active = i == currentIndex;
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => pageController.jumpToPage(i),
                              child: Container(
                                width: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: active ? kPrimary : kBorder, width: active ? 2 : 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: assets[i].file != null
                                      ? Image.file(
                                          assets[i].file!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                                        )
                                      : Image.network(
                                          assets[i].url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
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
          border: Border.all(color: appBorderColor(context)),
          borderRadius: BorderRadius.circular(6),
          color: appPanelSoftBg(context),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1.5),
          },
          border: TableBorder.symmetric(inside: BorderSide(color: appBorderColor(context))),
          children: [
            TableRow(
              decoration: BoxDecoration(color: appPanelBg(context)),
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

  Future<void> _cancel(Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hủy đơn'),
        content: Text('Hủy đơn #${order.id}?'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hủy đơn'),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService.cancelOrder(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã hủy đơn #${order.id}'), backgroundColor: Colors.orange),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hủy đơn thất bại: $e'), backgroundColor: Colors.red),
      );
    }
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
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
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
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (tuỳ chọn)')),
              const SizedBox(height: 8),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ (tuỳ chọn)')),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)')),
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
      final res = await ApiService.createEmployee(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        role: role,
      );
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
    final emailCtrl = TextEditingController(text: e.email);
    final addressCtrl = TextEditingController(text: e.address);
    final notesCtrl = TextEditingController(text: e.notes);
    final pinCtrl = TextEditingController();
    String role = e.role;
    bool isActive = e.isActive;
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
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 8),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Địa chỉ')),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú')),
              const SizedBox(height: 8),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN mới (để trống nếu giữ nguyên)',
                  hintText: '4-8 chữ số',
                ),
              ),
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
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                onChanged: (v) => setLocal(() => isActive = v),
                title: const Text('Tài khoản đang hoạt động'),
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
      await ApiService.updateEmployee(
        e.id,
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        role: role,
        pin: pinCtrl.text.trim().isEmpty ? null : pinCtrl.text.trim(),
        isActive: isActive,
      );
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: Colors.red));
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'picker':
        return 'Picker';
      case 'orderer':
        return 'Orderer';
      case 'manager':
        return 'Manager';
      default:
        return role;
    }
  }

  Future<void> _openEmployeeDeliveryHistory(Employee employee) async {
    final searchCtrl = TextEditingController();
    var range = 1; // 1=day, 2=month, 3=year
    var loading = true;
    var orders = <Order>[];
    String? error;

    Future<void> load(BuildContext dialogCtx, StateSetter setDialogState) async {
      if (!dialogCtx.mounted) return;
      setDialogState(() {
        loading = true;
        error = null;
      });
      try {
        final now = DateTime.now();
        final days = range == 1 ? 1 : (range == 2 ? now.day : now.difference(DateTime(now.year, 1, 1)).inDays + 1);
        final rows = await ApiService.getEmployeeDeliveries(
          employee.id,
          search: searchCtrl.text.trim(),
          days: days,
          limit: 300,
        );
        if (!dialogCtx.mounted) return;
        setDialogState(() {
          orders = rows;
          loading = false;
        });
      } catch (e) {
        if (!dialogCtx.mounted) return;
        setDialogState(() {
          error = '$e';
          loading = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          if (loading && orders.isEmpty && error == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => load(dialogContext, setDialogState));
          }
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
              child: Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Lịch sử giao • ${employee.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Tìm theo mã đơn / tên khách',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                            onSubmitted: (_) => load(dialogContext, setDialogState),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: range,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('Ngày này')),
                            DropdownMenuItem(value: 2, child: Text('Tháng này')),
                            DropdownMenuItem(value: 3, child: Text('Năm này')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setDialogState(() => range = v);
                            load(dialogContext, setDialogState);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : error != null
                              ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                              : orders.isEmpty
                                  ? const Center(child: Text('Chưa có đơn giao phù hợp'))
                                  : ListView.builder(
                                      itemCount: orders.length,
                                      itemBuilder: (_, i) {
                                        final o = orders[i];
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: kBorder),
                                            color: Colors.white,
                                          ),
                                          child: ExpansionTile(
                                            tilePadding: EdgeInsets.zero,
                                            childrenPadding: EdgeInsets.zero,
                                            title: Text('Đơn #${o.id} • ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Giao lúc: ${o.deliveredAt.isEmpty ? '-' : o.deliveredAt}', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                                Text('SL ${o.totalQty} • ${formatCurrency(o.totalAmount)} k', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                              ],
                                            ),
                                            children: [
                                              const SizedBox(height: 6),
                                              _buildOrderItemsExcelTable(o),
                                              if (o.deliveryPhotoPath.isNotEmpty || o.deliveryPhotoPaths.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: OutlinedButton.icon(
                                                      onPressed: () => _openDeliveryPhoto(o),
                                                      icon: const Icon(Icons.image_outlined, size: 16, color: kPrimary),
                                                      label: Text(
                                                        o.deliveryPhotoPaths.length > 1 ? 'Xem ảnh (${o.deliveryPhotoPaths.length})' : 'Xem ảnh xác nhận',
                                                        style: const TextStyle(color: kPrimary),
                                                      ),
                                                    ),
                                                  ),
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
            ),
          );
        },
      ),
    );
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
    final panelBg = appPanelBg(context);
    final panelSoftBg = appPanelSoftBg(context);
    final borderColor = appBorderColor(context);
    final textPrimary = appTextPrimary(context);
    final textSecondary = appTextSecondary(context);

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
        case 'pending':
          return 'Đợi duyệt';
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

    final filteredEmployees = _employees.where((e) {
      final q = _employeeSearch.trim().toLowerCase();
      final roleOk = _employeeRoleFilter == 'all' ? true : e.role == _employeeRoleFilter;
      if (!roleOk) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.phone.toLowerCase().contains(q) ||
          e.pin.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q);
    }).toList();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
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
                    Text('Quản lý', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: panelBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text('${_orders.length} chờ duyệt', style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Làm mới'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: panelBg,
                          side: BorderSide(color: borderColor),
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
                      color: panelBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _orders.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 44, color: textSecondary),
                                    const SizedBox(height: 8),
                                    Text('Không có hóa đơn chờ duyệt', style: TextStyle(color: textSecondary)),
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
                                      color: panelSoftBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Đơn #${o.id} • ${o.customerName}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary)),
                                        const SizedBox(height: 4),
                                        Text('${formatDate(o.createdAt)} • SL ${o.totalQty} • ${formatCurrency(o.totalAmount)} k', style: TextStyle(color: textSecondary)),
                                         if (o.createdByEmployeeName.trim().isNotEmpty)
                                           Padding(
                                             padding: const EdgeInsets.only(top: 2),
                                              child: Text('Người gửi: ${o.createdByEmployeeName}', style: TextStyle(fontSize: 12, color: textSecondary)),
                                           ),
                                        const SizedBox(height: 8),
                                        _buildOrderItemsExcelTable(o),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: TextButton(
                                                onPressed: () => _cancel(o),
                                                child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
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
                color: panelBg,
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(14),
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
                                  border: Border.all(color: isHighlighted ? kPrimary : borderColor),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isHighlighted ? const Color(0xFFFFF7E6) : panelSoftBg,
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
                                        Text('${o.customerName} • ${formatDate(o.createdAt)}', style: TextStyle(color: textSecondary, fontSize: 12)),
                                        if (o.pickerNote.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 3),
                                            child: Text('Ghi chú: ${o.pickerNote}', style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
                                          ),
                                        if (o.assignedPickerName.isNotEmpty)
                                          Text('Nhận: ${o.assignedPickerName} ${o.assignedAt.isNotEmpty ? '• ${o.assignedAt}' : ''}', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        if (o.deliveredByName.isNotEmpty)
                                          Text('Giao: ${o.deliveredByName} ${o.deliveredAt.isNotEmpty ? '• ${o.deliveredAt}' : ''}', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        if (o.deliveryPhotoPath.isNotEmpty || o.deliveryPhotoPaths.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors.click,
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _openDeliveryPhoto(o),
                                                  icon: const Icon(Icons.image_outlined, size: 16, color: kPrimary),
                                                  label: Text(
                                                    o.deliveryPhotoPaths.length > 1
                                                        ? 'Xem ảnh (${o.deliveryPhotoPaths.length})'
                                                        : 'Xem ảnh',
                                                    style: const TextStyle(color: kPrimary),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: borderColor),
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
                                  children: [
                                    _buildOrderItemsExcelTable(o),
                                    if (o.status == 'pending' || o.status == 'approved' || o.status == 'assigned')
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            MouseRegion(
                                              cursor: SystemMouseCursors.click,
                                              child: OutlinedButton.icon(
                                                onPressed: () => _cancel(o),
                                                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                                label: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.red),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          hintText: 'Tìm tên / SĐT / email / PIN',
                                          isDense: true,
                                          prefixIcon: Icon(Icons.search),
                                        ),
                                        onChanged: (v) => setState(() => _employeeSearch = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    DropdownButton<String>(
                                      value: _employeeRoleFilter,
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                                        DropdownMenuItem(value: 'orderer', child: Text('Orderer')),
                                        DropdownMenuItem(value: 'picker', child: Text('Picker')),
                                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                      ],
                                      onChanged: (v) => setState(() => _employeeRoleFilter = v ?? 'all'),
                                    ),
                                    const SizedBox(width: 8),
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: ElevatedButton.icon(
                                        onPressed: _createEmployee,
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Thêm NV'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: filteredEmployees.isEmpty
                                    ? Center(child: Text('Không có nhân viên phù hợp', style: TextStyle(color: textSecondary)))
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: filteredEmployees.length,
                                        itemBuilder: (_, i) {
                                          final e = filteredEmployees[i];
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: borderColor),
                                              borderRadius: BorderRadius.circular(10),
                                              color: panelSoftBg,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(e.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textPrimary)),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: e.isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                                        borderRadius: BorderRadius.circular(999),
                                                      ),
                                                      child: Text(
                                                        e.isActive ? 'Đang hoạt động' : 'Đang khóa',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          color: e.isActive ? kSuccess : Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                    PopupMenuButton<String>(
                                                      onSelected: (v) => v == 'edit' ? _editEmployee(e) : _deleteEmployee(e),
                                                      itemBuilder: (_) => const [
                                                        PopupMenuItem(value: 'edit', child: Text('Sửa thông tin')),
                                                        PopupMenuItem(value: 'delete', child: Text('Xóa nhân viên')),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text('${_roleLabel(e.role)} • PIN: ${e.pin}', style: TextStyle(color: textSecondary)),
                                                Text('SĐT: ${e.phone.isEmpty ? '-' : e.phone} • Email: ${e.email.isEmpty ? '-' : e.email}', style: TextStyle(color: textSecondary)),
                                                if (e.address.trim().isNotEmpty) Text('Địa chỉ: ${e.address.trim()}', style: TextStyle(color: textSecondary)),
                                                if (e.notes.trim().isNotEmpty) Text('Ghi chú: ${e.notes.trim()}', style: TextStyle(color: textSecondary)),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Đã giao: ${e.deliveredCount} đơn${e.lastDeliveredAt.isNotEmpty ? ' • Gần nhất: ${e.lastDeliveredAt}' : ''}',
                                                        style: TextStyle(fontSize: 12, color: textSecondary),
                                                      ),
                                                    ),
                                                    MouseRegion(
                                                      cursor: SystemMouseCursors.click,
                                                      child: OutlinedButton.icon(
                                                        onPressed: () => _openEmployeeDeliveryHistory(e),
                                                        icon: const Icon(Icons.history, size: 16),
                                                        label: const Text('Lịch sử giao'),
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
