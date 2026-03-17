import 'package:flutter/material.dart';
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
    final p = widget.product;
    final byColor = <String, List<Variant>>{};
    for (final v in p.variants) {
      byColor.putIfAbsent(v.color, () => []).add(v);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Giá: ${p.priceRange} k',
                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: byColor.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final e = byColor.entries.elementAt(idx);
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              e.key.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
                                color: outOfStock
                                    ? const Color(0xFFFFF1F2)
                                    : (lowStock ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Size ${v.size}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text('${formatCurrency(v.price)}k', style: const TextStyle(color: kTextSecondary)),
                                        Text('Kho: ${v.stock}${outOfStock ? ' (HẾT)' : ''}',
                                            style: TextStyle(
                                              color: outOfStock ? kDanger : kTextSecondary,
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
              const SizedBox(height: 10),
              SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy bỏ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
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

  Future<void> _openManualInput(BuildContext context) async {
    final ctrl = TextEditingController(text: currentQty > 0 ? '$currentQty' : '');
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nhập số lượng'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: '0 - $maxStock'),
          onSubmitted: (_) {
            final q = int.tryParse(ctrl.text.trim()) ?? 0;
            Navigator.pop(context, q);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final q = int.tryParse(ctrl.text.trim()) ?? 0;
              Navigator.pop(context, q);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (value == null) return;
    onChanged(value.clamp(0, maxStock));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => onChanged((currentQty - 1).clamp(0, maxStock)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(Icons.remove, size: 16),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _openManualInput(context),
              child: Center(
                child: Text(
                  '$currentQty',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () => onChanged((currentQty + 1).clamp(0, maxStock)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(Icons.add, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
