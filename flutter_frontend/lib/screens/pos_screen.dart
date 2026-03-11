import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const PosScreen({super.key, required this.inventoryMode});
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
        _snack('Da cap nhat don hang!', Colors.green);
      } else {
        await ApiService.checkout(
          customerName: _custNameCtrl.text,
          customerPhone: _custPhoneCtrl.text,
          cart: _cart,
        );
        _snack('Da xuat kho va tao hoa don!', Colors.green);
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
    return Row(children: [Expanded(child: _productArea()), _rightPanel()]);
  }

  Widget _productArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Row(children: [
                Text(
                  widget.inventoryMode ? 'Kho hang' : 'Xuat hang',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
                ),
                const SizedBox(width: 8),
                if (_products.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Text('${_products.length} sản phẩm',
                        style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
            SizedBox(
              width: 300, height: 38,
              child: TextField(
                decoration: const InputDecoration(hintText: 'Tim san pham...', prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (v) {
                  _search = v;
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (_search == v) _loadProducts(v);
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: () => _loadProducts(_search),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Làm mới'),
              ),
            ),
          ]),
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
          const Text('Khong co san pham nao', style: TextStyle(color: kTextSecondary)),
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
      badgeLabel = 'Het hang';
    } else if (hasLow) {
      borderColor = const Color(0xFFFBC02D);
      badgeBg = kWarning;
      badgeLabel = 'Con it';
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
    if (result != null && result.isNotEmpty) setState(() => _cart.addAll(result));
  }

  void _editProduct(Product p) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => EditProductDialog(product: p));
    if (changed == true) _loadProducts(_search);
  }

  Widget _rightPanel() {
    return Container(
      width: 380,
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: kBorder))),
      child: widget.inventoryMode ? AddProductPanel(onAdded: () => _loadProducts(_search)) : _cartPanel(),
    );
  }

  Widget _cartPanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('Khach hang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (_editingOrderId != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Text('Sua don #$_editingOrderId',
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
            ctrl.addListener(() => _custNameCtrl.text = ctrl.text);
            return TextField(
              controller: ctrl, focusNode: fn,
              decoration: const InputDecoration(
                  hintText: 'Ten khach hang', prefixIcon: Icon(Icons.person_outline, size: 18)),
            );
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _custPhoneCtrl,
          decoration: const InputDecoration(
              hintText: 'So dien thoai', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Gio hang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
            TextButton.icon(
              onPressed: () => setState(() => _cart.clear()),
              icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
              label: const Text('Xoa tat', style: TextStyle(color: Colors.red, fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: _cartList()),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Tong tien:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${formatCurrency(_total)} d',
                style: const TextStyle(fontSize: 18, color: kPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _cart.isNotEmpty ? _checkout : null,
            icon: Icon(_editingOrderId != null ? Icons.update : Icons.shopping_cart_checkout, size: 18),
            label: Text(
              _editingOrderId != null ? 'Cap nhat Don #$_editingOrderId' : 'Xuat hang',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_editingOrderId != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              onPressed: cancelEditing,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Huy chinh sua', style: TextStyle(fontSize: 12)),
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
          const Text('Chua co san pham', style: TextStyle(color: kTextSecondary)),
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
            SizedBox(
              width: 50, height: 32,
              child: TextField(
                controller: TextEditingController(text: '${it.quantity}'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(contentPadding: EdgeInsets.all(4)),
                onChanged: (v) {
                  final q = int.tryParse(v);
                  if (q != null && q > 0) setState(() => it.quantity = q);
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => setState(() => _cart.removeAt(i)),
            ),
          ]),
        );
      },
    );
  }
}
