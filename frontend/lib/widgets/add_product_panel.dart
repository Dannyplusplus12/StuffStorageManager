import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme.dart';

class AddProductPanel extends StatefulWidget {
  final VoidCallback onAdded;
  const AddProductPanel({super.key, required this.onAdded});
  @override
  State<AddProductPanel> createState() => _AddProductPanelState();
}

class _AddProductPanelState extends State<AddProductPanel> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _imagePath = '';
  String? _previewImagePath;
  final List<_ColorGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _reset() {
    _codeCtrl.clear();
    _nameCtrl.clear();
    _imagePath = '';
    _previewImagePath = null;
    _groups.clear();
    _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
    setState(() {});
  }

  String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;

  Future<void> _pickImageFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'images', extensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp']),
        ],
        confirmButtonText: 'Chọn ảnh',
      );
      if (file == null) return;

      final source = File(file.path);
      if (!await source.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy file ảnh đã chọn'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final targetDir = Directory('${Directory.current.path}${Platform.pathSeparator}assets${Platform.pathSeparator}images');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final absSource = source.absolute.path.replaceAll('\\', '/');
      final absTarget = targetDir.absolute.path.replaceAll('\\', '/');

      String relativePath;
      String previewPath;

      if (absSource.startsWith(absTarget)) {
        final fileName = _fileName(source.path);
        relativePath = 'assets/images/$fileName';
        previewPath = source.path;
      } else {
        final fileName = _fileName(source.path);
        final dot = fileName.lastIndexOf('.');
        final name = dot > 0 ? fileName.substring(0, dot) : fileName;
        final ext = dot > 0 ? fileName.substring(dot) : '';
        final unique = '${name}_${DateTime.now().millisecondsSinceEpoch}$ext';
        final dest = File('${targetDir.path}${Platform.pathSeparator}$unique');
        await source.copy(dest.path);
        relativePath = 'assets/images/$unique';
        previewPath = dest.path;
      }

      setState(() {
        _imagePath = relativePath;
        _previewImagePath = previewPath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _duplicateColorGroup(int gi) {
    final original = _groups[gi];
    final newRows = original.rows
        .map((r) => _SizeRow()
          ..size = r.size
          ..price = r.price
          ..stock = r.stock)
        .toList();
    final newGroup = _ColorGroup(
      color: '${original.color} (copy)',
      rows: newRows,
    );
    setState(() {
      _groups.insert(gi + 1, newGroup);
    });
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập mã hàng'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên sản phẩm'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final variants = <Map<String, dynamic>>[];
    for (final g in _groups) {
      if (g.color.trim().isEmpty) continue;
      for (final r in g.rows) {
        if (r.size.trim().isEmpty) continue;
        variants.add({'color': g.color.trim(), 'size': r.size.trim(), 'price': r.price, 'stock': r.stock});
      }
    }

    if (variants.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng thêm ít nhất 1 màu/size hợp lệ'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await ApiService.createProduct(code: code, name: name, imagePath: _imagePath, variants: variants);
      widget.onAdded();
      _reset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = (MediaQuery.of(context).size.height - 120).clamp(580.0, 1200.0);
    final colorCount = _groups.where((g) => g.color.trim().isNotEmpty).length;
    final variantCount = _groups.fold<int>(0, (s, g) => s + g.rows.where((r) => r.size.trim().isNotEmpty).length);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: panelHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Ảnh sản phẩm', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary)),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
                              child: _previewImagePath == null
                                  ? const Center(child: Text('Chưa chọn ảnh', style: TextStyle(color: Colors.grey)))
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_previewImagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: Text('Không tải được ảnh', style: TextStyle(color: Colors.grey))),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ElevatedButton.icon(onPressed: _pickImageFile, icon: const Icon(Icons.upload_file, size: 16), label: const Text('Tải ảnh')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tóm tắt nhanh', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary)),
                            const SizedBox(height: 8),
                            Text('• Nhóm màu: $colorCount', style: const TextStyle(color: kTextSecondary)),
                            Text('• Biến thể size: $variantCount', style: const TextStyle(color: kTextSecondary)),
                            Text('• Ảnh: ${_previewImagePath == null ? 'Chưa có' : 'Đã chọn'}', style: const TextStyle(color: kTextSecondary)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 56,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined, size: 20),
                            label: const Text('Lưu sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nhập hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: kTextPrimary)),
                      const SizedBox(height: 2),
                      const Text('Tạo mẫu giày mới với mã hàng, ảnh và biến thể màu/size', style: TextStyle(color: kTextSecondary)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Thông tin mẫu', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 240,
                                  child: TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Mã hàng (*)', hintText: 'VD: CHUCAO')),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên giày (*)', hintText: 'Tên sản phẩm...')),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Biến thể màu & size', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView(
                                  children: [
                                    ..._groups.asMap().entries.map((e) => _buildGroup(e.key, e.value)),
                                    const SizedBox(height: 6),
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: OutlinedButton.icon(
                                        onPressed: () => setState(() => _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]))),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Thêm màu'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
              Expanded(
                child: TextFormField(
                  initialValue: g.color,
                  decoration: const InputDecoration(hintText: 'Tên màu'),
                  onChanged: (v) => g.color = v,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: () => setState(() => g.rows.add(_SizeRow())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Size'),
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
                icon: const Icon(Icons.delete, color: Colors.red),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => setState(() => _groups.removeAt(gi)),
              ),
            ]),
            const SizedBox(height: 4),
            ...g.rows.asMap().entries.map((e) => _buildRow(g, e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(_ColorGroup g, int ri, _SizeRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 72,
          child: TextFormField(
            initialValue: r.size,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Size',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            onChanged: (v) => r.size = v,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 78,
          child: _ScrollableNumberField(
            value: r.stock,
            hintText: 'SL',
            onChanged: (v) => setState(() => r.stock = v),
            step: 1,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: _ScrollableNumberField(
          value: r.price,
          hintText: 'Giá',
          onChanged: (v) => setState(() => r.price = v),
          step: 1000,
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
  final EdgeInsetsGeometry? contentPadding;
  final TextAlign textAlign;

  const _ScrollableNumberField({
    required this.value,
    required this.hintText,
    required this.onChanged,
    this.step = 1,
    this.contentPadding,
    this.textAlign = TextAlign.start,
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
    _controller = TextEditingController(text: widget.value > 0 ? '${widget.value}' : '');
  }

  @override
  void didUpdateWidget(_ScrollableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value > 0 ? '${widget.value}' : '';
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
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText,
          contentPadding: widget.contentPadding,
        ),
        textAlign: widget.textAlign,
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
