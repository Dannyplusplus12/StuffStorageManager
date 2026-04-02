import 'dart:math';
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';

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
        title: const Text('Chỉnh sửa ngày giờ'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: dtCtrl,
            decoration: const InputDecoration(labelText: 'Ngày giờ', hintText: 'YYYY-MM-DD HH:MM'),
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
              child: const Text('Lưu'),
            ),
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
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final titleSection = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text('Hóa đơn',
                            style:
                                TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text('$_total hóa đơn',
                        style: const TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  );

                  Widget searchControls(double width) {
                    final cappedWidth = max(240.0, min(width, 480.0));
                    return SizedBox(
                      width: cappedWidth,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Tìm theo tên khách...',
                                  prefixIcon: Icon(Icons.search, size: 18),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: OutlinedButton.icon(
                                onPressed: () => _load(1),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Làm mới'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (constraints.maxWidth < 780) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleSection,
                        const SizedBox(height: 8),
                        searchControls(constraints.maxWidth),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 12),
                      searchControls(min(constraints.maxWidth * 0.45, 500)),
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
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              const Text('Không có hóa đơn', style: TextStyle(color: kTextSecondary)),
                            ]),
                          )
                        : ListView.separated(
                            itemCount: data.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final o = data[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorder),
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: Text('Đơn #${o.id}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: kTextPrimary)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          formatDate(o.createdAt),
                                          style: const TextStyle(color: kTextSecondary, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: const Text(
                                          'Hoàn thành',
                                          style: TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Khách: ${o.customerName}',
                                            style: const TextStyle(fontWeight: FontWeight.w500, color: kTextPrimary)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: kBorder),
                                              ),
                                              child: Text('SL: ${o.totalQty}',
                                                  style: const TextStyle(color: kTextSecondary)),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: kBorder),
                                              ),
                                              child: Text('Tổng: ${formatCurrency(o.totalAmount)} đ',
                                                  style: const TextStyle(color: kTextPrimary, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: kBorder),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ...o.items.map(
                                            (it) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                '- ${it.productName} (${it.variantInfo}) x${it.quantity}',
                                                style: const TextStyle(fontSize: 12, color: kTextSecondary),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _editDate(o),
                                            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                                            label: const Text('Sửa ngày'),
                                          ),
                                        ),
                                        const Spacer(),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: TextButton(
                                            onPressed: () => widget.onEditOrder(o.toJson()),
                                            child: const Text('Sửa',
                                                style: TextStyle(
                                                    color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                          mouseCursor: SystemMouseCursors.click,
                                          onPressed: () => _deleteOrder(o.id),
                                          tooltip: 'Xóa',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MouseRegion(
                    cursor: _page > 1 ? SystemMouseCursors.click : SystemMouseCursors.basic,
                    child: OutlinedButton.icon(
                      onPressed: _page > 1 ? () => _load(_page - 1) : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: const Text('Truoc'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Trang $_page / $_totalPages',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  MouseRegion(
                    cursor: _page < _totalPages ? SystemMouseCursors.click : SystemMouseCursors.basic,
                    child: OutlinedButton.icon(
                      onPressed: _page < _totalPages ? () => _load(_page + 1) : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Sau'),
                      iconAlignment: IconAlignment.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
