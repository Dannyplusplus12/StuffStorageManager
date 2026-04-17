import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../theme.dart';
import '../utils.dart';

class ProductBuyDialog extends StatefulWidget {
  final Product product;
  const ProductBuyDialog({super.key, required this.product});
  @override
  State<ProductBuyDialog> createState() => _ProductBuyDialogState();
}

class _ProductBuyDialogState extends State<ProductBuyDialog> {
  final Map<int, int> _qtys = {};

  @override
  Widget build(BuildContext context) {
    final panelBg = appPanelBg(context);
    final panelSoftBg = appPanelSoftBg(context);
    final borderColor = appBorderColor(context);
    final textPrimary = appTextPrimary(context);
    final textSecondary = appTextSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.product;
    final byColor = <String, List<Variant>>{};
    for (final v in p.variants) {
      byColor.putIfAbsent(v.color, () => []).add(v);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Giá: ${p.priceRange}k',
                            style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: textSecondary,
                      mouseCursor: SystemMouseCursors.click,
                    )
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  itemCount: byColor.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final e = byColor.entries.elementAt(idx);
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: panelSoftBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F2F4A) : kPrimaryLight,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: isDark ? const Color(0xFF35507A) : const Color(0xFFFFD9D1)),
                            ),
                            child: Text(
                              e.key.toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? const Color(0xFF93C5FD) : kPrimaryDark),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...e.value.map((v) {
                            final outOfStock = v.stock <= 0;
                            final lowStock = v.stock > 0 && v.stock < 20;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? (outOfStock
                                        ? const Color(0xFF3A1F27)
                                        : (lowStock ? const Color(0xFF3B311C) : const Color(0xFF1A2A44)))
                                    : (outOfStock
                                        ? const Color(0xFFFFF1F2)
                                        : (lowStock ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC))),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                         Text('Size ${v.size}', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                                        const SizedBox(height: 2),
                                         Text('${formatCurrency(v.price)}k', style: TextStyle(color: textSecondary)),
                                        Text('Kho: ${v.stock}${outOfStock ? ' (HẾT)' : ''}',
                                            style: TextStyle(
                                              color: outOfStock ? kDanger : textSecondary,
                                              fontSize: 12,
                                            )),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: outOfStock
                                        ? const Center(
                                            child: Text('Hết hàng', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                          )
                                        : _QuantityStepper(
                                            variantId: v.id!,
                                            maxStock: v.stock,
                                            currentQty: _qtys[v.id] ?? 0,
                                            onChanged: (q) {
                                              setState(() {
                                                if (q > 0 && q <= v.stock) {
                                                  _qtys[v.id!] = q;
                                                } else {
                                                  _qtys.remove(v.id);
                                                }
                                              });
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                  color: panelBg,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy bỏ'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton(
                            onPressed: () {
                              final items = <CartItem>[];
                              _qtys.forEach((vid, qty) {
                                if (qty > 0) {
                                  final v = p.variants.firstWhere((x) => x.id == vid);
                                  items.add(
                                    CartItem(
                                      variantId: v.id!,
                                      productName: p.name,
                                      color: v.color,
                                      size: v.size,
                                      price: v.price,
                                      quantity: qty,
                                    ),
                                  );
                                }
                              });
                              Navigator.pop(context, items);
                            },
                            child: const Text('Thêm vào đơn'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatefulWidget {
  final int variantId;
  final int maxStock;
  final int currentQty;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({
    required this.variantId,
    required this.maxStock,
    required this.currentQty,
    required this.onChanged,
  });

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentQty}');
  }

  @override
  void didUpdateWidget(covariant _QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentQty != widget.currentQty) {
      final currentTextValue = int.tryParse(_controller.text.trim()) ?? 0;
      if (currentTextValue != widget.currentQty) {
        final nextText = '${widget.currentQty}';
        _controller.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _increase() => widget.onChanged((widget.currentQty + 1).clamp(0, widget.maxStock));

  void _decrease() => widget.onChanged((widget.currentQty - 1).clamp(0, widget.maxStock));

  void _applyInput(String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    widget.onChanged(parsed.clamp(0, widget.maxStock));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
            final signal = resolvedEvent as PointerScrollEvent;
            if (signal.scrollDelta.dy < 0) {
              _increase();
            } else if (signal.scrollDelta.dy > 0) {
              _decrease();
            }
          });
        }
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: appBorderColor(context)),
          borderRadius: BorderRadius.circular(6),
          color: appPanelBg(context),
        ),
        child: Row(
          children: [
            InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: _decrease,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Icon(Icons.remove, size: 16),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                onChanged: _applyInput,
                onEditingComplete: () {
                  _applyInput(_controller.text);
                  _focusNode.unfocus();
                },
              ),
            ),
            InkWell(
              mouseCursor: SystemMouseCursors.click,
              onTap: _increase,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Icon(Icons.add, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
