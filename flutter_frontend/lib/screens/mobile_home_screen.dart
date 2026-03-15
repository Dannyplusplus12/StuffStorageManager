import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../dialogs/product_buy_dialog.dart';
import '../dialogs/staff_pin_dialog.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../utils/app_mode_manager.dart';

class MobileHomeScreen extends StatefulWidget {
  const MobileHomeScreen({super.key});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int _selectedIndex = 0;
  Timer? _statusTimer;
  bool _checkingStatus = false;
  final Set<int> _trackingDraftIds = {};
  final List<String> _notices = [];
  int _unreadNoticeCount = 0;

  bool get _isManager => AppModeManager.isManager;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkDraftStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _activateStaffMode() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const StaffPinDialog(),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _logoutStaffMode() async {
    await AppModeManager.logout();
    if (!mounted) return;
    setState(() {
      _selectedIndex = 0;
      _trackingDraftIds.clear();
      _notices.clear();
      _unreadNoticeCount = 0;
    });
  }

  void _onDraftCreated(int orderId) {
    setState(() {
      _trackingDraftIds.add(orderId);
      _notices.insert(0, 'Hóa đơn nháp #$orderId đã gửi chờ duyệt');
      _unreadNoticeCount += 1;
    });
  }

  Future<void> _checkDraftStatus() async {
    if (!_isManager || _trackingDraftIds.isEmpty || _checkingStatus) return;
    _checkingStatus = true;
    try {
      final pending = await ApiService.getPendingOrders();
      final pendingIds = pending.map((e) => e.id).toSet();
      final resolved = _trackingDraftIds.where((id) => !pendingIds.contains(id)).toList();
      if (resolved.isEmpty) return;

      final ordersMap = await ApiService.getOrders(page: 1, limit: 200);
      final orderIds = (ordersMap['data'] as List<Order>).map((o) => o.id).toSet();

      for (final id in resolved) {
        final approved = orderIds.contains(id);
        _trackingDraftIds.remove(id);
        final notice = approved
            ? '✅ Hóa đơn #$id đã được duyệt'
            : '❌ Hóa đơn #$id đã bị từ chối';
        _notices.insert(0, notice);
        _unreadNoticeCount += 1;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
        }
      }

      if (mounted) setState(() {});
    } catch (_) {
    } finally {
      _checkingStatus = false;
    }
  }

  void _openNotices() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final notices = _notices;
        return SafeArea(
          child: notices.isEmpty
              ? const SizedBox(
                  height: 180,
                  child: Center(child: Text('Chưa có thông báo')),
                )
              : ListView.separated(
                  itemCount: notices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: Text(notices[i]),
                  ),
                ),
        );
      },
    );
    setState(() => _unreadNoticeCount = 0);
  }

  List<BottomNavigationBarItem> get _items {
    if (!_isManager) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Kho'),
      ];
    }
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Kho'),
      BottomNavigationBarItem(icon: Icon(Icons.note_add_outlined), label: 'Tạo đơn'),
      BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Công nợ'),
      BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Hóa đơn'),
    ];
  }

  Widget _body() {
    if (!_isManager) return const _MobileInventoryViewerScreen();
    switch (_selectedIndex) {
      case 0:
        return const _MobileInventoryViewerScreen();
      case 1:
        return _MobileStaffCreateDraftScreen(onDraftCreated: _onDraftCreated);
      case 2:
        return const _MobileDebtViewerScreen();
      case 3:
        return const _MobileOrderHistoryScreen();
      default:
        return const _MobileInventoryViewerScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = _items.length;
    if (_selectedIndex >= itemCount) {
      _selectedIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSidebar,
        foregroundColor: Colors.white,
        title: Text(_isManager ? 'Mobile Staff' : 'Mobile Viewer'),
        actions: [
          if (_isManager)
            IconButton(
              onPressed: _openNotices,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (_unreadNoticeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_unreadNoticeCount',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: _isManager
                  ? TextButton(
                      onPressed: _logoutStaffMode,
                      child: const Text('Thoát staff', style: TextStyle(color: Colors.white)),
                    )
                  : TextButton(
                      onPressed: _activateStaffMode,
                      child: const Text('Kích hoạt staff', style: TextStyle(color: kPrimaryLight)),
                    ),
            ),
          )
        ],
      ),
      body: _body(),
      bottomNavigationBar: _isManager
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: _items,
            )
          : null,
    );
  }
}

class _MobileInventoryViewerScreen extends StatefulWidget {
  const _MobileInventoryViewerScreen();

  @override
  State<_MobileInventoryViewerScreen> createState() => _MobileInventoryViewerScreenState();
}

