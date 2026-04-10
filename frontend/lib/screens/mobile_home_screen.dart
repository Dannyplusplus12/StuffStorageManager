import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/mobile_notification_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../utils/app_mode_manager.dart';

({String color, String size}) _splitVariantInfo(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return (color: 'Khác', size: '-');
  if (!value.contains('-')) return (color: value, size: '-');
  final parts = value.split('-');
  final color = parts.first.trim().isEmpty ? 'Khác' : parts.first.trim();
  final size = parts.sublist(1).join('-').trim().isEmpty ? '-' : parts.sublist(1).join('-').trim();
  return (color: color, size: size);
}

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

class _RoleSelectionScreen extends StatefulWidget {
  final VoidCallback onRoleSelected;
  const _RoleSelectionScreen({required this.onRoleSelected});

  @override
  State<_RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<_RoleSelectionScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginByPin() async {
    if (_pinCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nhập mã PIN');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final pin = _pinCtrl.text.trim();
    final roles = ['orderer', 'picker', 'manager'];
    String? lastErr;
    for (final role in roles) {
      try {
        final login = await ApiService.loginByPin(pin: pin, requestedRole: role);
        final mode = role == 'picker' ? AppMode.picker : AppMode.orderer;
        await AppModeManager.setSession(
          mode,
          employeeId: (login['id'] ?? 0) as int,
          employeeName: (login['name'] ?? '').toString(),
          employeeRole: role,
        );
        if (!mounted) return;
        widget.onRoleSelected();
        return;
      } catch (e) {
        lastErr = e.toString();
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      final msg = (lastErr ?? '').toLowerCase();
      if (msg.contains('failed host lookup') || msg.contains('connection') || msg.contains('timed out') || msg.contains('socket')) {
        _error = 'Không kết nối được server';
      } else {
        _error = 'PIN không hợp lệ';
      }
    });
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
                const Text('Nhập PIN để vào đúng giao diện theo vai trò', style: TextStyle(color: kTextSecondary)),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã PIN',
                    errorText: _error,
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) => _loading ? null : _loginByPin(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSidebar,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.pin_outlined),
                    label: const Text('Vào app', style: TextStyle(fontSize: 16)),
                    onPressed: _loading ? null : _loginByPin,
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
    unawaited(MobileNotificationService.show('Thông báo đơn hàng', msg));
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
  final GlobalKey<_OrdererDebtScreenState> _debtKey = GlobalKey<_OrdererDebtScreenState>();
  final Map<int, String> _trackedOrders = {};
  final Map<int, int> _statusMissCount = {};
  int _tabIndex = 0;

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
    final isManager = AppModeManager.isManager;
    setState(() {
      _trackedOrders[orderId] = isManager ? 'approved' : 'pending';
      _statusMissCount[orderId] = 0;
    });
    if (isManager) {
      addNotice('📤 Đơn #$orderId đã gửi thẳng cho picker');
    } else {
      addNotice('📤 Đơn #$orderId đã gửi chờ staff tiếp nhận');
    }
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
          } else if (AppModeManager.isManager && miss >= 2) {
            _trackedOrders.remove(id);
            _statusMissCount.remove(id);
            addNotice('ℹ️ Đơn #$id không còn trong hệ thống');
          }
        } else {
          _statusMissCount[id] = 0;
          final newStatus = result['status'] as String;
          final lastStatus = _trackedOrders[id];
          if ((newStatus == 'approved' || newStatus == 'accepted' || newStatus == 'assigned') &&
              lastStatus == 'pending') {
            _trackedOrders[id] = newStatus;
            addNotice('✅ Đơn #$id đã được tiếp nhận, đang soạn hàng');
          } else if (newStatus == 'assigned' && lastStatus == 'approved') {
            _trackedOrders[id] = 'assigned';
            addNotice('✅ Picker đã nhận đơn #$id');
          } else if (newStatus == 'completed') {
            _trackedOrders.remove(id);
            _statusMissCount.remove(id);
            final pickerNote = (result['picker_note'] ?? '').toString().trim();
            if (pickerNote.isNotEmpty) {
              addNotice('⚠️ Đơn #$id đã hoàn thành một phần: $pickerNote');
            } else {
              addNotice('🎉 Đơn #$id đã hoàn thành thành công');
            }
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
        title: Text(_tabIndex == 0 ? 'Order' : 'Công nợ khách hàng'),
        actions: [
          buildNotificationIcon(),
          IconButton(
            onPressed: () {
              if (_tabIndex == 0) {
                _createOrderKey.currentState?.reloadProducts();
              } else {
                _debtKey.currentState?.reload();
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
          _CreateOrderScreen(key: _createOrderKey, onDraftCreated: _onDraftCreated),
          _OrdererDebtScreen(key: _debtKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.note_add_outlined), label: 'Soạn đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Công nợ'),
        ],
      ),
    );
  }
}

