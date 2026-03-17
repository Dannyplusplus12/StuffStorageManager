import 'package:flutter/material.dart';

import '../models/order.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getPendingOrders();
      if (mounted) {
        setState(() => _orders = list);
      }
      await NotificationService.getPendingOrders();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải đơn chờ duyệt: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Duyệt hóa đơn',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_orders.length} chờ duyệt',
                  style: const TextStyle(color: kDanger, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Làm mới'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? const Center(
                        child: Text('Không có hóa đơn chờ duyệt', style: TextStyle(color: kTextSecondary)),
                      )
                    : ListView.separated(
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final o = _orders[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Đơn #${o.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 10),
                                    Text(formatDate(o.createdAt), style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Khách: ${o.customerName}'),
                                Text('Số lượng: ${o.totalQty} • Tổng: ${formatCurrency(o.totalAmount)} đ'),
                                if (o.items.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...o.items.take(3).map(
                                    (it) => Text(
                                      '- ${it.productName} (${it.variantInfo}) x${it.quantity}',
                                      style: const TextStyle(fontSize: 12, color: kTextSecondary),
                                    ),
                                  ),
                                  if (o.items.length > 3)
                                    Text('... và ${o.items.length - 3} dòng khác',
                                        style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _reject(o),
                                      icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                      label: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _approve(o),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Duyệt'),
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
    );
  }
}
