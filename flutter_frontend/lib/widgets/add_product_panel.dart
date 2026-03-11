import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../services/api_service.dart';

class AddProductPanel extends StatefulWidget {
  final VoidCallback onAdded;
  const AddProductPanel({super.key, required this.onAdded});
  @override
  State<AddProductPanel> createState() => _AddProductPanelState();
}

class _AddProductPanelState extends State<AddProductPanel> {
  final _nameCtrl = TextEditingController();
  String _imagePath = '';
  final List<_ColorGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    _nameCtrl.clear();
    _imagePath = '';
    _groups.clear();
    _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
    setState(() {});
  }

  void _duplicateColorGroup(int gi) {
    final original = _groups[gi];
    final newRows = original.rows.map((r) => _SizeRow()
      ..size = r.size
      ..price = r.price
      ..stock = r.stock
    ).toList();
    final newGroup = _ColorGroup(
      color: '${original.color} (copy)',
      rows: newRows,
    );
    setState(() {
      _groups.insert(gi + 1, newGroup);
    });
  }

  Future<void> _save() async {
    final variants = <Map<String, dynamic>>[];
    for (final g in _groups) {
      if (g.color.trim().isEmpty) continue;
      for (final r in g.rows) {
        if (r.size.trim().isEmpty) continue;
        variants.add({'color': g.color.trim(), 'size': r.size.trim(), 'price': r.price, 'stock': r.stock});
      }
    }
    if (variants.isEmpty) return;
    try {
      await ApiService.createProduct(name: _nameCtrl.text.trim(), imagePath: _imagePath, variants: variants);
      widget.onAdded();
      _reset();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Thêm sản phẩm mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Tên giày...')),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                ..._groups.asMap().entries.map((e) => _buildGroup(e.key, e.value)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => setState(() => _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]))), child: const Text('+ Nhóm Màu')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 45,
            child: ElevatedButton(onPressed: _save, child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(int gi, _ColorGroup g) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(children: [
              const Text('Màu: '),
              Expanded(child: TextField(
                controller: TextEditingController(text: g.color),
                decoration: const InputDecoration(hintText: 'Tên màu'),
                onChanged: (v) => g.color = v,
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
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
            ...g.rows.asMap().entries.map((e) => _buildRow(g, e.key, e.value)),
            TextButton(onPressed: () => setState(() => g.rows.add(_SizeRow())), child: const Text('+ Thêm Size')),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_ColorGroup g, int ri, _SizeRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 55, child: TextField(controller: TextEditingController(text: r.size), decoration: const InputDecoration(hintText: 'Size'), onChanged: (v) => r.size = v)),
        const SizedBox(width: 4),
        Expanded(child: _ScrollableNumberField(
          value: r.price,
          hintText: 'Giá',
          onChanged: (v) => setState(() => r.price = v),
          step: 1000,
        )),
        const SizedBox(width: 4),
        SizedBox(width: 55, child: _ScrollableNumberField(
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
    _controller = TextEditingController(text: widget.value > 0 ? '${widget.value}' : '');
  }

  @override
  void didUpdateWidget(_ScrollableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value > 0 ? '${widget.value}' : '';
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
  String size = '';
  int price = 0;
  int stock = 0;
}
