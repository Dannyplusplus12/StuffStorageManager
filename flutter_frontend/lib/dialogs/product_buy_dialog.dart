import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    final p = widget.product;
    final byColor = <String, List<Variant>>{};
    for (final v in p.variants) {
      byColor.putIfAbsent(v.color, () => []).add(v);
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('Giá: ${p.priceRange} k', style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView(
                  children: byColor.entries.map((e) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ...e.value.map((v) {
                              final outOfStock = v.stock <= 0;
                              Color? rowBg;
                              if (outOfStock) {
                                rowBg = kNoStock;
                              } else if (v.stock < 20) {
                                rowBg = kLowStock;
                              }
                              return Container(
                                color: rowBg,
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Row(
                                  children: [
                                    SizedBox(width: 60, child: Text('Size ${v.size}')),
                                    Expanded(child: Text('${formatCurrency(v.price)}k (Kho: ${v.stock})${outOfStock ? " (HẾT)" : ""}')),
                                    SizedBox(
                                      width: 80,
                                      child: outOfStock
                                          ? const Text('Hết', style: TextStyle(color: Colors.red))
                                          : _ScrollableQuantityField(
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
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy bỏ')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final items = <CartItem>[];
                    _qtys.forEach((vid, qty) {
                      if (qty > 0) {
                        final v = p.variants.firstWhere((x) => x.id == vid);
                        items.add(CartItem(variantId: v.id!, productName: p.name, color: v.color, size: v.size, price: v.price, quantity: qty));
                      }
                    });
                    Navigator.pop(context, items);
                  },
                  child: const Text('Thêm vào đơn'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollableQuantityField extends StatefulWidget {
  final int variantId;
  final int maxStock;
  final int currentQty;
  final ValueChanged<int> onChanged;

  const _ScrollableQuantityField({
    required this.variantId,
    required this.maxStock,
    required this.currentQty,
    required this.onChanged,
  });

  @override
  State<_ScrollableQuantityField> createState() => _ScrollableQuantityFieldState();
}

class _ScrollableQuantityFieldState extends State<_ScrollableQuantityField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentQty > 0 ? '${widget.currentQty}' : '');
  }

  @override
  void didUpdateWidget(_ScrollableQuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentQty != widget.currentQty) {
      _controller.text = widget.currentQty > 0 ? '${widget.currentQty}' : '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    final newValue = (widget.currentQty + 1).clamp(0, widget.maxStock);
    widget.onChanged(newValue);
  }

  void _decrement() {
    final newValue = (widget.currentQty - 1).clamp(0, widget.maxStock);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          if (event.scrollDelta.dy < 0) {
            _increment();
          } else if (event.scrollDelta.dy > 0) {
            _decrement();
          }
        }
      },
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '0', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        onChanged: (val) {
          final q = int.tryParse(val) ?? 0;
          widget.onChanged(q);
        },
      ),
    );
  }
}
