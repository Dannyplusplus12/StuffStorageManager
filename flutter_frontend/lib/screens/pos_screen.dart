import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';
import '../dialogs/product_buy_dialog.dart';
import '../dialogs/edit_product_dialog.dart';
import '../widgets/add_product_panel.dart';

class PosScreen extends StatefulWidget {
  final bool inventoryMode;
  final bool showRightPanel;
  final bool showProductArea;
  final String? titleOverride;
  const PosScreen({
    super.key,
    required this.inventoryMode,
    this.showRightPanel = true,
    this.showProductArea = true,
    this.titleOverride,
  });
  @override
  PosScreenState createState() => PosScreenState();
}

class PosScreenState extends State<PosScreen> {
  List<Product> _products = [];
  bool _loading = false;
  String _search = '';
  List<CartItem> _cart = [];
  int? _editingOrderId;
  final _custNameCtrl = TextEditingController();
  final _custPhoneCtrl = TextEditingController();
  List<String> _suggestions = [];
  int _acKey = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (!widget.inventoryMode) _loadSuggestions();
  }

  @override
  void dispose() {
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts([String q = '']) async {
    setState(() => _loading = true);
    try {
      _products = await ApiService.getProducts(search: q);
    } catch (e) {
      _snack('$e', Colors.red);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSuggestions() async {
    try {
      final c = await ApiService.getCustomers();
      if (mounted) setState(() => _suggestions = c.map((e) => e.name).toList());
    } catch (_) {}
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg, duration: const Duration(seconds: 2)),
    );
  }

  void cancelEditing() {
    setState(() {
      _cart = [];
      _editingOrderId = null;
      _custNameCtrl.clear();
      _custPhoneCtrl.clear();
      _acKey++;
    });
  }

  void loadOrderToEdit(Map<String, dynamic> od) {
    final items = od['items'] as List? ?? [];
    final cart = <CartItem>[];
    for (final i in items) {
      final vid = i['variant_id'];
      if (vid == null) {
        _snack('Don cu thieu variant ID, khong sua duoc', Colors.red);
        return;
      }
      final vi = (i['variant_info'] as String?) ?? '';
      String color = '', size = vi;
      if (vi.contains('-')) {
        final p = vi.split('-');
        color = p[0];
        size = p.sublist(1).join('-');
      }
      cart.add(CartItem(
        variantId: vid,
        productName: i['product_name'] ?? '',
        color: color,
        size: size,
        price: (i['price'] ?? 0) as int,
        quantity: (i['quantity'] ?? 0) as int,
      ));
    }
    setState(() {
      _cart = cart;
      _editingOrderId = od['id'];
      _custNameCtrl.text = od['customer_name'] ?? od['customer'] ?? '';
      _acKey++;
    });
  }

  int get _total => _cart.fold(0, (s, e) => s + e.price * e.quantity);
  int get _qty => _cart.fold(0, (s, e) => s + e.quantity);

  Future<void> _checkout() async {
    if (_cart.isEmpty) return;
    try {
      if (_editingOrderId != null) {
        await ApiService.updateOrder(
          _editingOrderId!,
          customerName: _custNameCtrl.text,
          customerPhone: _custPhoneCtrl.text,
          cart: _cart,
        );
        _snack('Đã cập nhật đơn hàng!', Colors.green);
      } else {
        await ApiService.checkout(
          customerName: _custNameCtrl.text,
          customerPhone: _custPhoneCtrl.text,
          cart: _cart,
        );
        _snack('Đã xuất kho và tạo hóa đơn!', Colors.green);
      }
      cancelEditing();
      _loadProducts(_search);
      _loadSuggestions();
    } catch (e) {
      _snack('$e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showProductArea) {
      return Container(
        color: Colors.white,
        child: AddProductPanel(onAdded: () => _loadProducts(_search)),
      );
    }

    if (!widget.showRightPanel) {
      return _productArea();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth >= 1200
            ? 380.0
            : constraints.maxWidth >= 900
                ? 340.0
                : constraints.maxWidth * 0.95;
        if (constraints.maxWidth < 900) {
          final panelHeight = math.min(520.0, MediaQuery.of(context).size.height * 0.6);
          return Column(
            children: [
              Expanded(child: _productArea()),
              const Divider(height: 1, thickness: 1),
              SizedBox(
                height: panelHeight.isFinite && panelHeight > 320 ? panelHeight : 360,
                width: double.infinity,
                child: _rightPanel(),
              ),
            ],
          );
        }
        return Row(children: [Expanded(child: _productArea()), _rightPanel(width: panelWidth)]);
      },
    );
  }

  Widget _productArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              Widget titleSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.titleOverride ?? (widget.inventoryMode ? 'Kho hàng' : 'Xuất hàng'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_products.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(12)),
                      child: Text('${_products.length} sản phẩm',
                          style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              );

              Widget searchSection(double width) {
                final cappedWidth = math.max(220.0, math.min(width, 460.0));
                return SizedBox(
                  width: cappedWidth,
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Tìm sản phẩm...',
                              prefixIcon: Icon(Icons.search, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (v) {
                              _search = v;
                              Future.delayed(const Duration(milliseconds: 400), () {
                                if (_search == v) _loadProducts(v);
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton.icon(
                            onPressed: () => _loadProducts(_search),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Làm mới'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 8),
                    searchSection(constraints.maxWidth),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 12),
                  searchSection(math.min(constraints.maxWidth * 0.45, 480)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(child: _grid()),
        ],
      ),
    );
  }

  Widget _grid() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_products.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('Không có sản phẩm nào', style: TextStyle(color: kTextSecondary)),
        ]),
      );
    }
    return LayoutBuilder(builder: (ctx, c) {
      final cols = ((c.maxWidth + 10) / 170).floor().clamp(1, 20);
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 148 / 220),
        itemCount: _products.length,
        itemBuilder: (_, i) => _card(_products[i]),
      );
    });
  }

  Widget _card(Product p) {
    final totalStock = p.variants.fold(0, (s, v) => s + v.stock);
    final hasLow = p.variants.any((v) => v.stock > 0 && v.stock < 20);
    Color borderColor = kBorder;
    Color? badgeBg;
    String badgeLabel = '';
    if (totalStock <= 0) {
      borderColor = const Color(0xFFEF9A9A);
      badgeBg = kDanger;
      badgeLabel = 'Hết hàng';
    } else if (hasLow) {
      borderColor = const Color(0xFFFBC02D);
      badgeBg = kWarning;
      badgeLabel = 'Còn ít';
    }
        return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.inventoryMode ? _editProduct(p) : _buyProduct(p),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 3,
              child: Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(child: Icon(Icons.checkroom, size: 40, color: Colors.grey[400])),
                  ),
                ),
                if (badgeBg != null)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(badgeLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${p.priceRange} k',
                    style: const TextStyle(fontSize: 11, color: kPrimary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _buyProduct(Product p) async {
    final result = await showDialog<List<CartItem>>(context: context, builder: (_) => ProductBuyDialog(product: p));
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

  void _editProduct(Product p) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => EditProductDialog(product: p));
    if (changed == true) _loadProducts(_search);
  }

  Widget _rightPanel({double? width}) {
    return Container(
      width: width,
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: kBorder))),
      child: widget.inventoryMode ? AddProductPanel(onAdded: () => _loadProducts(_search)) : _cartPanel(),
    );
  }

  Widget _cartPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('Khách hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (_editingOrderId != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Text('Sửa đơn #$_editingOrderId',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF856404))),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Autocomplete<String>(
          key: ValueKey(_acKey),
          initialValue: TextEditingValue(text: _custNameCtrl.text),
          optionsBuilder: (v) => v.text.isEmpty
              ? []
              : _suggestions.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
          onSelected: (s) => _custNameCtrl.text = s,
          fieldViewBuilder: (ctx, ctrl, fn, onSub) {
            return TextField(
              controller: ctrl, focusNode: fn,
              decoration: const InputDecoration(
                  hintText: 'Tên khách hàng', prefixIcon: Icon(Icons.person_outline, size: 18)),
              onChanged: (v) => _custNameCtrl.text = v,
            );
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _custPhoneCtrl,
          decoration: const InputDecoration(
              hintText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Giỏ hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 6),
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
              child: Text('$_qty',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
          if (_cart.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton.icon(
                onPressed: () => setState(() => _cart.clear()),
                icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                label: const Text('Xóa hết', style: TextStyle(color: Colors.red, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: _cartList()),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tổng tiền:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${formatCurrency(_total)} đ',
                style: const TextStyle(fontSize: 18, color: kPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
            child: ElevatedButton.icon(
              style: ButtonStyle(
                mouseCursor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled) ? SystemMouseCursors.basic : SystemMouseCursors.click),
              ),
              onPressed: _cart.isNotEmpty ? _checkout : null,
              icon: Icon(_editingOrderId != null ? Icons.update : Icons.shopping_cart_checkout, size: 18),
              label: Text(
                _editingOrderId != null ? 'Cập nhật đơn #$_editingOrderId' : 'Xuất hàng',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
        ),
        if (_editingOrderId != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
              child: OutlinedButton(
                style: ButtonStyle(
                  mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
                  foregroundColor: WidgetStateProperty.all(Colors.grey),
                ),
                onPressed: cancelEditing,
                child: const Text('Hủy chỉnh sửa', style: TextStyle(fontSize: 12)),
              ),
          ),
        ],
      ]),
    );
  }

  Widget _cartList() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          const Text('Chưa có sản phẩm', style: TextStyle(color: kTextSecondary)),
        ]),
      );
    }
    return ListView.builder(
      itemCount: _cart.length,
      itemBuilder: (_, i) {
        final it = _cart[i];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: kBorder)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.productName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text('${it.color} / ${it.size} - ${formatCurrency(it.price)} k',
                    style: const TextStyle(fontSize: 11, color: kTextSecondary)),
              ]),
            ),
            const SizedBox(width: 6),
            _QtyEditor(
              quantity: it.quantity,
              onChanged: (q) {
                if (q <= 0) return;
                setState(() => it.quantity = q);
              },
              onIncrement: () => setState(() => it.quantity += 1),
              onDecrement: () {
                if (it.quantity <= 1) return;
                setState(() => it.quantity -= 1);
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              mouseCursor: SystemMouseCursors.click,
              onPressed: () => setState(() => _cart.removeAt(i)),
            ),
          ]),
        );
      },
    );
  }
}

class _QtyEditor extends StatefulWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyEditor({
    required this.quantity,
    required this.onChanged,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  State<_QtyEditor> createState() => _QtyEditorState();
}

class _QtyEditorState extends State<_QtyEditor> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.quantity}');
  }

  @override
  void didUpdateWidget(covariant _QtyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && !_focusNode.hasFocus) {
      _controller.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: widget.onDecrement,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Icon(Icons.remove, size: 14),
            ),
          ),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (v) {
                final q = int.tryParse(v);
                if (q != null && q > 0) widget.onChanged(q);
              },
              onEditingComplete: () {
                final q = int.tryParse(_controller.text);
                if (q == null || q <= 0) {
                  _controller.text = '${widget.quantity}';
                }
                _focusNode.unfocus();
              },
            ),
          ),
          InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: widget.onIncrement,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Icon(Icons.add, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
