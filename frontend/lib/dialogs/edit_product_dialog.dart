import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../models/product.dart' show Product, Variant;
import '../services/api_service.dart';
import '../theme.dart';

class EditProductDialog extends StatefulWidget {
  final Product product;
  const EditProductDialog({super.key, required this.product});
  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late String _imagePath;
  late List<_ColorGroup> _groups;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.product.code);
    _nameCtrl = TextEditingController(text: widget.product.name);
    _imagePath = widget.product.image;
    // Group variants by color
    final byColor = <String, List<Variant>>{};
    for (final v in widget.product.variants) {
      byColor.putIfAbsent(v.color, () => []).add(v);
    }
    _groups = byColor.entries.map((e) => _ColorGroup(color: e.key, rows: e.value.map((v) => _SizeRow(id: v.id, size: v.size, price: v.price, stock: v.stock)).toList())).toList();
    if (_groups.isEmpty) _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final variants = <Map<String, dynamic>>[];
    for (final g in _groups) {
      if (g.color.trim().isEmpty) continue;
      for (final r in g.rows) {
        if (r.size.trim().isEmpty) continue;
        final m = <String, dynamic>{'color': g.color.trim(), 'size': r.size.trim(), 'price': r.price, 'stock': r.stock};
        if (r.id != null) m['id'] = r.id;
        variants.add(m);
      }
    }
    try {
      await ApiService.updateProduct(
        widget.product.id,
        code: _codeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        imagePath: _imagePath,
        variants: variants,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xác nhận xóa', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Xóa vĩnh viễn sản phẩm này?', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
                  ),
                  const SizedBox(width: 8),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Xóa'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await ApiService.deleteProduct(widget.product.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Chỉnh sửa: ${widget.product.name}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: kTextPrimary)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: kTextSecondary,
                    mouseCursor: SystemMouseCursors.click,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text('Cập nhật mã, màu, size, giá và tồn kho', style: TextStyle(color: kTextSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(width: 160, child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Mã hàng'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm'))),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    ..._groups.asMap().entries.map((entry) => _buildColorGroup(entry.key, entry.value)),
                    const SizedBox(height: 8),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]))),
                        child: const Text('+ Thêm Nhóm Màu'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ElevatedButton(onPressed: _save, child: const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 4),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  onPressed: _delete,
                  child: const Text('XÓA SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _duplicateColorGroup(int gi) {
    final original = _groups[gi];
    final newRows = original.rows.map((r) => _SizeRow(
      size: r.size,
      price: r.price,
      stock: r.stock,
    )).toList();
    final newGroup = _ColorGroup(
      color: '${original.color} (copy)',
      rows: newRows,
    );
    setState(() {
      _groups.insert(gi + 1, newGroup);
    });
  }

  Widget _buildColorGroup(int gi, _ColorGroup g) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(children: [
              const Text('Màu: '),
              Expanded(
                child: TextFormField(
                  initialValue: g.color,
                  decoration: const InputDecoration(hintText: 'Tên màu'),
                  onChanged: (v) => g.color = v,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tooltip(
                message: 'Nhân bản màu',
                    child: IconButton(
                  icon: const Icon(Icons.copy_all, size: 18, color: Colors.blue),
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () => _duplicateColorGroup(gi),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: kDanger),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => setState(() => _groups.removeAt(gi)),
              ),
            ]),
            const SizedBox(height: 4),
            ...g.rows.asMap().entries.map((e) => _buildSizeRow(g, e.key, e.value)),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(onPressed: () => setState(() => g.rows.add(_SizeRow())), child: const Text('+ Thêm Size')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeRow(_ColorGroup g, int ri, _SizeRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: TextFormField(
            initialValue: r.size,
            decoration: const InputDecoration(hintText: 'Size'),
            onChanged: (v) => r.size = v,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: _ScrollableNumberField(
          value: r.price,
          hintText: 'Giá',
          onChanged: (v) => setState(() => r.price = v),
          step: 1000,
          enableWheelAdjust: false,
        )),
        const SizedBox(width: 4),
        SizedBox(width: 90, child: _ScrollableNumberField(
          value: r.stock,
          hintText: 'Kho',
          onChanged: (v) => setState(() => r.stock = v),
          step: 1,
        )),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red, size: 16),
          mouseCursor: SystemMouseCursors.click,
          onPressed: () => setState(() => g.rows.removeAt(ri)),
        ),
      ]),
    );
  }
}

class _ScrollableNumberField extends StatefulWidget {
  final int value;
  final String hintText;
  final ValueChanged<int> onChanged;
  final int step;
  final bool enableWheelAdjust;

  const _ScrollableNumberField({
    required this.value,
    required this.hintText,
    required this.onChanged,
    this.step = 1,
    this.enableWheelAdjust = true,
  });

  @override
  State<_ScrollableNumberField> createState() => _ScrollableNumberFieldState();
}

class _ScrollableNumberFieldState extends State<_ScrollableNumberField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_ScrollableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final current = int.tryParse(_controller.text.replaceAll('.', '')) ?? 0;
      if (current != widget.value) {
        final nextText = '${widget.value}';
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

  void _increment() {
    final newValue = widget.value + widget.step;
    widget.onChanged(newValue);
  }

  void _decrement() {
    final newValue = (widget.value - widget.step).clamp(0, 999999999);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (!widget.enableWheelAdjust) return;
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
        focusNode: _focusNode,
        decoration: InputDecoration(hintText: widget.hintText),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          final parsed = int.tryParse(v.replaceAll('.', '')) ?? 0;
          widget.onChanged(parsed);
        },
      ),
    );
  }
}

class _ColorGroup {
  String color;
  List<_SizeRow> rows;
  _ColorGroup({required this.color, required this.rows});
}

class _SizeRow {
  int? id;
  String size;
  int price;
  int stock;
  _SizeRow({this.id, this.size = '', this.price = 0, this.stock = 0});
}
