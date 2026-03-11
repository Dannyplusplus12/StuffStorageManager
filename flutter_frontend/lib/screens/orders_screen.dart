import 'dart:math';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../dialogs/order_detail_dialog.dart';

class OrdersScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>) onEditOrder;
  const OrdersScreen({super.key, required this.onEditOrder});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int page) async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getOrders(page: page);
      final data = r['data'] as List<Order>;
      final total = r['total'] as int;
      if (mounted) {
        setState(() {
          _orders = data;
          _page = page;
          _total = total;
          _totalPages = max(1, (total / 20).ceil());
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

  Future<void> _deleteOrder(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa hóa đơn này?\n(Kho và công nợ sẽ được hoàn tác)'),
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
      try {
        await ApiService.deleteOrder(id);
        _load(_page);
      } catch (e) {
        _snack('$e', Colors.red);
      }
    }
  }

  void _editDate(Order o) async {
    final dtCtrl = TextEditingController(text: o.createdAt);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chinh sua ngay gio'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: dtCtrl,
            decoration: const InputDecoration(labelText: 'Ngày giờ', hintText: 'YYYY-MM-DD HH:MM'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huy')),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ApiService.updateOrderDate(o.id, dtCtrl.text.trim());
                nav.pop(true);
              } catch (e) {
                messenger.showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Luu'),
          ),
        ],
      ),
    );
    if (saved == true) _load(_page);
  }

  List<Order> get _filtered => _search.isEmpty
      ? _orders
      : _orders.where((o) => o.customerName.toLowerCase().contains(_search.toLowerCase()) ||
          _removeAccents(o.customerName.toLowerCase()).contains(_removeAccents(_search.toLowerCase()))).toList();

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

  @override
  Widget build(BuildContext context) {
    final data = _filtered;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Hoa don',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration:
                  BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(12)),
              child: Text('$_total hóa đơn',
                  style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            SizedBox(
              width: 260, height: 38,
              child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Tim theo ten khach...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _load(1),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Lam moi'),
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
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text('Khong co hoa don', style: TextStyle(color: kTextSecondary)),
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
                                  label: Text('Ngày giờ', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Khách hàng', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Tổng tiền', style: TextStyle(fontWeight: FontWeight.bold)),
                                  numeric: true),
                              DataColumn(
                                  label: Text('SL', style: TextStyle(fontWeight: FontWeight.bold)),
                                  numeric: true),
                              DataColumn(
                                  label:
                                      Text('Thao tác', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: data.map((o) {
                              return DataRow(cells: [
                                DataCell(
                                  Row(children: [
                                    const Icon(Icons.schedule, size: 14, color: kTextSecondary),
                                    const SizedBox(width: 4),
                                    Text(formatDate(o.createdAt), style: const TextStyle(fontSize: 13)),
                                  ]),
                                  onTap: () => _editDate(o),
                                ),
                                DataCell(Text(o.customerName,
                                    style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text('${formatCurrency(o.totalAmount)} đ',
                                    style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F9FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('${o.totalQty}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                )),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  TextButton(
                                    onPressed: () => showDialog(
                                        context: context, builder: (_) => OrderDetailDialog(order: o)),
                                    child: const Text('Xem', style: TextStyle(color: Colors.blue)),
                                  ),
                                  TextButton(
                                    onPressed: () => widget.onEditOrder(o.toJson()),
                                    child: const Text('Sua',
                                        style: TextStyle(
                                            color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    onPressed: () => _deleteOrder(o.id),
                                    tooltip: 'Xoa',
                                  ),
                                ])),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _page > 1 ? () => _load(_page - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Truoc'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Trang $_page / $_totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                onPressed: _page < _totalPages ? () => _load(_page + 1) : null,
                icon: const Icon(Icons.chevron_right, size: 16),
                label: const Text('Sau'),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
