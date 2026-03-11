import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../models/product.dart' show Product, Variant;
import '../services/api_service.dart';

class EditProductDialog extends StatefulWidget {
  final Product product;
  const EditProductDialog({super.key, required this.product});
  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  late final TextEditingController _nameCtrl;
  late String _imagePath;
  late List<_ColorGroup> _groups;

  @override
  void initState() {
    super.initState();
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
      await ApiService.updateProduct(widget.product.id, name: _nameCtrl.text.trim(), imagePath: _imagePath, variants: variants);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Xác nhận xóa'),
      content: const Text('Xóa vĩnh viễn sản phẩm này?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Có'))],
    ));
    if (ok == true) {
      await ApiService.deleteProduct(widget.product.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Chỉnh sửa: ${widget.product.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm')),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    ..._groups.asMap().entries.map((entry) => _buildColorGroup(entry.key, entry.value)),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: () => setState(() => _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]))), child: const Text('+ Thêm Nhóm Màu')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _save, child: const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                onPressed: _delete,
                child: const Text('XÓA SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(children: [
              const Text('Màu: '),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: g.color),
                  decoration: const InputDecoration(hintText: 'Tên màu'),
                  onChanged: (v) => g.color = v,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tooltip(
                message: 'Nhân bản màu',
                child: IconButton(
                  icon: const Icon(Icons.copy_all, size: 18, color: Colors.blue),
                  onPressed: () => _duplicateColorGroup(gi),
                ),
              ),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _groups.removeAt(gi))),
            ]),
            const SizedBox(height: 4),
            ...g.rows.asMap().entries.map((e) => _buildSizeRow(g, e.key, e.value)),
            TextButton(onPressed: () => setState(() => g.rows.add(_SizeRow())), child: const Text('+ Thêm Size')),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeRow(_ColorGroup g, int ri, _SizeRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 60, child: TextField(controller: TextEditingController(text: r.size), decoration: const InputDecoration(hintText: 'Size'), onChanged: (v) => r.size = v)),
        const SizedBox(width: 4),
        Expanded(child: _ScrollableNumberField(
          value: r.price,
          hintText: 'Giá',
          onChanged: (v) => setState(() => r.price = v),
          step: 1000,
        )),
        const SizedBox(width: 4),
        SizedBox(width: 60, child: _ScrollableNumberField(
          value: r.stock,
          hintText: 'Kho',
          onChanged: (v) => setState(() => r.stock = v),
          step: 1,
        )),
        IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 16), onPressed: () => setState(() => g.rows.removeAt(ri))),
      ]),
    );
  }
}

class _ScrollableNumberField extends StatefulWidget {
  final int value;
  final String hintText;
  final ValueChanged<int> onChanged;
  final int step;

  const _ScrollableNumberField({
    required this.value,
    required this.hintText,
    required this.onChanged,
    this.step = 1,
  });

  @override
  State<_ScrollableNumberField> createState() => _ScrollableNumberFieldState();
}

class _ScrollableNumberFieldState extends State<_ScrollableNumberField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_ScrollableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
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
