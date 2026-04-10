import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils.dart';
import 'edit_log_dialog.dart';
import 'order_detail_dialog.dart';

class CustomerHistoryDialog extends StatefulWidget {
  final int custId;
  final String custName;
  final void Function(Map<String, dynamic>) onEditOrder;
  const CustomerHistoryDialog({super.key, required this.custId, required this.custName, required this.onEditOrder});
  @override
  State<CustomerHistoryDialog> createState() => _CustomerHistoryDialogState();
}

class _CustomerHistoryDialogState extends State<CustomerHistoryDialog> {
  List<HistoryItem> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await ApiService.getCustomerHistory(widget.custId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _addLog() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => EditLogDialog(custId: widget.custId));
    if (ok == true) _load();
  }

  void _editLog(HistoryItem h) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => EditLogDialog(custId: widget.custId, data: {'log_id': h.logId, 'desc': h.desc, 'amount': h.amount, 'date': h.date}));
    if (ok == true) _load();
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
    }
  }

  void _viewOrder(HistoryItem h) {
    if (h.data == null) return;
    final d = h.data!;
    final items = (d['items'] as List? ?? []).map((i) => OrderItem.fromJson(i as Map<String, dynamic>)).toList();
    final o = Order(
      id: d['id'] ?? 0,
      createdAt: d['date'] ?? '',
      customerName: d['customer_name'] ?? d['customer'] ?? '',
      totalAmount: (d['total_money'] ?? 0) as int,
      totalQty: (d['total_qty'] ?? 0) as int,
      status: 'completed',
      items: items,
    );
    showDialog(context: context, builder: (_) => OrderDetailDialog(order: o));
  }

  void _editOrder(HistoryItem h) {
    if (h.data == null) return;
    Navigator.pop(context);
    widget.onEditOrder(h.data!);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Lịch sử — ${widget.custName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Thêm điều chỉnh'), onPressed: _addLog),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const Divider(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? const Center(child: Text('Chưa có lịch sử'))
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columnSpacing: 12,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F8F8)),
                                columns: const [
                                  DataColumn(label: Text('Ngày giờ', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Loại', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Nội dung', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Số tiền', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _items.map((h) {
                                  final isOrder = h.type == 'ORDER';
                                  return DataRow(cells: [
                                    DataCell(Text(formatDate(h.date))),
                                    DataCell(Text(isOrder ? 'Xuất đơn hàng' : 'Điều chỉnh', style: TextStyle(color: isOrder ? Colors.blue : Colors.green))),
                                    DataCell(SizedBox(width: 250, child: Text(h.desc, overflow: TextOverflow.ellipsis))),
                                    DataCell(Text('${formatSignedCurrency(h.amount)} k', style: TextStyle(color: h.amount > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
                                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                      if (isOrder) ...[
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: TextButton(onPressed: () => _viewOrder(h), child: const Text('Xem', style: TextStyle(color: Colors.blue))),
                                        ),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: TextButton(onPressed: () => _editOrder(h), child: const Text('Sửa')),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                          mouseCursor: SystemMouseCursors.click,
                                          onPressed: () => _deleteInvoice(h.data!['id']),
                                        ),
                                      ] else ...[
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: TextButton(onPressed: () => _editLog(h), child: const Text('Sửa')),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                                          mouseCursor: SystemMouseCursors.click,
                                          onPressed: () => _deleteLog(h.logId!),
                                        ),
                                      ],
                                    ])),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
