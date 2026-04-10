import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';

class AreasScreen extends StatefulWidget {
  final ValueChanged<int>? onOpenDebtByArea;
  const AreasScreen({super.key, this.onOpenDebtByArea});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  List<AreaSummary> _areas = [];

  Future<bool> _confirmDialog({required String title, required String message, String okText = 'Xóa'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: kTextSecondary)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(cursor: SystemMouseCursors.click, child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không'))),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text(okText)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final areas = await ApiService.getAreas();
      if (mounted) setState(() => _areas = areas);
    } catch (e) {
      _snack('$e', Colors.red);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Vui lòng nhập tên khu vực', Colors.red);
      return;
    }
    try {
      await ApiService.createArea(name);
      _nameCtrl.clear();
      _snack('Đã thêm khu vực', Colors.green);
      _load();
    } catch (e) {
      _snack('$e', Colors.red);
    }
  }

  Future<void> _rename(AreaSummary a) async {
    final ctrl = TextEditingController(text: a.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Đổi tên khu vực', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 8),
              TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Tên khu vực')),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(cursor: SystemMouseCursors.click, child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy'))),
                  const SizedBox(width: 8),
                  MouseRegion(cursor: SystemMouseCursors.click, child: ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.updateArea(a.id, ctrl.text.trim());
      _snack('Đã cập nhật khu vực', Colors.green);
      _load();
    } catch (e) {
      _snack('$e', Colors.red);
    }
  }

  Future<void> _delete(AreaSummary a) async {
    final ok = await _confirmDialog(
      title: 'Xóa khu vực?',
      message: 'Khu vực "${a.name}" sẽ bị xóa. Khách hàng sẽ được chuyển khu vực mặc định.',
      okText: 'Xóa',
    );
    if (!ok) return;
    try {
      await ApiService.deleteArea(a.id);
      _snack('Đã xóa khu vực', Colors.green);
      _load();
    } catch (e) {
      _snack('$e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 340,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Thêm chợ / khu vực mới', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Tên khu vực...')),
                  const SizedBox(height: 10),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton.icon(onPressed: _create, icon: const Icon(Icons.add, size: 16), label: const Text('Tạo khu vực')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columns: const [
                          DataColumn(label: Text('Tên Khu Vực', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Số Khách', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Tổng Nợ Khu Vực', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _areas.map((a) {
                          return DataRow(cells: [
                            DataCell(
                              Text(a.name),
                              onTap: () => widget.onOpenDebtByArea?.call(a.id),
                            ),
                            DataCell(Text('${a.customerCount}'), onTap: () => widget.onOpenDebtByArea?.call(a.id)),
                            DataCell(Text('${formatCurrency(a.totalDebt)} k'), onTap: () => widget.onOpenDebtByArea?.call(a.id)),
                            DataCell(PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _rename(a);
                                } else {
                                  _delete(a);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                PopupMenuItem(value: 'delete', child: Text('Xóa')),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
