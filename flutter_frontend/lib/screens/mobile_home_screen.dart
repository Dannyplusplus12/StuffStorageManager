import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                const Text('Vui lòng chọn vai trò để tiếp tục', style: TextStyle(color: kTextSecondary)),
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
                    label: const Text('Người soạn hàng', style: TextStyle(fontSize: 16)),
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
            ? const SizedBox(height: 180, child: Center(child: Text('Chưa có thông báo')))
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

class _OrdererScreen extends StatefulWidget {
  final VoidCallback onRoleChanged;
  const _OrdererScreen({required this.onRoleChanged});

  @override
  State<_OrdererScreen> createState() => _OrdererScreenState();
}

class _OrdererScreenState extends State<_OrdererScreen> with _NotificationMixin {
  Timer? _pollTimer;
  final GlobalKey<_CreateOrderScreenState> _createOrderKey = GlobalKey<_CreateOrderScreenState>();
  final Map<int, String> _trackedOrders = {};
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
            addNotice('🎉 Đơn #$id đã hoàn thành thành công');
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () async {
              await logout(context);
              widget.onRoleChanged();
            },
            child: const Text('Thoát'),
          ),
        ],
      ),
      body: _CreateOrderScreen(key: _createOrderKey, onDraftCreated: _onDraftCreated),
    );
  }
}

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
  final GlobalKey<_PickerInventoryScreenState> _inventoryKey = GlobalKey<_PickerInventoryScreenState>();
  int _tabIndex = 0;

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

  Future<void> _jumpToInventoryItem(OrderItem item) async {
    if (!mounted) return;
    setState(() => _tabIndex = 1);
    await Future.delayed(const Duration(milliseconds: 80));
    _inventoryKey.currentState?.focusByOrderItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSuccess,
        foregroundColor: Colors.white,
        title: Text(_tabIndex == 0 ? 'Người soạn hàng' : 'Kho hàng'),
        actions: [
          buildNotificationIcon(),
          IconButton(
            onPressed: () {
              if (_tabIndex == 0) {
                _acceptedKey.currentState?.reloadOrders();
              } else {
                _inventoryKey.currentState?.reloadProducts();
              }
            },
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: () async {
              await logout(context);
              widget.onRoleChanged();
            },
            child: const Text('Thoát'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _AcceptedOrdersScreen(
            key: _acceptedKey,
            onConfirmed: (id) => addNotice('✅ Đã xác nhận hoàn thành đơn #$id'),
            onOpenItem: _jumpToInventoryItem,
          ),
          _PickerInventoryScreen(key: _inventoryKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Đơn giao'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Kho hàng'),
        ],
      ),
    );
  }
}

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
  List<String> _customerNameSuggestions = const [];

  int get _total => _cart.fold<int>(0, (s, e) => s + e.price * e.quantity);

  @override
  void initState() {
    super.initState();
    _load();
    _loadCustomerNameSuggestions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerNameSuggestions() async {
    try {
      final customers = await ApiService.getCustomers();
      final names = customers.map((e) => e.name.trim()).where((e) => e.isNotEmpty).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) {
        setState(() => _customerNameSuggestions = names);
      }
    } catch (_) {}
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

  void _openOrdererProductQuickView(Product p) {
    final image = p.image.trim();
    final canLoadNetworkImage = image.startsWith('http://') || image.startsWith('https://');
    final qtys = <int, int>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> openManualInput(Variant v) async {
              final currentQty = qtys[v.id] ?? 0;
              final ctrl = TextEditingController(text: currentQty > 0 ? '$currentQty' : '');
              final value = await showDialog<int>(
                context: sheetContext,
                builder: (_) => AlertDialog(
                  title: const Text('Nhập số lượng'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(hintText: '0 - ${v.stock}'),
                    onSubmitted: (_) {
                      final q = int.tryParse(ctrl.text.trim()) ?? 0;
                      Navigator.pop(sheetContext, q);
                    },
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () {
                        final q = int.tryParse(ctrl.text.trim()) ?? 0;
                        Navigator.pop(sheetContext, q);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              if (value == null) return;
              final normalized = value.clamp(0, v.stock);
              setSheetState(() {
                if (normalized > 0) {
                  qtys[v.id!] = normalized;
                } else {
                  qtys.remove(v.id);
                }
              });
            }

            void changeQty(Variant v, int nextQty) {
              final normalized = nextQty.clamp(0, v.stock);
              setSheetState(() {
                if (normalized > 0) {
                  qtys[v.id!] = normalized;
                } else {
                  qtys.remove(v.id);
                }
              });
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        border: Border.all(color: kBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: canLoadNetworkImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_not_supported_outlined, size: 44, color: kTextSecondary),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.checkroom, size: 48, color: kTextSecondary),
                            ),
                    ),
                    if (image.isNotEmpty && !canLoadNetworkImage)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Ảnh cục bộ: $image', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                      ),
                    const SizedBox(height: 12),
                    const Text('Màu & số lượng', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...p.variants.map((v) {
                      final outOfStock = v.stock <= 0;
                      final currentQty = qtys[v.id] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: outOfStock ? const Color(0xFFFFF1F2) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${v.color} - ${v.size}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${formatCurrency(v.price)} đ', style: const TextStyle(color: kTextSecondary)),
                                  Text(
                                    'Kho: ${v.stock}${outOfStock ? ' (HẾT)' : ''}',
                                    style: TextStyle(color: outOfStock ? kDanger : kTextSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              child: outOfStock
                                  ? const Center(
                                      child: Text('Hết hàng', style: TextStyle(color: kDanger, fontWeight: FontWeight.w600)),
                                    )
                                  : Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: kBorder),
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors.white,
                                      ),
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () => changeQty(v, currentQty - 1),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Icon(Icons.remove, size: 16),
                                            ),
                                          ),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => openManualInput(v),
                                              child: Center(
                                                child: Text(
                                                  '$currentQty',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => changeQty(v, currentQty + 1),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Icon(Icons.add, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (qtys.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng chọn số lượng trước khi thêm vào giỏ')),
                            );
                            return;
                          }

                          setState(() {
                            qtys.forEach((vid, qty) {
                              final v = p.variants.firstWhere((x) => x.id == vid);
                              final idx = _cart.indexWhere((e) => e.variantId == vid);
                              if (idx >= 0) {
                                _cart[idx].quantity += qty;
                              } else {
                                _cart.add(CartItem(
                                  variantId: v.id!,
                                  productName: p.name,
                                  color: v.color,
                                  size: v.size,
                                  price: v.price,
                                  quantity: qty,
                                ));
                              }
                            });
                          });

                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('Gửi đơn'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmSendDialog() async {
    final customerName = _nameCtrl.text.trim().isEmpty ? 'Khách lẻ' : _nameCtrl.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận gửi đơn'),
        content: Text('Bạn xác nhận muốn gửi đơn của $customerName'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gửi đơn'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submitDraft() async {
    if (_cart.isEmpty) return;
    final ok = await _confirmSendDialog();
    if (!ok) return;

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
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  final q = textEditingValue.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<String>.empty();
                  return _customerNameSuggestions.where((name) => name.toLowerCase().contains(q));
                },
                onSelected: (value) {
                  _nameCtrl.text = value;
                },
                fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
                  if (textCtrl.text != _nameCtrl.text) {
                    textCtrl.value = TextEditingValue(
                      text: _nameCtrl.text,
                      selection: TextSelection.collapsed(offset: _nameCtrl.text.length),
                    );
                  }
                  return TextField(
                    controller: textCtrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(hintText: 'Tên khách hàng'),
                    onChanged: (v) => _nameCtrl.text = v,
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
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
                        (p) {
                          final totalStock = p.variants.fold<int>(0, (s, v) => s + v.stock);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _openOrdererProductQuickView(p),
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
                            ),
                          );
                        },
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

class _AcceptedOrdersScreen extends StatefulWidget {
  final void Function(int orderId) onConfirmed;
  final void Function(OrderItem item) onOpenItem;
  const _AcceptedOrdersScreen({super.key, required this.onConfirmed, required this.onOpenItem});

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

  Future<bool> _confirmDeliveryDialog(int orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận hoàn thành'),
        content: Text('Bạn chắc chắn đã hoàn thành đơn #$orderId?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kSuccess, foregroundColor: Colors.white),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _confirm(int orderId) async {
    final ok = await _confirmDeliveryDialog(orderId);
    if (!ok) return;

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
                          (item) {
                            final enough = item.enoughStock ?? true;
                            final stock = item.currentStock;
                            final stockText = stock == null ? '' : ' • Kho: $stock';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => widget.onOpenItem(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: enough ? const Color(0xFFF8FAFC) : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: enough ? kBorder : const Color(0xFFEF9A9A)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.open_in_new,
                                          size: 14, color: enough ? kTextSecondary : kDanger),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${item.productName} (${item.variantInfo}) × ${item.quantity}$stockText',
                                          style: TextStyle(fontSize: 13, color: enough ? kTextPrimary : kDanger),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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
                            label: const Text('Xác nhận đã hoàn thành'),
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

class _PickerInventoryScreen extends StatefulWidget {
  const _PickerInventoryScreen({super.key});

  @override
  State<_PickerInventoryScreen> createState() => _PickerInventoryScreenState();
}

class _PickerInventoryScreenState extends State<_PickerInventoryScreen> {
  bool _loading = true;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();
  List<Product> _products = [];
  int? _highlightProductId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reloadProducts() => _load();

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final products = await ApiService.getProducts(search: _search.trim());
      if (mounted) {
        setState(() => _products = products);
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải kho: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted && !silent) {
      setState(() => _loading = false);
    }
  }

  Future<void> focusByOrderItem(OrderItem item) async {
    _search = item.productName;
    _searchCtrl.text = item.productName;
    await _load();

    Product? target;
    if (item.variantId != null) {
      for (final p in _products) {
        final matched = p.variants.any((v) => v.id == item.variantId);
        if (matched) {
          target = p;
          break;
        }
      }
    }
    if (target == null) {
      for (final p in _products) {
        if (p.name.toLowerCase().contains(item.productName.toLowerCase())) {
          target = p;
          break;
        }
      }
    }

    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy mặt hàng trong kho hiện tại')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _highlightProductId = target!.id);
      _showProductQuickView(target, focusVariantId: item.variantId);
    }
  }

  void _showProductQuickView(Product p, {int? focusVariantId}) {
    Variant? focusVariant;
    if (focusVariantId != null) {
      for (final v in p.variants) {
        if (v.id == focusVariantId) {
          focusVariant = v;
          break;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        final image = p.image.trim();
        final canLoadNetworkImage = image.startsWith('http://') || image.startsWith('https://');

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: kBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: canLoadNetworkImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported_outlined, size: 44, color: kTextSecondary),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.checkroom, size: 48, color: kTextSecondary),
                        ),
                ),
                if (image.isNotEmpty && !canLoadNetworkImage)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Ảnh cục bộ: $image', style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                  ),
                const SizedBox(height: 12),
                const Text('Màu & tồn kho', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...p.variants.map((v) {
                  final isFocus = focusVariant != null && v.id == focusVariant.id;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFocus ? const Color(0xFFE8F5E9) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isFocus ? const Color(0xFF66BB6A) : kBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text('${v.color} - ${v.size}')),
                        Text('Kho: ${v.stock}', style: TextStyle(color: v.stock > 0 ? kTextPrimary : kDanger, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm trong kho...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _search = '';
                          _highlightProductId = null;
                        });
                        _load();
                      },
                    ),
            ),
            onChanged: (v) => setState(() => _search = v),
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
                      final isHighlight = _highlightProductId == p.id;
                      return Card(
                        margin: EdgeInsets.zero,
                        color: isHighlight ? const Color(0xFFFFF8E1) : null,
                        child: ListTile(
                          onTap: () => _showProductQuickView(p),
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









