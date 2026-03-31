import 'package:flutter/material.dart';
import 'dart:async';

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
  Timer? _refreshTimer;

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
      final list = await ApiService.getPendingOrders();
      if (mounted) {
        setState(() => _orders = list);
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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
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
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      '${_orders.length} chờ duyệt',
                      style: const TextStyle(color: kTextSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Làm mới'),
                    ),
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
                                          'Chờ duyệt',
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
                                              child: Text('SL: ${o.totalQty}', style: const TextStyle(color: kTextSecondary)),
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
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Spacer(),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: TextButton.icon(
                                            onPressed: () => _reject(o),
                                            icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                            label: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _approve(o),
                                            icon: const Icon(Icons.check, size: 16),
                                            label: const Text('Duyệt'),
                                            style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
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
      ),
    );
  }
}
