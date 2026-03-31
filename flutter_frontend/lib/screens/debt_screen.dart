import 'dart:math' as math;

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
  String _filter = '';
  bool _loading = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await ApiService.getCustomers();
      if (mounted) {
        setState(() {
          _customers = c;
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

  List<Customer> get _filtered => _filter.isEmpty
      ? _customers
      : _customers
          .where((c) =>
              c.name.toLowerCase().contains(_filter) ||
              _removeAccents(c.name.toLowerCase()).contains(_removeAccents(_filter.toLowerCase())) ||
              c.phone.toLowerCase().contains(_filter))
          .toList();

  int get _totalDebt => _customers.fold(0, (s, c) => s + c.debt);

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cảnh báo'),
        content: const Text('Xóa khách hàng?\n(Toàn bộ lịch sử và công nợ sẽ mất)'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Có'),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sửa: ${c.name}'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên')),
            const SizedBox(height: 8),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'SĐT')),
            const SizedBox(height: 8),
            TextField(
              controller: debtCtrl,
              decoration: const InputDecoration(labelText: 'Dư nợ'),
              keyboardType: TextInputType.number,
            ),
          ]),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ),
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
    );
    if (saved == true) _load();
  }

  void _openAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final debtCtrl = TextEditingController(text: '0');
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm khách hàng mới'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên khách hàng (*)')),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Số điện thoại')),
              const SizedBox(height: 8),
              TextField(
                controller: debtCtrl,
                decoration: const InputDecoration(labelText: 'Dư nợ ban đầu (VNĐ)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên'), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  await ApiService.createCustomer(
                    name: name,
                    phone: phoneCtrl.text.trim(),
                    debt: int.tryParse(debtCtrl.text.replaceAll('.', '')) ?? 0,
                  );
                  if (mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ),
        ],
      ),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tableArea()),
        Container(
          width: 520,
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
      ],
    );
  }

  Widget _tableArea() {
    final data = _filtered;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final titleBadge = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text('Công nợ khách hàng',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Tổng nợ: ${formatCurrency(_totalDebt)} đ',
                        style: const TextStyle(color: kDanger, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              );

              Widget searchControls(double width) {
                final cappedWidth = math.max(240.0, math.min(width, 580.0));
                return SizedBox(
                  width: cappedWidth,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Tìm tên hoặc SĐT...',
                              prefixIcon: Icon(Icons.search, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) => setState(() => _filter = v.toLowerCase().trim()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton.icon(
                            onPressed: _openAddCustomerDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Thêm mới'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Làm mới'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBadge,
                    const SizedBox(height: 8),
                    searchControls(constraints.maxWidth),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleBadge),
                  const SizedBox(width: 12),
                  searchControls(math.min(constraints.maxWidth * 0.58, 620)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
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
                    : SingleChildScrollView(
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kBorder)),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Tên Khách', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('SĐT', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Dư Nợ (VND)', style: TextStyle(fontWeight: FontWeight.bold)),
                                  numeric: true),
                              DataColumn(label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: data.map((c) {
                              return DataRow(
                                selected: _selectedCustomer?.id == c.id,
                                cells: [
                                  DataCell(
                                    Row(children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: kPrimaryLight,
                                        child: Text(
                                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                              color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    ]),
                                    onTap: () => setState(() => _selectedCustomer = c),
                                  ),
                                  DataCell(
                                    Text(c.phone.isNotEmpty ? c.phone : '-'),
                                    onTap: () => setState(() => _selectedCustomer = c),
                                  ),
                                  DataCell(
                                    Text(
                                      '${formatCurrency(c.debt)} đ',
                                      style: TextStyle(
                                        color: c.debt > 0 ? kDanger : kSuccess,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () => setState(() => _selectedCustomer = c),
                                  ),
                                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: TextButton.icon(
                                        onPressed: () => _editCustomer(c),
                                        icon: const Icon(Icons.edit_outlined, size: 14),
                                        label: const Text('Sửa'),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      mouseCursor: SystemMouseCursors.click,
                                      onPressed: () => _deleteCustomer(c.id),
                                      tooltip: 'Xóa',
                                    ),
                                  ])),
                                ],
                              );
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
  final Set<String> _expandedKeys = {};

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Xóa bản ghi điều chỉnh này?'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Có'),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteDebtLog(widget.custId, logId);
      _load();
      widget.onChanged();
    }
  }

  void _deleteInvoice(int orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Xóa Hóa đơn này?'),
        actions: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Có'),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteOrder(orderId);
      _load();
      widget.onChanged();
    }
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
            else
              ...orderItems.map((item) {
                final map = item as Map<String, dynamic>;
                final productName = map['product_name'] ?? '';
                final variantInfo = map['variant_info'] ?? '';
                final quantity = map['quantity'] ?? 0;
                final price = map['price'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '- $productName ${variantInfo.toString().isNotEmpty ? '($variantInfo)' : ''} x$quantity • ${formatCurrency((price as int) * (quantity as int))} đ',
                    style: const TextStyle(color: kTextSecondary),
                  ),
                );
              }),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (isOrder)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton(
                    onPressed: d == null ? null : () => widget.onEditOrder(d),
                    child: const Text('Sửa đơn'),
                  ),
                )
              else
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton(
                    onPressed: () => _editLog(h),
                    child: const Text('Sửa điều chỉnh'),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                mouseCursor: SystemMouseCursors.click,
                onPressed: isOrder ? () => _deleteInvoice((d?['id'] ?? 0) as int) : () => _deleteLog(h.logId!),
              ),
            ],
          ),
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
                            final key = h.type == 'ORDER'
                                ? 'order_${h.data?['id'] ?? index}'
                                : 'log_${h.logId ?? index}';
                            final isOrder = h.type == 'ORDER';
                            return ExpansionTile(
                              key: ValueKey(key),
                              initiallyExpanded: _expandedKeys.contains(key),
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  if (expanded) {
                                    _expandedKeys.add(key);
                                  } else {
                                    _expandedKeys.remove(key);
                                  }
                                });
                              },
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              childrenPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(formatDate(h.date), overflow: TextOverflow.ellipsis),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      isOrder ? 'Xuất đơn hàng' : 'Điều chỉnh',
                                      style: TextStyle(color: isOrder ? Colors.blue : Colors.green),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(h.desc, overflow: TextOverflow.ellipsis),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      formatSignedCurrency(h.amount),
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: h.amount > 0 ? Colors.red : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: [_buildDetail(h)],
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