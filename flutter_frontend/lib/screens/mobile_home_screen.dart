import 'dart:async';

import 'package:flutter/material.dart';

import '../dialogs/product_buy_dialog.dart';
import '../dialogs/staff_pin_dialog.dart';
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
  void _refreshRoot() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (AppModeManager.mode) {
      case AppMode.orderer:
        return _OrdererScreen(onRoleChanged: _refreshRoot);
      case AppMode.picker:
        return _PickerScreen(onRoleChanged: _refreshRoot);
      case AppMode.none:
        return _RoleSelectionScreen(onRoleSelected: _refreshRoot);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// ROLE SELECTION
// ─────────────────────────────────────────────────────────────

class _RoleSelectionScreen extends StatelessWidget {
  final VoidCallback onRoleSelected;
  const _RoleSelectionScreen({required this.onRoleSelected});

  Future<void> _selectRole(BuildContext context, AppMode role) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RolePinDialog(requestedRole: role),
    );
    if (result == true && context.mounted) {
      onRoleSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 64, color: kSidebar),
                const SizedBox(height: 24),
                const Text(
                  'Chọn vai trò',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng chọn vai trò để tiếp tục',
                  style: TextStyle(color: kTextSecondary),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSidebar,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Người soạn đơn', style: TextStyle(fontSize: 16)),
                    onPressed: () => _selectRole(context, AppMode.orderer),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Người giao hàng', style: TextStyle(fontSize: 16)),
                    onPressed: () => _selectRole(context, AppMode.picker),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED NOTIFICATION MIXIN
// ─────────────────────────────────────────────────────────────

mixin _NotificationMixin<T extends StatefulWidget> on State<T> {
  final List<String> notices = [];
  int unreadCount = 0;

  void addNotice(String msg) {
    if (!mounted) return;
    setState(() {
      notices.insert(0, msg);
      unreadCount += 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void openNotices() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
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
      ),
    );
    setState(() => unreadCount = 0);
  }

  Widget buildNotificationIcon() {
    return IconButton(
      onPressed: openNotices,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unreadCount > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$unreadCount', style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> logout(BuildContext ctx) async {
    await AppModeManager.logout();
  }
}

// ─────────────────────────────────────────────────────────────
// ORDERER SCREEN
// ─────────────────────────────────────────────────────────────

class _OrdererScreen extends StatefulWidget {
  final VoidCallback onRoleChanged;
  const _OrdererScreen({required this.onRoleChanged});

  @override
  State<_OrdererScreen> createState() => _OrdererScreenState();
}

class _OrdererScreenState extends State<_OrdererScreen> with _NotificationMixin {
  Timer? _pollTimer;
  final GlobalKey<_CreateOrderScreenState> _createOrderKey = GlobalKey<_CreateOrderScreenState>();
  // orderId → last known status ('pending' | 'accepted')
  final Map<int, String> _trackedOrders = {};
  // orderId → consecutive 404 count (avoid false reject notify due temporary backend/network glitches)
  final Map<int, int> _statusMissCount = {};

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollOrderStatuses());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onDraftCreated(int orderId) {
    setState(() {
      _trackedOrders[orderId] = 'pending';
      _statusMissCount[orderId] = 0;
    });
    addNotice('📤 Đơn #$orderId đã gửi chờ tiếp nhận');
  }

  Future<void> _pollOrderStatuses() async {
    if (_trackedOrders.isEmpty) return;
    final ids = List<int>.from(_trackedOrders.keys);
    for (final id in ids) {
      try {
        final result = await ApiService.getOrderStatus(id);
        if (result == null) {
          // Treat as rejected only after 2 consecutive 404 checks.
          // This prevents false reject notifications when backend is temporarily unavailable.
          final miss = (_statusMissCount[id] ?? 0) + 1;
          _statusMissCount[id] = miss;
          final lastStatus = _trackedOrders[id];
          if (lastStatus == 'pending' && miss >= 2) {
            _trackedOrders.remove(id);
            _statusMissCount.remove(id);
            addNotice('❌ Đơn #$id đã bị từ chối');
          }
        } else {
          _statusMissCount[id] = 0;
          final newStatus = result['status'] as String;
          final lastStatus = _trackedOrders[id];
          if (newStatus == 'accepted' && lastStatus == 'pending') {
            _trackedOrders[id] = 'accepted';
            addNotice('✅ Đơn #$id đã được tiếp nhận, đang soạn hàng');
          } else if (newStatus == 'completed') {
            _trackedOrders.remove(id);
            _statusMissCount.remove(id);
            addNotice('🎉 Đơn #$id đã giao hàng thành công');
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSidebar,
        foregroundColor: Colors.white,
        title: const Text('Người soạn đơn'),
        actions: [
          buildNotificationIcon(),
          IconButton(
            onPressed: () => _createOrderKey.currentState?.reloadProducts(),
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () async {
              await logout(context);
              widget.onRoleChanged();
            },
            child: const Text('Thoát', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: _CreateOrderScreen(key: _createOrderKey, onDraftCreated: _onDraftCreated),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PICKER SCREEN
// ─────────────────────────────────────────────────────────────

class _PickerScreen extends StatefulWidget {
  final VoidCallback onRoleChanged;
  const _PickerScreen({required this.onRoleChanged});

  @override
  State<_PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends State<_PickerScreen> with _NotificationMixin {
  Timer? _pollTimer;
  Set<int> _lastSeenAcceptedIds = {};
  final GlobalKey<_AcceptedOrdersScreenState> _acceptedKey = GlobalKey<_AcceptedOrdersScreenState>();

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollNewOrders());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollNewOrders() async {
    try {
      final orders = await ApiService.getAcceptedOrders();
      final currentIds = orders.map((o) => o.id).toSet();
      final newIds = currentIds.difference(_lastSeenAcceptedIds);
      for (final id in newIds) {
        addNotice('📦 Đơn mới #$id cần soạn hàng');
      }
      _lastSeenAcceptedIds = currentIds;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSuccess,
        foregroundColor: Colors.white,
        title: const Text('Người giao hàng'),
        actions: [
          buildNotificationIcon(),
          IconButton(
            onPressed: () => _acceptedKey.currentState?.reloadOrders(),
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () async {
              await logout(context);
              widget.onRoleChanged();
            },
            child: const Text('Thoát', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: _AcceptedOrdersScreen(
        key: _acceptedKey,
        onConfirmed: (id) => addNotice('✅ Đã xác nhận giao hàng đơn #$id'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CREATE ORDER SCREEN (orderer)
// ─────────────────────────────────────────────────────────────

class _CreateOrderScreen extends StatefulWidget {
  final void Function(int orderId) onDraftCreated;
  const _CreateOrderScreen({super.key, required this.onDraftCreated});

  @override
  State<_CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<_CreateOrderScreen> {
  bool _loading = true;
  bool _submitting = false;
  String _search = '';
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  List<Product> _products = [];
  final List<CartItem> _cart = [];
  Timer? _refreshTimer;

  int get _total => _cart.fold<int>(0, (s, e) => s + e.price * e.quantity);

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> reloadProducts() => _load();

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final products = await ApiService.getProducts(search: _search.trim());
      if (mounted) setState(() => _products = products);
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải sản phẩm: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted && !silent) setState(() => _loading = false);
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
      setState(() {
        _cart.clear();
        _nameCtrl.clear();
        _phoneCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi đơn: $e'), backgroundColor: Colors.red),
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
                  hintText: 'Tìm sản phẩm...',
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                  onPressed: _submitting || _cart.isEmpty ? null : _submitDraft,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Gửi đơn'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACCEPTED ORDERS SCREEN (picker)
// ─────────────────────────────────────────────────────────────

class _AcceptedOrdersScreen extends StatefulWidget {
  final void Function(int orderId) onConfirmed;
  const _AcceptedOrdersScreen({super.key, required this.onConfirmed});

  @override
  State<_AcceptedOrdersScreen> createState() => _AcceptedOrdersScreenState();
}

class _AcceptedOrdersScreenState extends State<_AcceptedOrdersScreen> {
  bool _loading = true;
  List<Order> _orders = [];
  final Set<int> _confirming = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> reloadOrders() => _load();

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final orders = await ApiService.getAcceptedOrders();
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải đơn hàng: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted && !silent) setState(() => _loading = false);
  }

  Future<void> _confirm(int orderId) async {
    setState(() => _confirming.add(orderId));
    try {
      await ApiService.confirmOrder(orderId);
      widget.onConfirmed(orderId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xác nhận: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _confirming.remove(orderId));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: _orders.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: kTextSecondary),
                      SizedBox(height: 12),
                      Text('Không có đơn hàng cần soạn', style: TextStyle(color: kTextSecondary)),
                    ],
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = _orders[i];
                final isConfirming = _confirming.contains(o.id);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Đơn #${o.id} — ${o.customerName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Text(
                              '${formatCurrency(o.totalAmount)} đ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: kDanger),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${formatDate(o.createdAt)} • ${o.totalQty} sản phẩm',
                            style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                        const SizedBox(height: 8),
                        ...o.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• ${item.productName} (${item.variantInfo}) × ${item.quantity}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kSuccess,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: isConfirming ? null : () => _confirm(o.id),
                            icon: isConfirming
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Xác nhận đã giao'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

