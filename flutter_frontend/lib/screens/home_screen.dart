import 'package:flutter/material.dart';
import 'dart:io';
import '../app_pages.dart';
import '../theme.dart';
import '../utils/app_mode_manager.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'debt_screen.dart';
import 'orders_screen.dart';

export '../app_pages.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppPage _page = AppPage.dashboard;
  final GlobalKey<PosScreenState> _posKey = GlobalKey();

  void _select(AppPage p) {
    if (_page == AppPage.pos && p != AppPage.pos) {
      _posKey.currentState?.cancelEditing();
    }
    setState(() => _page = p);
  }

  void switchToPosWithOrder(Map<String, dynamic> orderData) {
    setState(() => _page = AppPage.pos);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _posKey.currentState?.loadOrderToEdit(orderData);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Scaffold(
        body: _body(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _page.index,
          onTap: (index) => _select(AppPage.values[index]),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.dashboard_outlined), activeIcon: const Icon(Icons.dashboard), label: 'Tổng quan'),
            BottomNavigationBarItem(icon: const Icon(Icons.point_of_sale_outlined), activeIcon: const Icon(Icons.point_of_sale), label: 'Xuất hàng'),
            BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_outlined), activeIcon: const Icon(Icons.inventory_2), label: 'Kho'),
            BottomNavigationBarItem(icon: const Icon(Icons.people_outline), activeIcon: const Icon(Icons.people), label: 'Công nợ'),
            BottomNavigationBarItem(icon: const Icon(Icons.receipt_long_outlined), activeIcon: const Icon(Icons.receipt_long), label: 'Hóa đơn'),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(selected: _page, onSelect: _select),
            Expanded(child: _body()),
          ],
        ),
      );
    }
  }

  Widget _body() {
    switch (_page) {
      case AppPage.dashboard:
        return DashboardScreen(onNavigate: _select);
      case AppPage.pos:
        return PosScreen(key: _posKey, inventoryMode: false);
      case AppPage.inventory:
        return PosScreen(inventoryMode: true);
      case AppPage.debt:
        return DebtScreen(onEditOrder: switchToPosWithOrder);
      case AppPage.orders:
        return OrdersScreen(onEditOrder: switchToPosWithOrder);
    }
  }
}

class _Sidebar extends StatelessWidget {
  final AppPage selected;
  final ValueChanged<AppPage> onSelect;
  const _Sidebar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: kSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quản lý Kho',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Text(
                  'Store Manager',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 8),
          _item(Icons.dashboard_outlined, Icons.dashboard, 'Tổng quan', AppPage.dashboard),
          _item(Icons.point_of_sale_outlined, Icons.point_of_sale, 'Xuất hàng', AppPage.pos),
          _item(Icons.inventory_2_outlined, Icons.inventory_2, 'Kho hàng', AppPage.inventory),
          _item(Icons.people_outline, Icons.people, 'Công nợ', AppPage.debt),
          _item(Icons.receipt_long_outlined, Icons.receipt_long, 'Hóa đơn', AppPage.orders),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('v1.0.0', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, IconData activeIcon, String label, AppPage page) {
    final active = selected == page;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () => onSelect(page),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? kSidebarActive : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active ? Border(left: BorderSide(color: kPrimary, width: 3)) : null,
          ),
          child: Row(
            children: [
              Icon(
                active ? activeIcon : icon,
                color: active ? kPrimary : const Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF94A3B8),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
