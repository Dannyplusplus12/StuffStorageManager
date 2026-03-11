import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/add_customer_panel.dart';
import '../dialogs/customer_history_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await ApiService.getCustomers();
      if (mounted) setState(() => _customers = c);
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Có'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteCustomer(id);
      _load();
    }
  }

  void _openHistory(Customer c) async {
    await showDialog(
      context: context,
      builder: (_) => CustomerHistoryDialog(
          custId: c.id, custName: c.name, onEditOrder: widget.onEditOrder),
    );
    _load();
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
                keyboardType: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiService.updateCustomer(c.id,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    debt: int.tryParse(debtCtrl.text.replaceAll('.', '')) ?? c.debt);
                nav.pop(true);
              } catch (e) {
                messenger.showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tableArea()),
        Container(
          width: 380,
          decoration: const BoxDecoration(
              color: Colors.white, border: Border(left: BorderSide(color: kBorder))),
          child: AddCustomerPanel(onAdded: _load),
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
          Row(children: [
            const Text('Công nợ khách hàng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration:
                  BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
              child: Text('Tổng nợ: ${formatCurrency(_totalDebt)} đ',
                  style: const TextStyle(color: kDanger, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            SizedBox(
              width: 280, height: 38,
              child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Tìm tên hoặc SĐT...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (v) => setState(() => _filter = v.toLowerCase().trim()),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Làm mới'),
              ),
            ),
          ]),
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
                              DataColumn(
                                  label: Text('Tên Khách', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('SĐT', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Dư Nợ (VND)', style: TextStyle(fontWeight: FontWeight.bold)),
                                  numeric: true),
                              DataColumn(
                                  label: Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: data.map((c) {
                              return DataRow(cells: [
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
                                  onTap: () => _editCustomer(c),
                                ),
                                DataCell(Text(c.phone.isNotEmpty ? c.phone : '-'),
                                    onTap: () => _editCustomer(c)),
                                DataCell(
                                  Text('${formatCurrency(c.debt)} d',
                                      style: TextStyle(
                                          color: c.debt > 0 ? kDanger : kSuccess,
                                          fontWeight: FontWeight.bold)),
                                  onTap: () => _editCustomer(c),
                                ),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  TextButton.icon(
                                    onPressed: () => _openHistory(c),
                                    icon: const Icon(Icons.history, size: 14),
                                    label: const Text('Lịch sử'),
                                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    onPressed: () => _deleteCustomer(c.id),
                                    tooltip: 'Xoa',
                                  ),
                                ])),
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