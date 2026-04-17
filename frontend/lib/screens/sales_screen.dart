import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/customer.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _customerCtrl = TextEditingController();
  final _customerFocus = FocusNode();
  final _phoneCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(text: _todayText());

  List<Customer> _customers = [];
  List<Product> _products = [];
  final List<_SaleRow> _rows = [_SaleRow()];
  bool _loading = false;

  static String _todayText() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _customerFocus.dispose();
    _phoneCtrl.dispose();
    _dateCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rs = await Future.wait([
        ApiService.getCustomers(),
        ApiService.getProducts(),
      ]);
      if (mounted) {
        setState(() {
          _customers = rs[0] as List<Customer>;
          _products = rs[1] as List<Product>;
        });
      }
    } catch (e) {
      _snack('$e', Colors.red);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  String _norm(String s) {
    const withAccents = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const withoutAccents = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyyd';
    final low = s.toLowerCase().trim();
    final out = StringBuffer();
    for (int i = 0; i < low.length; i++) {
      final idx = withAccents.indexOf(low[i]);
      out.write(idx == -1 ? low[i] : withoutAccents[idx]);
    }
    return out.toString();
  }

  Product? _findProductExact(String input) {
    final key = _norm(input);
    for (final p in _products) {
      if (_norm(p.code) == key || _norm(p.name) == key) return p;
    }
    return null;
  }

  Variant? _findVariantExact(Product? p, String colorInput, String sizeInput) {
    if (p == null) return null;
    final cKey = _norm(colorInput);
    final sKey = _norm(sizeInput);
    for (final v in p.variants) {
      if (_norm(v.color) == cKey && _norm(v.size) == sKey) return v;
    }
    return null;
  }

  List<String> _productCodes(String q) {
    final key = _norm(q);
    final codes = _products.map((e) => e.code.isEmpty ? e.name : e.code).toSet().toList();
    codes.sort();
    if (key.isEmpty) return codes;
    return codes.where((n) => _norm(n).contains(key)).toList();
  }

  List<String> _colorsFor(_SaleRow r, String q) {
    final p = _findProductExact(r.codeCtrl.text);
    final colors = (p?.variants.map((v) => v.color).toSet().toList() ?? []);
    colors.sort();
    final key = _norm(q);
    if (key.isEmpty) return colors;
    return colors.where((c) => _norm(c).contains(key)).toList();
  }

  List<String> _sizesFor(_SaleRow r, String q) {
    final p = _findProductExact(r.codeCtrl.text);
    final cKey = _norm(r.colorCtrl.text);
    final sizes = (p?.variants.where((v) => cKey.isEmpty || _norm(v.color) == cKey).map((v) => v.size).toSet().toList() ?? []);
    sizes.sort();
    final key = _norm(q);
    if (key.isEmpty) return sizes;
    return sizes.where((s) => _norm(s).contains(key)).toList();
  }

  void _onCodeChanged(_SaleRow r, String v) {
    final hasCode = v.trim().isNotEmpty;
    if (!hasCode) {
      r.autoAddedNextRow = false;
    }

    final p = _findProductExact(v);
    if (p != null) {
      r.nameCtrl.text = p.name;
      if (p.variants.length == 1) {
        final only = p.variants.first;
        r.colorCtrl.text = only.color;
        r.sizeCtrl.text = only.size;
        r.price = only.price;
      }
    }
    _recalcRow(r);

    if (hasCode && !r.autoAddedNextRow) {
      r.autoAddedNextRow = true;
      setState(() => _rows.add(_SaleRow()));
    }
  }

  void _onColorOrSizeChanged(_SaleRow r) {
    final p = _findProductExact(r.codeCtrl.text);
    final exact = _findVariantExact(p, r.colorCtrl.text, r.sizeCtrl.text);
    if (exact != null) {
      r.price = exact.price;
    }
    _recalcRow(r);
  }

  int? _maxStockForRow(_SaleRow r) {
    final p = _findProductExact(r.codeCtrl.text);
    final v = _findVariantExact(p, r.colorCtrl.text, r.sizeCtrl.text);
    return v?.stock;
  }

  void _recalcRow(_SaleRow r) {
    var q = int.tryParse(r.qtyCtrl.text.trim()) ?? 0;
    final maxStock = _maxStockForRow(r);
    if (maxStock != null) {
      q = q.clamp(0, maxStock);
      final fixedText = q == 0 ? '' : '$q';
      if (r.qtyCtrl.text.trim() != fixedText) {
        r.qtyCtrl.value = TextEditingValue(
          text: fixedText,
          selection: TextSelection.collapsed(offset: fixedText.length),
        );
      }
    }
    r.amount = q * r.price;
    setState(() {});
  }

  int get _total => _rows.fold(0, (s, r) => s + r.amount);

  Future<void> _submit() async {
    final cart = <CartItem>[];
    for (final r in _rows) {
      final p = _findProductExact(r.codeCtrl.text);
      final v = _findVariantExact(p, r.colorCtrl.text, r.sizeCtrl.text);
      var qty = int.tryParse(r.qtyCtrl.text.trim()) ?? 0;
      if (p == null || v == null || v.id == null || qty <= 0) continue;
      qty = qty.clamp(0, v.stock);
      if (qty <= 0) continue;
      cart.add(CartItem(
        variantId: v.id!,
        productName: p.name,
        color: v.color,
        size: v.size,
        price: v.price,
        quantity: qty,
      ));
    }
    if (cart.isEmpty) {
      _snack('Chưa có dòng hợp lệ để bán', Colors.red);
      return;
    }
    try {
      await ApiService.checkoutDesktopDispatch(
        customerName: _customerCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        cart: cart,
      );
      _snack('Đã gửi đơn cho picker, chờ nhận xử lý', Colors.green);
      setState(() {
        for (final r in _rows) {
          r.dispose();
        }
        _rows
          ..clear()
          ..add(_SaleRow());
      });
    } catch (e) {
      _snack('$e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelBg = appPanelBg(context);
    final borderColor = appBorderColor(context);
    final textPrimary = appTextPrimary(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: panelBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bán hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: FixedColumnWidth(360),
                        1: FixedColumnWidth(12),
                        2: FixedColumnWidth(220),
                        3: FixedColumnWidth(12),
                        4: FixedColumnWidth(160),
                      },
                      children: [
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('Khách hàng', style: TextStyle(fontSize: 12, color: appTextSecondary(context), fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox.shrink(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('Số điện thoại', style: TextStyle(fontSize: 12, color: appTextSecondary(context), fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox.shrink(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('Ngày xuất', style: TextStyle(fontSize: 12, color: appTextSecondary(context), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            SizedBox(
                              height: 44,
                              child: _autoInput(
                                label: null,
                                controller: _customerCtrl,
                                focusNode: _customerFocus,
                                optionsWidth: 360,
                                source: (q) {
                                  final names = _customers.map((e) => e.name).toList();
                                  final key = _norm(q);
                                  if (key.isEmpty) return names;
                                  return names.where((n) => _norm(n).contains(key)).toList();
                                },
                                onChanged: (v) {
                                  final key = _norm(v);
                                  final hit = _customers.where((c) => _norm(c.name) == key).toList();
                                  if (hit.isNotEmpty) _phoneCtrl.text = hit.first.phone;
                                },
                              ),
                            ),
                            const SizedBox.shrink(),
                            SizedBox(
                              height: 44,
                              child: TextField(controller: _phoneCtrl, decoration: const InputDecoration(hintText: 'Số điện thoại')),
                            ),
                            const SizedBox.shrink(),
                            SizedBox(
                              height: 44,
                              child: TextField(controller: _dateCtrl, decoration: const InputDecoration(hintText: 'Ngày xuất')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: panelBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            _header(),
                            Expanded(
                              child: ListView(
                                children: _rows.asMap().entries.map((e) => _row(e.key, e.value)).toList(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Text('TỔNG TIỀN: ${formatCurrency(_total)} k', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: textPrimary)),
                    const Spacer(),
                    SizedBox(
                      height: 48,
                      width: 280,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('XUẤT HÀNG', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    Widget th(String t, {double? w}) => SizedBox(
          width: w,
          child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: appTextPrimary(context))),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: appBorderColor(context))),
        color: appPanelSoftBg(context),
      ),
      child: Row(
        children: [
          th('Mã hàng', w: 140),
          const SizedBox(width: 8),
          th('Tên mặt hàng', w: 220),
          const SizedBox(width: 8),
          th('Màu sắc', w: 150),
          const SizedBox(width: 8),
          th('SL', w: 70),
          const SizedBox(width: 8),
          th('Size', w: 100),
          const SizedBox(width: 8),
          th('Đơn giá', w: 120),
          const SizedBox(width: 8),
          th('Thành tiền', w: 130),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _row(int idx, _SaleRow r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: appBorderColor(context)))),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: _autoInput(
              controller: r.codeCtrl,
              focusNode: r.codeFocus,
              optionsWidth: 220,
              source: (q) => _productCodes(q),
              onChanged: (v) => _onCodeChanged(r, v),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 220, child: TextField(controller: r.nameCtrl)),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: _autoInput(
              controller: r.colorCtrl,
              focusNode: r.colorFocus,
              optionsWidth: 220,
              source: (q) => _colorsFor(r, q),
              onChanged: (_) => _onColorOrSizeChanged(r),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: _QtyInputField(
              controller: r.qtyCtrl,
              maxQuantity: _maxStockForRow(r),
              onValueChanged: (_) => _recalcRow(r),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: _autoInput(
              controller: r.sizeCtrl,
              focusNode: r.sizeFocus,
              optionsWidth: 180,
              source: (q) => _sizesFor(r, q),
              onChanged: (_) => _onColorOrSizeChanged(r),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(formatCurrency(r.price), style: TextStyle(color: appTextPrimary(context)))),
          SizedBox(width: 130, child: Text(formatCurrency(r.amount), style: TextStyle(color: appTextPrimary(context)))),
          IconButton(
            mouseCursor: SystemMouseCursors.click,
            onPressed: _rows.length <= 1
                ? null
                : () {
                    setState(() {
                      final row = _rows.removeAt(idx);
                      row.dispose();
                    });
                  },
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _autoInput({
    String? label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required double optionsWidth,
    required List<String> Function(String query) source,
    required ValueChanged<String> onChanged,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (textEditingValue) => source(textEditingValue.text),
      displayStringForOption: (o) => o,
      onSelected: (v) {
        controller.text = v;
        onChanged(v);
      },
      fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label),
          onChanged: onChanged,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        if (opts.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: SizedBox(
              width: optionsWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: opts.length,
                  itemBuilder: (_, i) {
                    final o = opts[i];
                    return ListTile(
                      dense: true,
                      title: Text(o),
                      onTap: () => onSelected(o),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SaleRow {
  final codeCtrl = TextEditingController();
  final codeFocus = FocusNode();
  final nameCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  final colorFocus = FocusNode();
  final sizeCtrl = TextEditingController();
  final sizeFocus = FocusNode();
  final qtyCtrl = TextEditingController();
  int price = 0;
  int amount = 0;
  bool autoAddedNextRow = false;

  void dispose() {
    codeCtrl.dispose();
    codeFocus.dispose();
    nameCtrl.dispose();
    colorCtrl.dispose();
    colorFocus.dispose();
    sizeCtrl.dispose();
    sizeFocus.dispose();
    qtyCtrl.dispose();
  }
}

class _QtyInputField extends StatefulWidget {
  final TextEditingController controller;
  final int? maxQuantity;
  final ValueChanged<int> onValueChanged;

  const _QtyInputField({
    required this.controller,
    this.maxQuantity,
    required this.onValueChanged,
  });

  @override
  State<_QtyInputField> createState() => _QtyInputFieldState();
}

class _QtyInputFieldState extends State<_QtyInputField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _apply(int value) {
    final max = widget.maxQuantity;
    final next = max == null ? value.clamp(0, 999999999) : value.clamp(0, max);
    final text = next == 0 ? '' : '$next';
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onValueChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (_focusNode.hasFocus && event is PointerScrollEvent) {
          final current = int.tryParse(widget.controller.text.trim()) ?? 0;
          if (event.scrollDelta.dy < 0) {
            _apply(current + 1);
          } else if (event.scrollDelta.dy > 0) {
            _apply(current - 1);
          }
        }
      },
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        onChanged: (v) => _apply(int.tryParse(v.trim()) ?? 0),
      ),
    );
  }
}
