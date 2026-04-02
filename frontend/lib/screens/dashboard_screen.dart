import 'package:flutter/material.dart';
import '../app_pages.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(AppPage) onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  int _totalProducts = 0;
  int _totalCustomers = 0;
  int _totalDebt = 0;
  int _totalOrders = 0;
  List<Order> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getDashboardStats();
      if (mounted) {
        setState(() {
          _totalProducts = s['totalProducts'] as int;
          _totalCustomers = s['totalCustomers'] as int;
          _totalDebt = s['totalDebt'] as int;
          _totalOrders = s['totalOrders'] as int;
          _recentOrders = s['recentOrders'] as List<Order>;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tổng quan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextPrimary),
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
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            _statsRow(),
            const SizedBox(height: 24),
            _recentOrdersCard(),
          ],
        ],
      ),
    );
  }

  Widget _statsRow() {
    return LayoutBuilder(builder: (ctx, c) {
      final w = (c.maxWidth - 48) / 4;
      return Row(
        children: [
          _StatCard(
            width: w,
            icon: Icons.inventory_2,
            iconColor: const Color(0xFF6366F1),
            iconBg: const Color(0xFFEEF2FF),
            label: 'Sản phẩm',
            value: '$_totalProducts',
            sub: 'Loại sản phẩm',
            onTap: () => widget.onNavigate(AppPage.inventory),
          ),
          const SizedBox(width: 16),
          _StatCard(
            width: w,
            icon: Icons.people,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFD1FAE5),
            label: 'Khách hàng',
            value: '$_totalCustomers',
            sub: 'Đang theo dõi',
            onTap: () => widget.onNavigate(AppPage.debt),
          ),
          const SizedBox(width: 16),
          _StatCard(
            width: w,
            icon: Icons.account_balance_wallet,
            iconColor: kDanger,
            iconBg: const Color(0xFFFEE2E2),
            label: 'Tổng dư nợ',
            value: '${formatCurrency(_totalDebt)} đ',
            sub: 'Tổng công nợ khách',
            onTap: () => widget.onNavigate(AppPage.debt),
          ),
          const SizedBox(width: 16),
          _StatCard(
            width: w,
            icon: Icons.receipt_long,
            iconColor: kPrimary,
            iconBg: kPrimaryLight,
            label: 'Đơn hàng',
            value: '$_totalOrders',
            sub: 'Tổng hóa đơn',
            onTap: () => widget.onNavigate(AppPage.pendingApproval),
          ),
        ],
      );
    });
  }

  Widget _recentOrdersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Đơn hàng gần đây',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: TextButton(
                    onPressed: () => widget.onNavigate(AppPage.pendingApproval),
                    child: const Text('Xem tất cả →'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_recentOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Chưa có đơn hàng nào',
                  style: TextStyle(color: kTextSecondary),
                ),
              ),
            )
          else
            ...(_recentOrders.map((o) => _orderRow(o))),
        ],
      ),
    );
  }

  Widget _orderRow(Order o) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt, color: kPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn #${o.id}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  o.customerName,
                  style: const TextStyle(color: kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatCurrency(o.totalAmount)} đ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kPrimary,
                  fontSize: 13,
                ),
              ),
              Text(
                formatDate(o.createdAt),
                style: const TextStyle(color: kTextSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String sub;
  final VoidCallback? onTap;

  const _StatCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(20),
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
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: kTextSecondary),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 11, color: kTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
