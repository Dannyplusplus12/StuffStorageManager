import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../dialogs/edit_log_dialog.dart';

class DebtScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onEditOrder;
  const DebtScreen({super.key, required this.onEditOrder});
  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  List<Customer> _customers = [];
  List<AreaSummary> _areas = [];
  String _filter = '';
  bool _loading = false;
  Customer? _selectedCustomer;
  final _newNameCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  final _newDebtCtrl = TextEditingController(text: '0');
  int? _selectedAreaId;
  int? _listAreaFilterId;

  Future<bool> _confirmDialog({required String title, required String message, String okText = 'Có'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTextPrimary)),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: kTextSecondary)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(okText),
                    ),
                  ),
                ],
              ),
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
    _newNameCtrl.dispose();
    _newPhoneCtrl.dispose();
    _newDebtCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rs = await Future.wait([
        ApiService.getCustomers(),
        ApiService.getAreas(),
      ]);
      final c = rs[0] as List<Customer>;
      final areas = rs[1] as List<AreaSummary>;
      if (mounted) {
        setState(() {
          _customers = c;
          _areas = areas;
          _selectedAreaId ??= (areas.isNotEmpty ? areas.first.id : null);
          final selectedId = _selectedCustomer?.id;
          if (selectedId != null) {
            _selectedCustomer = c.where((e) => e.id == selectedId).cast<Customer?>().firstWhere(
                  (e) => e != null,
                  orElse: () => null,
                );
          }
        });
      }
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

  Iterable<Customer> get _areaFiltered =>
      _listAreaFilterId == null ? _customers : _customers.where((c) => c.areaId == _listAreaFilterId);

  List<Customer> get _filtered {
    Iterable<Customer> list = _areaFiltered;
    if (_filter.isEmpty) return list.toList();
    final f = _filter.toLowerCase();
    final fNo = _removeAccents(f);
    return list
        .where((c) =>
            c.name.toLowerCase().contains(f) ||
            _removeAccents(c.name.toLowerCase()).contains(fNo) ||
            c.phone.toLowerCase().contains(f))
        .toList();
  }

  int get _totalDebt => _areaFiltered.fold(0, (s, c) => s + c.debt);

  String _removeAccents(String input) {
    const withAccents = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const withoutAccents = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyyd';
    String output = '';
    for (int i = 0; i < input.length; i++) {
      int index = withAccents.indexOf(input[i]);
      output += index == -1 ? input[i] : withoutAccents[index];
    }
    return output;
  }

  Future<void> _deleteCustomer(int id) async {
    final ok = await _confirmDialog(
      title: 'Cảnh báo',
      message: 'Xóa khách hàng?\n(Toàn bộ lịch sử và công nợ sẽ mất)',
      okText: 'Xóa',
    );
    if (ok) {
      await ApiService.deleteCustomer(id);
      if (_selectedCustomer?.id == id) {
        setState(() => _selectedCustomer = null);
      }
      _load();
    }
  }

  void _editCustomer(Customer c) async {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone);
    final debtCtrl = TextEditingController(text: '${c.debt}');
    int selectedAreaId = c.areaId ?? (_areas.isNotEmpty ? _areas.first.id : 0);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sửa khách hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(c.name, style: const TextStyle(color: kTextSecondary)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'SĐT')),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: selectedAreaId == 0 ? null : selectedAreaId,
                  decoration: const InputDecoration(labelText: 'Khu vực (*)'),
                  items: _areas.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setLocal(() => selectedAreaId = v ?? 0),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: debtCtrl,
                  decoration: const InputDecoration(labelText: 'Dư nợ'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                    ),
                    const SizedBox(width: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ElevatedButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await ApiService.updateCustomer(
                              c.id,
                              name: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              debt: int.tryParse(debtCtrl.text.replaceAll('.', '')) ?? c.debt,
                              areaId: selectedAreaId,
                            );
                            nav.pop(true);
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Widget _addPanel() {
    final names = _customers.map((e) => e.name).toSet().toList()..sort();
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Thêm khách hàng mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Autocomplete<String>(
            optionsBuilder: (v) {
              final q = v.text.trim();
              if (q.isEmpty) return names;
              final qLower = q.toLowerCase();
              final qNo = _removeAccents(qLower);
              return names.where((s) {
                final sLower = s.toLowerCase();
                return sLower.contains(qLower) || _removeAccents(sLower).contains(qNo);
              });
            },
            onSelected: (s) => _newNameCtrl.text = s,
            fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
              if (ctrl.text != _newNameCtrl.text) {
                ctrl.text = _newNameCtrl.text;
              }
              return TextField(
                controller: ctrl,
                focusNode: focusNode,
                decoration: const InputDecoration(hintText: 'Tên khách hàng (*)'),
                onChanged: (v) => _newNameCtrl.text = v,
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPhoneCtrl,
            decoration: const InputDecoration(hintText: 'Số điện thoại'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedAreaId,
            decoration: const InputDecoration(hintText: 'Chọn khu vực (*)'),
            items: _areas.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.name))).toList(),
            onChanged: (v) => setState(() => _selectedAreaId = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newDebtCtrl,
            decoration: const InputDecoration(hintText: 'Dư nợ ban đầu'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton.icon(
              onPressed: _addCustomerInline,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm khách'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomerInline() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Vui lòng nhập tên', Colors.red);
      return;
    }
    if (_selectedAreaId == null) {
      _snack('Vui lòng chọn khu vực', Colors.red);
      return;
    }
    try {
      await ApiService.createCustomer(
        name: name,
        phone: _newPhoneCtrl.text.trim(),
        debt: int.tryParse(_newDebtCtrl.text.replaceAll('.', '')) ?? 0,
        areaId: _selectedAreaId!,
      );
      _newNameCtrl.clear();
      _newPhoneCtrl.clear();
      _newDebtCtrl.text = '0';
      _snack('Đã thêm khách hàng mới', Colors.green);
      await _load();
    } catch (e) {
      _snack('$e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 420,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(child: _tableArea()),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _addPanel(),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
          margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: kBorder))),
          child: _selectedCustomer == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Chọn một khách hàng để xem lịch sử giao dịch',
                      style: TextStyle(color: kTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _CustomerHistoryPanel(
                  custId: _selectedCustomer!.id,
                  custName: _selectedCustomer!.name,
                  onEditOrder: widget.onEditOrder,
                  onChanged: _load,
                ),
        ),
        ),
      ],
    );
  }

  Widget _tableArea() {
    final data = _filtered;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Danh sách khách hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm tên hoặc SĐT...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _filter = v.trim()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _listAreaFilterId,
            isExpanded: true,
            decoration: const InputDecoration(),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Tất cả khu vực')),
              ..._areas.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.name))),
            ],
            onChanged: (v) => setState(() => _listAreaFilterId = v),
          ),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Làm mới'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
            child: Text('Tổng nợ: ${formatCurrency(_totalDebt)} đ', style: const TextStyle(color: kDanger, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text('Không có khách hàng', style: TextStyle(color: kTextSecondary)),
                        ]),
                      )
                    : ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (_, i) {
                          final c = data[i];
                          final selected = _selectedCustomer?.id == c.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFFFFF5F2) : Colors.white,
                              border: Border.all(color: selected ? kPrimary : kBorder),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              mouseCursor: SystemMouseCursors.click,
                              onTap: () => setState(() => _selectedCustomer = c),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${c.phone.isEmpty ? '-' : c.phone} • ${c.areaName.isEmpty ? 'Chưa rõ khu vực' : c.areaName}'),
                              trailing: SizedBox(
                                width: 140,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text('${formatCurrency(c.debt)} đ', textAlign: TextAlign.right, style: const TextStyle(color: kDanger, fontWeight: FontWeight.bold)),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') {
                                          _editCustomer(c);
                                        } else {
                                          _deleteCustomer(c.id);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Sửa')),
                                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _CustomerHistoryPanel extends StatefulWidget {
  final int custId;
  final String custName;
  final void Function(Map<String, dynamic>) onEditOrder;
  final VoidCallback onChanged;
  const _CustomerHistoryPanel({
    required this.custId,
    required this.custName,
    required this.onEditOrder,
    required this.onChanged,
  });

  @override
  State<_CustomerHistoryPanel> createState() => _CustomerHistoryPanelState();
}

class _CustomerHistoryPanelState extends State<_CustomerHistoryPanel> {
  List<HistoryItem> _items = [];
  bool _loading = false;

  Future<bool> _confirmDialog({required String title, required String message, String okText = 'Có'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
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
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(okText),
                    ),
                  ),
                ],
              ),
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
  void didUpdateWidget(covariant _CustomerHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.custId != widget.custId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await ApiService.getCustomerHistory(widget.custId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addLog() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => EditLogDialog(custId: widget.custId));
    if (ok == true) {
      _load();
      widget.onChanged();
    }
  }

  void _editLog(HistoryItem h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => EditLogDialog(
        custId: widget.custId,
        data: {'log_id': h.logId, 'desc': h.desc, 'amount': h.amount, 'date': h.date},
      ),
    );
    if (ok == true) {
      _load();
      widget.onChanged();
    }
  }

  void _deleteLog(int logId) async {
    final ok = await _confirmDialog(title: 'Xác nhận xóa', message: 'Xóa bản ghi điều chỉnh này?', okText: 'Xóa');
    if (ok) {
      await ApiService.deleteDebtLog(widget.custId, logId);
      _load();
      widget.onChanged();
    }
  }

  void _deleteInvoice(int orderId) async {
    final ok = await _confirmDialog(title: 'Xác nhận xóa', message: 'Xóa hóa đơn này?', okText: 'Xóa');
    if (ok) {
      await ApiService.deleteOrder(orderId);
      _load();
      widget.onChanged();
    }
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

  Widget _buildDetail(HistoryItem h) {
    final isOrder = h.type == 'ORDER';
    final d = h.data;
    final orderItems = (d?['items'] as List?) ?? const [];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOrder ? 'Chi tiết đơn hàng' : 'Chi tiết điều chỉnh',
            style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
          const SizedBox(height: 6),
          Text('Nội dung: ${h.desc}', style: const TextStyle(color: kTextSecondary)),
          const SizedBox(height: 4),
          Text('Số tiền: ${formatSignedCurrency(h.amount)}', style: const TextStyle(color: kTextSecondary)),
          if (isOrder) ...[
            const SizedBox(height: 8),
            if (orderItems.isEmpty)
              const Text('- Không có chi tiết mặt hàng', style: TextStyle(color: kTextSecondary))
            else ...() {
              final grouped = <String, Map<String, dynamic>>{};
              for (final item in orderItems) {
                final map = item as Map<String, dynamic>;
                final product = (map['product_name'] ?? '').toString();
                final variantInfo = (map['variant_info'] ?? '').toString();
                final qty = (map['quantity'] ?? 0) as int;
                final price = (map['price'] ?? 0) as int;
                final parsed = _splitVariantInfo(variantInfo);
                grouped.putIfAbsent(product, () => {'totalQty': 0, 'colors': <String, Map<String, int>>{}});
                grouped[product]!['totalQty'] = (grouped[product]!['totalQty'] as int) + qty;
                final colors = grouped[product]!['colors'] as Map<String, Map<String, int>>;
                final colorKey = parsed.color.isEmpty ? 'Khác' : parsed.color;
                colors.putIfAbsent(colorKey, () => {'qty': 0, 'money': 0});
                colors[colorKey]!['qty'] = (colors[colorKey]!['qty'] ?? 0) + qty;
                colors[colorKey]!['money'] = (colors[colorKey]!['money'] ?? 0) + (qty * price);
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
              return [
                Container(
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
              ];
            }(),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch sử — ${widget.custName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Thêm điều chỉnh'),
                  onPressed: _addLog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Chưa có lịch sử'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final h = _items[index];
                            final isOrder = h.type == 'ORDER';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${formatDate(h.date)} · ${isOrder ? 'Xuất đơn' : 'Điều chỉnh'} · ${h.desc}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: isOrder ? Colors.blue : Colors.green),
                                        ),
                                      ),
                                      Text(
                                        formatSignedCurrency(h.amount),
                                        style: TextStyle(
                                          color: h.amount > 0 ? Colors.red : Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      PopupMenuButton<String>(
                                        tooltip: 'Tác vụ',
                                        itemBuilder: (_) => [
                                          PopupMenuItem(value: 'edit', child: Text(isOrder ? 'Sửa đơn' : 'Sửa điều chỉnh')),
                                          const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                                        ],
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            if (isOrder) {
                                              final d = h.data;
                                              if (d != null) widget.onEditOrder(d);
                                            } else {
                                              _editLog(h);
                                            }
                                          } else {
                                            if (isOrder) {
                                              _deleteInvoice((h.data?['id'] ?? 0) as int);
                                            } else if (h.logId != null) {
                                              _deleteLog(h.logId!);
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  _buildDetail(h),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}