class _MobileInventoryViewerScreenState extends State<_MobileInventoryViewerScreen> {
  bool _loading = true;
  String _search = '';
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await ApiService.getProducts(search: _search.trim());
      if (mounted) setState(() => _products = products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải kho: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm sản phẩm...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => _search = v,
            onSubmitted: (_) => _load(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = _products[i];
                      final totalStock = p.variants.fold<int>(0, (s, v) => s + v.stock);
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ExpansionTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Tổng tồn: $totalStock'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: totalStock > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              totalStock > 0 ? 'Còn hàng' : 'Hết hàng',
                              style: TextStyle(
                                fontSize: 12,
                                color: totalStock > 0 ? kSuccess : kDanger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          children: p.variants
                              .map(
                                (v) => ListTile(
                                  dense: true,
                                  title: Text('${v.color} - ${v.size}'),
                                  subtitle: Text('Giá: ${formatCurrency(v.price)} đ'),
                                  trailing: Text(
                                    'Kho: ${v.stock}',
                                    style: TextStyle(
                                      color: v.stock > 0 ? kTextPrimary : kDanger,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _MobileStaffCreateDraftScreen extends StatefulWidget {
  final void Function(int orderId) onDraftCreated;
  const _MobileStaffCreateDraftScreen({required this.onDraftCreated});

  @override
  State<_MobileStaffCreateDraftScreen> createState() => _MobileStaffCreateDraftScreenState();
}

class _MobileStaffCreateDraftScreenState extends State<_MobileStaffCreateDraftScreen> {
  bool _loading = true;
  bool _submitting = false;
  String _search = '';
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  List<Product> _products = [];
  final List<CartItem> _cart = [];

  int get _total => _cart.fold<int>(0, (s, e) => s + e.price * e.quantity);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await ApiService.getProducts(search: _search.trim());
      if (mounted) setState(() => _products = products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải sản phẩm: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickProduct(Product product) async {
    final result = await showDialog<List<CartItem>>(
      context: context,
      builder: (_) => ProductBuyDialog(product: product),
    );
    if (result == null || result.isEmpty) return;
    setState(() {
      for (final add in result) {
        final idx = _cart.indexWhere((e) => e.variantId == add.variantId);
        if (idx >= 0) {
          _cart[idx].quantity += add.quantity;
        } else {
          _cart.add(add);
        }
      }
    });
  }

  Future<void> _submitDraft() async {
    if (_cart.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final res = await ApiService.checkoutDraft(
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        cart: _cart,
      );
      final orderId = (res['order_id'] ?? 0) as int;
      widget.onDraftCreated(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi hóa đơn nháp #$orderId chờ duyệt')),
        );
      }
      setState(() {
        _cart.clear();
        _nameCtrl.clear();
        _phoneCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi nháp: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Tên khách hàng'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Số điện thoại'),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm sản phẩm để thêm...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => _search = v,
                onSubmitted: (_) => _load(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Sản phẩm', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ..._products.map(
                      (p) => ListTile(
                        title: Text(p.name),
                        subtitle: Text('Giá: ${p.priceRange} k'),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _pickProduct(p),
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Giỏ hàng (${_cart.length} mẫu)', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (_cart.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Chưa có sản phẩm nào trong giỏ'),
                      )
                    else
                      ..._cart.map(
                        (c) => ListTile(
                          title: Text('${c.productName} (${c.color}-${c.size})'),
                          subtitle: Text('${formatCurrency(c.price)} đ x ${c.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => _cart.remove(c)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tổng: ${formatCurrency(_total)} đ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submitDraft,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Gửi duyệt'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileDebtViewerScreen extends StatefulWidget {
  const _MobileDebtViewerScreen();

  @override
  State<_MobileDebtViewerScreen> createState() => _MobileDebtViewerScreenState();
}

class _MobileDebtViewerScreenState extends State<_MobileDebtViewerScreen> {
  bool _loading = true;
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final customers = await ApiService.getCustomers();
      if (mounted) setState(() => _customers = customers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải công nợ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = _customers.fold<int>(0, (s, e) => s + e.debt);
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Tổng dư nợ'),
                    trailing: Text(
                      '${formatCurrency(totalDebt)} đ',
                      style: const TextStyle(color: kDanger, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._customers.map(
                  (c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(c.name),
                      subtitle: Text(c.phone.isEmpty ? 'Không có SĐT' : c.phone),
                      trailing: Text(
                        '${formatCurrency(c.debt)} đ',
                        style: const TextStyle(color: kDanger, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}

class _MobileOrderHistoryScreen extends StatefulWidget {
  const _MobileOrderHistoryScreen();

  @override
  State<_MobileOrderHistoryScreen> createState() => _MobileOrderHistoryScreenState();
}

class _MobileOrderHistoryScreenState extends State<_MobileOrderHistoryScreen> {
  bool _loading = true;
  List<Order> _orders = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int page) async {
    setState(() => _loading = true);
    try {
      final ordersMap = await ApiService.getOrders(page: page, limit: 20);
      final allOrders = (ordersMap['data'] as List<Order>);

      Set<int> pendingIds = <int>{};
      try {
        final pending = await ApiService.getPendingOrders();
        pendingIds = pending.map((e) => e.id).toSet();
      } catch (_) {
        // Backend pending endpoint may be unavailable in some environments.
        // Keep showing order history from /orders instead of failing the screen.
      }

      final approvedHistory = pendingIds.isEmpty
          ? allOrders
          : allOrders.where((o) => !pendingIds.contains(o.id)).toList();
      final total = (ordersMap['total'] ?? 0) as int;
      final currentPage = (ordersMap['page'] ?? page) as int;
      if (mounted) {
        setState(() {
          _orders = approvedHistory;
          _total = total;
          _page = currentPage;
          _totalPages = max(1, (total / 20).ceil());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải hóa đơn: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _orderCard(Order o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(o.customerName),
        subtitle: Text('${formatDate(o.createdAt)} • SL: ${o.totalQty}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${formatCurrency(o.totalAmount)} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              'Đã duyệt',
              style: TextStyle(
                fontSize: 11,
                color: kSuccess,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => _load(_page),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Lịch sử gần đây', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('$_total hóa đơn', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Card(child: ListTile(title: Text('Không có hóa đơn đã duyệt ở trang này')))
          else
            ..._orders.map(_orderCard),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _page > 1 ? () => _load(_page - 1) : null,
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Trước'),
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

