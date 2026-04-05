import 'package:flutter/material.dart';
import '../app_pages.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import 'pos_screen.dart';
import 'debt_screen.dart';
import 'areas_screen.dart';
import 'sales_screen.dart';
import 'pending_approval_screen.dart';

export '../app_pages.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppPage _page = AppPage.inventory;
  final GlobalKey<PosScreenState> _posKey = GlobalKey();
  int? _debtPrefilterAreaId;

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

  void _openDebtByArea(int areaId) {
    setState(() {
      _debtPrefilterAreaId = areaId;
      _page = AppPage.debt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _body(),
      bottomNavigationBar: _BottomNavBar(selected: _page, onSelect: _select),
    );
  }

  Widget _body() {
    switch (_page) {
      case AppPage.pos:
        return PosScreen(key: _posKey, inventoryMode: false);
      case AppPage.inventory:
        return const PosScreen(inventoryMode: true, showRightPanel: false);
      case AppPage.stockIn:
        return const PosScreen(inventoryMode: true, showProductArea: false);
      case AppPage.debt:
        return DebtScreen(
          onEditOrder: switchToPosWithOrder,
          initialListAreaFilterId: _debtPrefilterAreaId,
        );
      case AppPage.areas:
        return AreasScreen(onOpenDebtByArea: _openDebtByArea);
      case AppPage.sales:
        return const SalesScreen();
      case AppPage.pendingApproval:
        return PendingApprovalScreen(onChanged: () => setState(() {}));
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  final AppPage selected;
  final ValueChanged<AppPage> onSelect;
  const _BottomNavBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final pendingCount = NotificationService.pendingOrderCount;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _item(Icons.add_box_outlined, Icons.add_box, 'Nhập hàng', AppPage.stockIn),
            _item(Icons.inventory_2_outlined, Icons.inventory_2, 'Kho hàng', AppPage.inventory),
            _item(Icons.point_of_sale_outlined, Icons.point_of_sale, 'Xuất hàng', AppPage.pos),
            _item(Icons.storefront_outlined, Icons.storefront, 'Bán hàng', AppPage.sales),
            _item(Icons.map_outlined, Icons.map, 'Khu vực', AppPage.areas),
            _item(Icons.people_outline, Icons.people, 'Công nợ', AppPage.debt),
            _item(
              Icons.fact_check_outlined,
              Icons.fact_check,
              'Quản lý',
              AppPage.pendingApproval,
              badgeCount: pendingCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, IconData activeIcon, String label, AppPage page, {int badgeCount = 0}) {
    final active = selected == page;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () => onSelect(page),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? kPrimaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? kPrimary : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                active ? activeIcon : icon,
                color: active ? kPrimary : kTextSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: active ? kPrimary : kTextSecondary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              if (badgeCount > 0)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
