import 'package:flutter/material.dart';
import '../app_pages.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import 'pos_screen.dart';
import 'debt_screen.dart';
import 'areas_screen.dart';
import 'sales_screen.dart';
import 'revenue_screen.dart';
import 'pending_approval_screen.dart';

export '../app_pages.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const HomeScreen({
    super.key,
    this.isDarkMode = false,
    this.onToggleTheme,
  });
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
      bottomNavigationBar: _BottomNavBar(
        selected: _page,
        onSelect: _select,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
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
      case AppPage.revenue:
        return const RevenueScreen();
      case AppPage.pendingApproval:
        return PendingApprovalScreen(onChanged: () => setState(() {}));
    }
  }
}

class _BottomNavBar extends StatelessWidget {
  final AppPage selected;
  final ValueChanged<AppPage> onSelect;
  final bool isDarkMode;
  final VoidCallback? onToggleTheme;

  const _BottomNavBar({
    required this.selected,
    required this.onSelect,
    required this.isDarkMode,
    this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final pendingCount = NotificationService.pendingOrderCount;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? colorScheme.surface : Colors.white;
    final navBorder = isDark ? const Color(0xFF263449) : kBorder;
    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: navBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _item(context, Icons.add_box_outlined, Icons.add_box, 'Nhập hàng', AppPage.stockIn),
                  _item(context, Icons.inventory_2_outlined, Icons.inventory_2, 'Kho hàng', AppPage.inventory),
                  _item(context, Icons.point_of_sale_outlined, Icons.point_of_sale, 'Xuất hàng', AppPage.pos),
                  _item(context, Icons.storefront_outlined, Icons.storefront, 'Bán hàng', AppPage.sales),
                  _item(context, Icons.bar_chart_outlined, Icons.bar_chart, 'Doanh thu', AppPage.revenue),
                  _item(context, Icons.map_outlined, Icons.map, 'Khu vực', AppPage.areas),
                  _item(context, Icons.people_outline, Icons.people, 'Công nợ', AppPage.debt),
                  _item(
                    context,
                    Icons.fact_check_outlined,
                    Icons.fact_check,
                    'Quản lý',
                    AppPage.pendingApproval,
                    badgeCount: pendingCount,
                  ),
                ],
              ),
            ),
          ),
          if (onToggleTheme != null) ...[
            const SizedBox(width: 14),
            Container(width: 1, height: 28, color: navBorder),
            const SizedBox(width: 10),
            _themeToggle(isDark),
          ],
        ],
      ),
    );
  }

  Widget _themeToggle(bool isDark) {
    final activeColor = isDark ? const Color(0xFF60A5FA) : kPrimary;
    final activeBg = isDark ? const Color(0xFF1D2B45) : kPrimaryLight;
    final idleColor = isDark ? const Color(0xFF94A3B8) : kTextSecondary;

    return Container(
      margin: const EdgeInsets.only(left: 2),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onToggleTheme,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: activeBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: activeColor.withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              Icon(isDark ? Icons.nightlight_round : Icons.light_mode, color: activeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                isDarkMode ? 'Dark' : 'Light',
                style: TextStyle(
                  color: isDark ? Colors.white : idleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, IconData activeIcon, String label, AppPage page, {int badgeCount = 0}) {
    final active = selected == page;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? (isDark ? const Color(0xFF60A5FA) : kPrimary)
        : (isDark ? const Color(0xFF94A3B8) : kTextSecondary);
    final activeBg = isDark ? const Color(0xFF1A2A44) : kPrimaryLight;
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
            color: active ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                active ? activeIcon : icon,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
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
