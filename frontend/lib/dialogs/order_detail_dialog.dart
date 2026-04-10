import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils.dart';
import '../theme.dart';

class OrderDetailDialog extends StatelessWidget {
  final Order order;
  const OrderDetailDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    int totalVerify = 0;
    for (final i in order.items) {
      totalVerify += i.quantity * i.price;
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chi tiết đơn #${order.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Khách hàng: ${order.customerName}'),
              Text('Ngày mua: ${order.createdAt}'),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Phân loại', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SL', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Thành tiền', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: order.items.map((i) {
                        return DataRow(cells: [
                          DataCell(Text(i.productName)),
                          DataCell(Text(i.variantInfo)),
                          DataCell(Text('${i.quantity}')),
                          DataCell(Text(formatCurrency(i.quantity * i.price))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Tổng cộng: ${formatCurrency(totalVerify)} k', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimary)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