class _OrdererDebtScreen extends StatefulWidget {
  const _OrdererDebtScreen({super.key});

  @override
  State<_OrdererDebtScreen> createState() => _OrdererDebtScreenState();
}

class _OrdererDebtScreenState extends State<_OrdererDebtScreen> {
  bool _loading = true;
  String _search = '';
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getCustomers();
      if (mounted) {
        setState(() {
          _customers = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải công nợ: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Customer> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) => c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q)).toList();
  }

  Future<void> _openCustomerHistory(Customer c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OrdererCustomerHistorySheet(
        customer: c,
        onChanged: reload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Tìm tên khách/SĐT...', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: reload,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          onTap: () => _openCustomerHistory(c),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${c.phone.isEmpty ? '-' : c.phone} • ${c.areaName.isEmpty ? 'Chưa rõ khu vực' : c.areaName}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${formatCurrency(c.debt)} k', style: const TextStyle(color: kDanger, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
                            ],
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

class _OrdererCustomerHistorySheet extends StatefulWidget {
  final Customer customer;
  final Future<void> Function() onChanged;
  const _OrdererCustomerHistorySheet({required this.customer, required this.onChanged});

  @override
  State<_OrdererCustomerHistorySheet> createState() => _OrdererCustomerHistorySheetState();
}

class _OrdererCustomerHistorySheetState extends State<_OrdererCustomerHistorySheet> {
  bool _loading = true;
  List<HistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getCustomerHistory(widget.customer.id);
      if (mounted) setState(() => _items = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải lịch sử: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _collectMoney() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'Trả tiền');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thu tiền'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nhập số tiền thu từ khách'),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'VD: 50000'),
            ),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: 'Ghi chú')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (ok != true) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    try {
      await ApiService.createDebtLog(widget.customer.id, changeAmount: -amount, note: noteCtrl.text.trim().isEmpty ? 'Trả tiền' : noteCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thu tiền thành công'), backgroundColor: Colors.green),
        );
      }
      await _load();
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi thu tiền: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _historyTile(HistoryItem h) {
    final isOrder = h.type == 'ORDER';
    final amountTxt = '${h.amount >= 0 ? '+' : ''}${formatCurrency(h.amount)} k';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(h.date, style: const TextStyle(fontSize: 12, color: kTextSecondary))),
              Text(amountTxt, style: TextStyle(color: h.amount >= 0 ? kDanger : kSuccess, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(h.desc, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (isOrder && (h.data?['items'] as List?) != null) ...[
            const SizedBox(height: 6),
            ...(h.data!['items'] as List)
                .map((e) => e as Map<String, dynamic>)
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('- ${e['product_name']} (${e['variant_info']}) x${e['quantity']}', style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                    )),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Nợ hiện tại: ${formatCurrency(widget.customer.debt)} k', style: const TextStyle(color: kDanger, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _collectMoney,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Thu tiền'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('Chưa có lịch sử'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _historyTile(_items[i]),
                        ),
            ),
          ],
        ),
      ),
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
  static const _seenAcceptedKey = 'picker_seen_accepted_order_ids';
  Timer? _pollTimer;
  Set<int> _lastSeenAcceptedIds = {};
  final GlobalKey<_ApprovedOrdersScreenState> _approvedKey = GlobalKey<_ApprovedOrdersScreenState>();
  final GlobalKey<_AcceptedOrdersScreenState> _assignedKey = GlobalKey<_AcceptedOrdersScreenState>();
  final GlobalKey<_PickerInventoryScreenState> _inventoryKey = GlobalKey<_PickerInventoryScreenState>();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initSeenOrdersAndPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSeenOrdersAndPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenData = prefs.containsKey(_seenAcceptedKey);

    if (hasSeenData) {
      final saved = prefs.getStringList(_seenAcceptedKey) ?? const [];
      _lastSeenAcceptedIds = saved.map((e) => int.tryParse(e)).whereType<int>().toSet();
    } else {
      try {
        final orders = await ApiService.getApprovedOrders();
        _lastSeenAcceptedIds = orders.map((o) => o.id).toSet();
        await prefs.setStringList(
          _seenAcceptedKey,
          _lastSeenAcceptedIds.map((e) => e.toString()).toList(),
        );
      } catch (_) {}
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollNewOrders());
    _pollNewOrders();
  }

  Future<void> _pollNewOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orders = await ApiService.getApprovedOrders();
      final currentIds = orders.map((o) => o.id).toSet();
      final newIds = currentIds.difference(_lastSeenAcceptedIds);
      if (newIds.isNotEmpty) {
        for (final id in newIds) {
          addNotice('📦 Đơn mới #$id cần soạn hàng');
        }
        _approvedKey.currentState?.reloadOrders();
        _assignedKey.currentState?.reloadOrders();
      }
      _lastSeenAcceptedIds = currentIds;
      await prefs.setStringList(
        _seenAcceptedKey,
        _lastSeenAcceptedIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<void> _jumpToInventoryItem(OrderItem item) async {
    if (!mounted) return;
    setState(() => _tabIndex = 2);
    await Future.delayed(const Duration(milliseconds: 80));
    _inventoryKey.currentState?.focusByOrderItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSuccess,
        foregroundColor: Colors.white,
        title: Text(_tabIndex == 0 ? 'Nhận đơn' : (_tabIndex == 1 ? 'Giao đơn' : 'Kho hàng')),
        actions: [
          buildNotificationIcon(),
          IconButton(
            onPressed: () {
              if (_tabIndex == 0) {
                _approvedKey.currentState?.reloadOrders();
              } else if (_tabIndex == 1) {
                _assignedKey.currentState?.reloadOrders();
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
          _ApprovedOrdersScreen(
            key: _approvedKey,
            onReceived: (id) {
              addNotice('📥 Đã nhận đơn #$id');
              _assignedKey.currentState?.reloadOrders();
            },
          ),
          _AcceptedOrdersScreen(
            key: _assignedKey,
            onConfirmed: (id, note) {
              if (note != null && note.trim().isNotEmpty) {
                addNotice('⚠️ Đơn #$id hoàn thành một phần: $note');
              } else {
                addNotice('✅ Đã giao xong đơn #$id');
              }
              _approvedKey.currentState?.reloadOrders();
            },
            onOpenItem: _jumpToInventoryItem,
          ),
          _PickerInventoryScreen(key: _inventoryKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_outlined), label: 'Nhận đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Giao đơn'),
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
  Timer? _searchDebounce;
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
    _searchDebounce?.cancel();
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

  String _selectedSummaryForProduct(Product p) {
    final selected = _cart
        .where((c) => p.variants.any((v) => v.id == c.variantId) && c.quantity > 0)
        .toList();
    if (selected.isEmpty) return '';
    return selected.map((c) => '${c.size}/${c.color} x ${c.quantity}').join('\n');
  }

  Future<void> _openCartReviewPopup() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> openManualInput(CartItem item) async {
              final ctrl = TextEditingController(text: '${item.quantity}');
              final value = await showDialog<int>(
                context: sheetContext,
                builder: (_) => AlertDialog(
                  title: const Text('Nhập số lượng'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(hintText: '>= 0'),
                    onSubmitted: (_) => Navigator.pop(sheetContext, int.tryParse(ctrl.text.trim()) ?? 0),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, int.tryParse(ctrl.text.trim()) ?? 0),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              if (value == null) return;
              setState(() {
                final normalized = value < 0 ? 0 : value;
                if (normalized == 0) {
                  _cart.remove(item);
                } else {
                  item.quantity = normalized;
                }
              });
              setSheetState(() {});
            }

            void changeQty(CartItem item, int nextQty) {
              setState(() {
                if (nextQty <= 0) {
                  _cart.remove(item);
                } else {
                  item.quantity = nextQty;
                }
              });
              setSheetState(() {});
            }

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Đơn hiện tại',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Text(
                        '${_cart.length} mẫu • Tổng ${formatCurrency(_total)} k',
                        style: const TextStyle(color: kTextSecondary, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: _cart.isEmpty
                          ? const Center(child: Text('Chưa có sản phẩm nào trong giỏ'))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                children: () {
                                  final byModel = <String, List<CartItem>>{};
                                  for (final item in _cart) {
                                    byModel.putIfAbsent(item.productName, () => []).add(item);
                                  }

                                  final widgets = <Widget>[];
                                  final modelNames = byModel.keys.toList()
                                    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  for (final modelName in modelNames) {
                                    final modelItems = byModel[modelName] ?? const <CartItem>[];
                                    final byColor = <String, List<CartItem>>{};
                                    for (final item in modelItems) {
                                      byColor.putIfAbsent(item.color, () => []).add(item);
                                    }
                                    final modelQty = modelItems.fold<int>(0, (s, x) => s + x.quantity);
                                    final modelMoney = modelItems.fold<int>(0, (s, x) => s + (x.quantity * x.price));

                                    widgets.add(
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: kBorder),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(modelName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                                                ),
                                                Text(
                                                  '$modelQty cái • ${formatCurrency(modelMoney)} k',
                                                  style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ...((() {
                                              final colors = byColor.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                              return colors;
                                            })()).map((colorName) {
                                              final colorItems = byColor[colorName] ?? const <CartItem>[];
                                              final totalQty = colorItems.fold<int>(0, (s, x) => s + x.quantity);
                                              final colorMoney = colorItems.fold<int>(0, (s, x) => s + (x.quantity * x.price));
                                              final sortedItems = [...colorItems]
                                                ..sort((a, b) => a.size.toLowerCase().compareTo(b.size.toLowerCase()));
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF8FAFC),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: kBorder),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Màu $colorName • $totalQty cái • ${formatCurrency(colorMoney)} k',
                                                      style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimary),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ...sortedItems.map((item) {
                                                return Padding(
                                                        padding: const EdgeInsets.only(bottom: 6),
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Expanded(
                                                              child: Padding(
                                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                                child: Text(
                                                                  'Size ${item.size} • ${formatCurrency(item.price)} k',
                                                                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            SizedBox(
                                                              width: 120,
                                                              child: Container(
                                                                height: 40,
                                                                decoration: BoxDecoration(
                                                                  border: Border.all(color: kBorder),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                  color: Colors.white,
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    InkWell(
                                                                      mouseCursor: SystemMouseCursors.click,
                                                                      onTap: () => changeQty(item, item.quantity - 1),
                                                                      child: const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                                        child: Icon(Icons.remove, size: 16),
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      child: InkWell(
                                                                        mouseCursor: SystemMouseCursors.click,
                                                                        onTap: () => openManualInput(item),
                                                                        child: Center(
                                                                          child: Text(
                                                                            '${item.quantity}',
                                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    InkWell(
                                                                      mouseCursor: SystemMouseCursors.click,
                                                                      onTap: () => changeQty(item, item.quantity + 1),
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
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return widgets;
                                }(),
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Đóng'),
                            ),
                          ),
                        ],
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

  void _openOrdererProductQuickView(Product p) {
    final image = p.image.trim();
    final imageUrl = ApiService.resolveApiUrl(image);
    final canLoadNetworkImage = imageUrl.isNotEmpty;
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

            final hasChanges = qtys.isNotEmpty;

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFFCF3),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFB7E4C7)),
                      ),
                      child: Text(
                        'Tổng kho: ${p.variants.fold<int>(0, (s, v) => s + v.stock)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kSuccess),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                  height: 120,
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
                    const Text('Mẫu • Màu • Size', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...() {
                      final byColor = <String, List<Variant>>{};
                      for (final v in p.variants) {
                        byColor.putIfAbsent(v.color, () => []).add(v);
                      }
                      final colors = byColor.keys.toList()
                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                      return colors.map((colorName) {
                        final colorVariants = [...(byColor[colorName] ?? const <Variant>[])];
                        colorVariants.sort((a, b) => a.size.toLowerCase().compareTo(b.size.toLowerCase()));
                        final colorStock = colorVariants.fold<int>(0, (s, x) => s + x.stock);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Màu $colorName • Tổng kho: $colorStock', style: const TextStyle(fontWeight: FontWeight.w700, color: kPrimary)),
                              const SizedBox(height: 8),
                              ...colorVariants.map((v) {
                                final outOfStock = v.stock <= 0;
                                final currentQty = qtys[v.id] ?? 0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: outOfStock ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Size ${v.size}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Text('${formatCurrency(v.price)} k', style: const TextStyle(color: kTextSecondary)),
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
                                                      mouseCursor: SystemMouseCursors.click,
                                                      onTap: () => changeQty(v, currentQty - 1),
                                                      child: const Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        child: Icon(Icons.remove, size: 16),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: InkWell(
                                                        mouseCursor: SystemMouseCursors.click,
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
                                                      mouseCursor: SystemMouseCursors.click,
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
                            ],
                          ),
                        );
                      });
                    }(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                              label: const Text('Đóng'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: hasChanges
                                  ? () {
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
                                    }
                                  : null,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Xác nhận'),
                            ),
                          ),
                        ],
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
      final res = AppModeManager.isManager
          ? await ApiService.checkoutDesktopDispatch(
              customerName: _nameCtrl.text.trim(),
              customerPhone: _phoneCtrl.text.trim(),
              cart: _cart,
            )
          : await ApiService.checkoutDraft(
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
                  if (q.isEmpty) return _customerNameSuggestions;
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
                    onTap: () {
                      textCtrl.value = textCtrl.value.copyWith(
                        text: textCtrl.text,
                        selection: TextSelection.collapsed(offset: textCtrl.text.length),
                      );
                    },
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
                onChanged: (v) {
                  _search = v;
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 250), () => _load(silent: true));
                },
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
                          final selectedSummary = _selectedSummaryForProduct(p);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _openOrdererProductQuickView(p),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tổng tồn: $totalStock'),
                                  if (selectedSummary.isNotEmpty)
                                    Text(
                                      selectedSummary,
                                      style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
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
                            subtitle: Text('${formatCurrency(c.price)} k x ${c.quantity}'),
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
                    'Tổng: ${formatCurrency(_total)} k',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _cart.isEmpty ? null : _openCartReviewPopup,
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  label: const Text('Xem'),
                ),
                const SizedBox(width: 8),
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

class _ApprovedOrdersScreen extends StatefulWidget {
  final void Function(int orderId) onReceived;
  const _ApprovedOrdersScreen({super.key, required this.onReceived});

  @override
  State<_ApprovedOrdersScreen> createState() => _ApprovedOrdersScreenState();
}

class _ApprovedOrdersScreenState extends State<_ApprovedOrdersScreen> {
  bool _loading = true;
  List<Order> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reloadOrders() => _load();

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final orders = await ApiService.getApprovedOrders();
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải đơn đã duyệt: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted && !silent) setState(() => _loading = false);
  }

  List<Widget> _orderGroupedSummaryWidgets(Order o) {
    final grouped = <String, Map<String, Map<String, int>>>{};
    for (final it in o.items) {
      final pair = _splitVariantInfo(it.variantInfo);
      grouped.putIfAbsent(it.productName, () => {});
      grouped[it.productName]!.putIfAbsent(pair.color, () => {});
      grouped[it.productName]![pair.color]![pair.size] = (grouped[it.productName]![pair.color]![pair.size] ?? 0) + it.quantity;
    }
    if (grouped.isEmpty) {
      return const [Text('Không có chi tiết', style: TextStyle(fontSize: 12, color: kTextSecondary))];
    }

    final widgets = <Widget>[];
    grouped.forEach((model, byColor) {
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(model, style: const TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 15)),
              const SizedBox(height: 8),
              ...byColor.entries.map((entry) {
                final color = entry.key;
                final bySize = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Màu $color', style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: bySize.entries
                            .map((e) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: Text('Size ${e.key}: ${e.value}', style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
    return widgets;
  }

  Future<void> _receive(Order order) async {
    final pickerId = AppModeManager.employeeId;
    if (pickerId == null) return;
    try {
      await ApiService.receiveOrder(order.id, pickerId: pickerId);
      widget.onReceived(order.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi nhận đơn: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_orders.isEmpty) return const Center(child: Text('Chưa có đơn nào chờ nhận'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      itemBuilder: (_, i) {
        final o = _orders[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text('Đơn #${o.id} • ${o.customerName}'),
            subtitle: Text('${formatDate(o.createdAt)} • ${formatCurrency(o.totalAmount)} k'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _orderGroupedSummaryWidgets(o)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _receive(o),
                  child: const Text('Nhận đơn'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AcceptedOrdersScreen extends StatefulWidget {
  final void Function(int orderId, String? pickerNote) onConfirmed;
  final void Function(OrderItem item) onOpenItem;
  const _AcceptedOrdersScreen({super.key, required this.onConfirmed, required this.onOpenItem});

  @override
  State<_AcceptedOrdersScreen> createState() => _AcceptedOrdersScreenState();
}

class _AcceptedOrdersScreenState extends State<_AcceptedOrdersScreen> {
  bool _loading = true;
  List<Order> _orders = [];
  final Set<int> _confirming = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reloadOrders() => _load();

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final pickerId = AppModeManager.employeeId;
      if (pickerId == null) {
        if (mounted) setState(() => _orders = []);
        return;
      }
      final orders = await ApiService.getAssignedOrders(pickerId);
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

  int _initialPickedQty(OrderItem item) {
    final stock = item.currentStock;
    if (stock == null) return item.quantity;
    if (stock >= item.quantity) return item.quantity;
    if (stock < 0) return 0;
    return stock;
  }

  String _compactGroupedSummary(Order o) {
    final grouped = <String, Map<String, int>>{};
    for (final it in o.items) {
      final pair = _splitVariantInfo(it.variantInfo);
      grouped.putIfAbsent(it.productName, () => {});
      grouped[it.productName]![pair.color] = (grouped[it.productName]![pair.color] ?? 0) + it.quantity;
    }
    if (grouped.isEmpty) return '';
    final lines = <String>[];
    grouped.forEach((model, byColor) {
      final c = byColor.entries.map((e) => '${e.key}:${e.value}').join(' • ');
      lines.add('$model ($c)');
    });
    return lines.take(2).join('\n');
  }

  Future<String?> _pickDeliveryPhotoPath() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    final x = await picker.pickImage(source: source, imageQuality: 75);
    return x?.path;
  }

  Future<void> _confirmWithPicked(Order order, Map<int, int> pickedByKey, {String pickerNote = ''}) async {
    setState(() => _confirming.add(order.id));
    try {
      final pickerId = AppModeManager.employeeId;
      if (pickerId == null) throw Exception('Thiếu phiên đăng nhập picker');
      final payload = <Map<String, dynamic>>[];
      for (var i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        final key = item.orderItemId ?? (item.variantId ?? (100000 + i));
        payload.add({
          'order_item_id': item.orderItemId,
          'variant_id': item.variantId,
          'picked_qty': pickedByKey[key] ?? _initialPickedQty(item),
        });
      }

      final photoPath = await _pickDeliveryPhotoPath();
      if (photoPath == null || photoPath.trim().isEmpty) {
        throw Exception('Bắt buộc có ảnh xác nhận giao hàng');
      }

      final res = await ApiService.deliverOrder(
        order.id,
        pickerId: pickerId,
        photoPath: photoPath,
        items: payload,
        pickerNote: pickerNote,
      );
      final note = (res['picker_note'] ?? '').toString();
      widget.onConfirmed(order.id, note.isEmpty ? null : note);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xác nhận: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _confirming.remove(order.id));
  }

  Future<void> _openOrderPopup(Order order) async {
    final pickedByKey = <int, int>{};
    final pickerNoteCtrl = TextEditingController();
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final key = item.orderItemId ?? (item.variantId ?? (100000 + i));
      pickedByKey[key] = _initialPickedQty(item);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> openManualInput(OrderItem item, int key) async {
              final currentQty = pickedByKey[key] ?? 0;
              final maxQty = item.quantity;
              final ctrl = TextEditingController(text: '$currentQty');
              final value = await showDialog<int>(
                context: dialogContext,
                builder: (_) => AlertDialog(
                  title: const Text('Nhập số lượng thực tế'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(hintText: '0 - $maxQty'),
                    onSubmitted: (_) => Navigator.pop(dialogContext, int.tryParse(ctrl.text.trim()) ?? 0),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, int.tryParse(ctrl.text.trim()) ?? 0),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              if (value == null) return;
              setDialogState(() => pickedByKey[key] = value.clamp(0, maxQty));
            }

            void changeQty(OrderItem item, int key, int nextQty) {
              setDialogState(() => pickedByKey[key] = nextQty.clamp(0, item.quantity));
            }

            return FractionallySizedBox(
              heightFactor: 0.9,
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('Đơn #${order.id} — ${order.customerName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Text(
                        '${formatDate(order.createdAt)} • ${order.totalQty} sản phẩm • ${formatCurrency(order.totalAmount)} k',
                        style: const TextStyle(color: kTextSecondary, fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: pickerNoteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Ghi chú cho đơn (tuỳ chọn)',
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...() {
                              final grouped = <String, Map<String, List<MapEntry<int, OrderItem>>>>{};
                              for (final entry in order.items.asMap().entries) {
                                final item = entry.value;
                                final pair = _splitVariantInfo(item.variantInfo);
                                grouped.putIfAbsent(item.productName, () => {});
                                grouped[item.productName]!.putIfAbsent(pair.color, () => []).add(MapEntry(entry.key, item));
                              }

                              return grouped.entries.map((modelEntry) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(modelEntry.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kTextPrimary)),
                                      const SizedBox(height: 8),
                                      ...modelEntry.value.entries.map((colorEntry) {
                                        final totalReq = colorEntry.value.fold<int>(0, (s, x) => s + x.value.quantity);
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: kBorder),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Màu ${colorEntry.key} • YC $totalReq', style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimary)),
                                              const SizedBox(height: 6),
                                              ...colorEntry.value.map((pair) {
                                                final index = pair.key;
                                                final item = pair.value;
                                                final key = item.orderItemId ?? (item.variantId ?? (100000 + index));
                                                final currentQty = pickedByKey[key] ?? 0;
                                                final stock = item.currentStock;
                                                final stockText = stock == null ? '' : ' • Kho: $stock';
                                                final enough = item.enoughStock ?? true;
                                                final parsed = _splitVariantInfo(item.variantInfo);

                                                final itemTotal = item.price * currentQty;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 6),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: InkWell(
                                                          mouseCursor: SystemMouseCursors.click,
                                                          borderRadius: BorderRadius.circular(6),
                                                          onTap: () {
                                                            Navigator.pop(dialogContext);
                                                            widget.onOpenItem(item);
                                                          },
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  'Size ${parsed.size}',
                                                                  style: TextStyle(fontSize: 13, color: enough ? kTextPrimary : kDanger, fontWeight: FontWeight.w600),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  'YC ${item.quantity}$stockText',
                                                                  style: TextStyle(fontSize: 12, color: enough ? kTextSecondary : kDanger),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  'Giá ${formatCurrency(item.price)} k • Thành ${formatCurrency(itemTotal)} k',
                                                                  style: TextStyle(fontSize: 12, color: enough ? kTextSecondary : kDanger),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 120,
                                                        child: Container(
                                                          height: 40,
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: kBorder),
                                                            borderRadius: BorderRadius.circular(6),
                                                            color: Colors.white,
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              InkWell(
                                                                mouseCursor: SystemMouseCursors.click,
                                                                onTap: () => changeQty(item, key, currentQty - 1),
                                                                child: const Padding(
                                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                                  child: Icon(Icons.remove, size: 16),
                                                                ),
                                                              ),
                                                              Expanded(
                                                                child: InkWell(
                                                                  mouseCursor: SystemMouseCursors.click,
                                                                  onTap: () => openManualInput(item, key),
                                                                  child: Center(
                                                                    child: Text(
                                                                      '$currentQty',
                                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              InkWell(
                                                                mouseCursor: SystemMouseCursors.click,
                                                                onTap: () => changeQty(item, key, currentQty + 1),
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
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              });
                            }(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Đóng'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: kSuccess, foregroundColor: Colors.white),
                              onPressed: _confirming.contains(order.id)
                                  ? null
                                  : () async {
                                      Navigator.pop(dialogContext);
                                      await _confirmWithPicked(order, pickedByKey, pickerNote: pickerNoteCtrl.text.trim());
                                    },
                              icon: _confirming.contains(order.id)
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Xác nhận đơn'),
                            ),
                          ),
                        ],
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
    pickerNoteCtrl.dispose();
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
                      Text('Không có đơn hàng cần giao', style: TextStyle(color: kTextSecondary)),
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
                  child: ListTile(
                    onTap: isConfirming ? null : () => _openOrderPopup(o),
                    title: Text('Đơn #${o.id} — ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${formatDate(o.createdAt)} • ${o.totalQty} sản phẩm\n${_compactGroupedSummary(o)}'),
                    trailing: isConfirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new),
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
        final imageUrl = ApiService.resolveApiUrl(image);
        final canLoadNetworkImage = imageUrl.isNotEmpty;

        return FractionallySizedBox(
          heightFactor: 0.95,
          child: SafeArea(
            top: false,
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
                            imageUrl,
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
                const Text('Màu & size tồn kho', style: TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary)),
                const SizedBox(height: 8),
                ...() {
                  final byColor = <String, List<Variant>>{};
                  for (final v in p.variants) {
                    byColor.putIfAbsent(v.color, () => []).add(v);
                  }
                  final colors = byColor.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                  return colors.map((colorName) {
                    final variants = [...(byColor[colorName] ?? const <Variant>[])];
                    variants.sort((a, b) => a.size.toLowerCase().compareTo(b.size.toLowerCase()));
                    final colorStock = variants.fold<int>(0, (s, x) => s + x.stock);
                    final colorHasFocus = focusVariant != null && variants.any((x) => x.id == focusVariant?.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorHasFocus ? const Color(0xFFF6FBF7) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colorHasFocus ? const Color(0xFFBBDDC7) : kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Màu $colorName',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary),
                                ),
                              ),
                              Text(
                                'Tổng kho: $colorStock',
                                style: TextStyle(
                                  color: colorStock > 0 ? kTextSecondary : kDanger,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: variants.map((v) {
                              final isFocus = focusVariant != null && v.id == focusVariant.id;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isFocus ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: isFocus ? const Color(0xFF66BB6A) : kBorder),
                                ),
                                child: Text(
                                  'Size ${v.size}: ${v.stock}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: v.stock > 0 ? kTextPrimary : kDanger,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  });
                }(),
                ],
              ),
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

















