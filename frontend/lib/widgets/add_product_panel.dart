import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils.dart';

class AddProductPanel extends StatefulWidget {
  final VoidCallback onAdded;
  const AddProductPanel({super.key, required this.onAdded});
  @override
  State<AddProductPanel> createState() => _AddProductPanelState();
}

class _AddProductPanelState extends State<AddProductPanel> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();
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
    _codeFocus.dispose();
    _nameFocus.dispose();
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  void _reset() {
    _codeCtrl.clear();
    _nameCtrl.clear();
    _imagePath = '';
    _previewImagePath = null;
    for (final g in _groups) {
      g.dispose();
    }
    _groups.clear();
    _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
    setState(() {});
  }

  KeyEventResult _handleNavKey(
    KeyEvent event, {
    required VoidCallback onForward,
    required VoidCallback onBackward,
    VoidCallback? onShiftEnter,
    VoidCallback? onCtrlForward,
    VoidCallback? onCtrlBackward,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    final isEnter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    if (isEnter) {
      if (isShift) {
        (onShiftEnter ?? onForward)();
      } else {
        onForward();
      }
      return KeyEventResult.handled;
    }

    if (isCtrl && key == LogicalKeyboardKey.arrowRight) {
      (onCtrlForward ?? onForward)();
      return KeyEventResult.handled;
    }
    if (isCtrl && key == LogicalKeyboardKey.arrowLeft) {
      (onCtrlBackward ?? onBackward)();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusColorExisting(int gi) {
    if (gi < 0) {
      _nameFocus.requestFocus();
      return;
    }
    if (gi >= _groups.length) return;
    _groups[gi].colorFocus.requestFocus();
  }

  void _focusSizeExisting(int gi, int ri) {
    if (gi < 0 || gi >= _groups.length) {
      _focusColorExisting(gi);
      return;
    }
    if (ri >= 0 && ri < _groups[gi].rows.length) {
      _groups[gi].rows[ri].sizeFocus.requestFocus();
      return;
    }
    _focusColorExisting(gi + 1);
  }

  void _focusColor(int gi) {
    if (gi < 0) {
      _nameFocus.requestFocus();
      return;
    }
    if (gi >= _groups.length) {
      setState(() => _groups.add(_ColorGroup(color: '', rows: [_SizeRow()])));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _groups.last.colorFocus.requestFocus();
      });
      return;
    }
    _groups[gi].colorFocus.requestFocus();
  }

  void _focusSize(int gi, int ri) {
    if (gi < 0) {
      _nameFocus.requestFocus();
      return;
    }
    if (gi >= _groups.length) {
      setState(() => _groups.add(_ColorGroup(color: '', rows: [_SizeRow()])));
    }
    while (_groups[gi].rows.length <= ri) {
      _groups[gi].rows.add(_SizeRow());
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _groups[gi].rows[ri].sizeFocus.requestFocus();
    });
  }

  void _onColorChanged(int gi, String value) {
    final g = _groups[gi];
    g.color = value;
    if (value.trim().isNotEmpty && !g.autoAddedNextColor) {
      g.autoAddedNextColor = true;
      _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
    }
    setState(() {});
  }

  void _onSizeChanged(_ColorGroup g, int ri, String value) {
    final row = g.rows[ri];
    row.size = value;
    if (value.trim().isNotEmpty && !row.autoAddedNextSize) {
      row.autoAddedNextSize = true;
      g.rows.add(_SizeRow());
    }
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

  void _removeColorGroup(int gi) {
    if (gi < 0 || gi >= _groups.length) return;
    final removed = _groups.removeAt(gi);
    final removedWasFocused = removed.colorFocus.hasFocus ||
        removed.rows.any((r) => r.sizeFocus.hasFocus || r.stockFocus.hasFocus || r.priceFocus.hasFocus);

    if (_groups.isEmpty) {
      _groups.add(_ColorGroup(color: '', rows: [_SizeRow()]));
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed.dispose();
    });

    if (removedWasFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _groups.isEmpty) return;
        final nextIndex = gi >= _groups.length ? _groups.length - 1 : gi;
        _groups[nextIndex].colorFocus.requestFocus();
      });
    }
  }

  void _removeSizeRow(_ColorGroup g, int ri) {
    if (ri < 0 || ri >= g.rows.length) return;
    final removed = g.rows.removeAt(ri);
    final removedWasFocused = removed.sizeFocus.hasFocus || removed.stockFocus.hasFocus || removed.priceFocus.hasFocus;

    if (g.rows.isEmpty) {
      g.rows.add(_SizeRow());
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      removed.dispose();
    });

    if (removedWasFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || g.rows.isEmpty) return;
        final nextIndex = ri >= g.rows.length ? g.rows.length - 1 : ri;
        g.rows[nextIndex].sizeFocus.requestFocus();
      });
    }
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final previewPath = _previewImagePath;
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
      var imagePath = _imagePath;
      if (previewPath != null && imagePath.isNotEmpty && !imagePath.startsWith('/product-images/')) {
        imagePath = await ApiService.uploadProductImage(File(previewPath));
      }
      await ApiService.createProduct(code: code, name: name, imagePath: imagePath, variants: variants);
      widget.onAdded();
      _reset();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm sản phẩm mới'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelSoftBg = appPanelSoftBg(context);
    final borderColor = appBorderColor(context);
    final textPrimary = appTextPrimary(context);
    final textSecondary = appTextSecondary(context);
    final panelHeight = (MediaQuery.of(context).size.height - 120).clamp(480.0, 1200.0);
    final panelWidth = MediaQuery.of(context).size.width;
    final leftPanelWidth = (panelWidth * 0.26).clamp(240.0, 300.0);
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
                  width: leftPanelWidth,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final previewHeight = (constraints.maxHeight * 0.28).clamp(140.0, 220.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: panelSoftBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Ảnh sản phẩm', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: previewHeight,
                                  child: AspectRatio(
                                    aspectRatio: kProductImageAspect,
                                    child: Container(
                                      decoration: BoxDecoration(color: panelSoftBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
                                      child: _previewImagePath == null
                                          ? Center(child: Text('Chưa chọn ảnh', style: TextStyle(color: textSecondary)))
                                          : ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                File(_previewImagePath!),
                                                fit: BoxFit.cover,
                                                alignment: Alignment.center,
                                                errorBuilder: (_, __, ___) => Center(child: Text('Không tải được ảnh', style: TextStyle(color: textSecondary))),
                                              ),
                                            ),
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
                        decoration: BoxDecoration(color: panelSoftBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tóm tắt nhanh', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                            const SizedBox(height: 8),
                            Text('• Nhóm màu: $colorCount', style: TextStyle(color: textSecondary)),
                            Text('• Biến thể size: $variantCount', style: TextStyle(color: textSecondary)),
                            Text('• Ảnh: ${_previewImagePath == null ? 'Chưa có' : 'Đã chọn'}', style: TextStyle(color: textSecondary)),
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
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nhập hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text('Tạo mẫu giày mới với mã hàng, ảnh và biến thể màu/size', style: TextStyle(color: textSecondary)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: panelSoftBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Thông tin mẫu', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 240,
                                  child: Focus(
                                    canRequestFocus: false,
                                    onKeyEvent: (node, event) => _handleNavKey(
                                      event,
                                      onForward: () => _nameFocus.requestFocus(),
                                      onBackward: () => _codeFocus.requestFocus(),
                                      onCtrlForward: () => _nameFocus.requestFocus(),
                                      onCtrlBackward: () => _codeFocus.requestFocus(),
                                    ),
                                    child: TextField(
                                      controller: _codeCtrl,
                                      focusNode: _codeFocus,
                                      decoration: const InputDecoration(labelText: 'Mã hàng (*)', hintText: 'VD: CHUCAO'),
                                      onSubmitted: (_) => _nameFocus.requestFocus(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Focus(
                                    canRequestFocus: false,
                                    onKeyEvent: (node, event) => _handleNavKey(
                                      event,
                                      onForward: () => _focusColor(0),
                                      onBackward: () => _codeFocus.requestFocus(),
                                      onCtrlForward: () => _focusColorExisting(0),
                                      onCtrlBackward: () => _codeFocus.requestFocus(),
                                    ),
                                    child: TextField(
                                      controller: _nameCtrl,
                                      focusNode: _nameFocus,
                                      decoration: const InputDecoration(labelText: 'Tên giày (*)', hintText: 'Tên sản phẩm...'),
                                      onSubmitted: (_) => _focusColor(0),
                                    ),
                                  ),
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
                          decoration: BoxDecoration(color: panelSoftBg, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Biến thể màu & size', style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary)),
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
      key: ValueKey('group_${g.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: appPanelSoftBg(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: appBorderColor(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(children: [
              const Text('Màu: '),
              Expanded(
                child: Focus(
                  canRequestFocus: false,
                  onKeyEvent: (node, event) => _handleNavKey(
                    event,
                    onForward: () => _focusSize(gi, 0),
                    onBackward: () => _focusColor(gi - 1),
                    onShiftEnter: () => _focusColor(gi + 1),
                    onCtrlForward: () => _focusSizeExisting(gi, 0),
                    onCtrlBackward: () => _focusColorExisting(gi - 1),
                  ),
                  child: TextFormField(
                    focusNode: g.colorFocus,
                    initialValue: g.color,
                    decoration: const InputDecoration(hintText: 'Tên màu'),
                    onChanged: (v) => _onColorChanged(gi, v),
                    onFieldSubmitted: (_) => _focusSize(gi, 0),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                onPressed: () => _removeColorGroup(gi),
              ),
            ]),
            const SizedBox(height: 4),
            ...g.rows.asMap().entries.map((e) => _buildRow(gi, g, e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int gi, _ColorGroup g, int ri, _SizeRow r) {
    return Padding(
      key: ValueKey('row_${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 108,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (node, event) => _handleNavKey(
              event,
              onForward: () => r.stockFocus.requestFocus(),
              onBackward: () => (ri == 0 ? g.colorFocus : g.rows[ri - 1].priceFocus).requestFocus(),
              onShiftEnter: () => _focusColor(gi + 1),
              onCtrlForward: () => r.stockFocus.requestFocus(),
              onCtrlBackward: () => (ri == 0 ? g.colorFocus : g.rows[ri - 1].priceFocus).requestFocus(),
            ),
            child: TextFormField(
              focusNode: r.sizeFocus,
              initialValue: r.size,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Size',
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
              onChanged: (v) => _onSizeChanged(g, ri, v),
              onFieldSubmitted: (_) => r.stockFocus.requestFocus(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 117,
          child: _ScrollableNumberField(
            value: r.stock,
            hintText: 'SL',
            onChanged: (v) => setState(() => r.stock = v),
            step: 1,
            focusNode: r.stockFocus,
            onForward: () => r.priceFocus.requestFocus(),
            onBackward: () => r.sizeFocus.requestFocus(),
            onShiftEnter: () => _focusColor(gi + 1),
            onCtrlForward: () => r.priceFocus.requestFocus(),
            onCtrlBackward: () => r.sizeFocus.requestFocus(),
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
          enableWheelAdjust: false,
          focusNode: r.priceFocus,
          onForward: () => _focusSize(gi, ri + 1),
          onBackward: () => r.stockFocus.requestFocus(),
          onShiftEnter: () => _focusColor(gi + 1),
          onCtrlForward: () => _focusSizeExisting(gi, ri + 1),
          onCtrlBackward: () => r.stockFocus.requestFocus(),
        )),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red, size: 16),
          mouseCursor: SystemMouseCursors.click,
          onPressed: () => _removeSizeRow(g, ri),
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
  final FocusNode? focusNode;
  final VoidCallback? onForward;
  final VoidCallback? onBackward;
  final VoidCallback? onShiftEnter;
  final VoidCallback? onCtrlForward;
  final VoidCallback? onCtrlBackward;
  final EdgeInsetsGeometry? contentPadding;
  final TextAlign textAlign;

  const _ScrollableNumberField({
    required this.value,
    required this.hintText,
    required this.onChanged,
    this.step = 1,
    this.enableWheelAdjust = true,
    this.focusNode,
    this.onForward,
    this.onBackward,
    this.onShiftEnter,
    this.onCtrlForward,
    this.onCtrlBackward,
    this.contentPadding,
    this.textAlign = TextAlign.start,
  });

  @override
  State<_ScrollableNumberField> createState() => _ScrollableNumberFieldState();
}

class _ScrollableNumberFieldState extends State<_ScrollableNumberField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late final bool _ownFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value > 0 ? '${widget.value}' : '');
    _ownFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(_ScrollableNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final current = int.tryParse(_controller.text.replaceAll('.', '')) ?? 0;
      if (current != widget.value) {
        final nextText = widget.value > 0 ? '${widget.value}' : '';
        _controller.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_ownFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    final isEnter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    if (isEnter) {
      if (isShift) {
        (widget.onShiftEnter ?? widget.onForward)?.call();
      } else {
        widget.onForward?.call();
      }
      return KeyEventResult.handled;
    }
    if (isCtrl && key == LogicalKeyboardKey.arrowRight) {
      (widget.onCtrlForward ?? widget.onForward)?.call();
      return KeyEventResult.handled;
    }
    if (isCtrl && key == LogicalKeyboardKey.arrowLeft) {
      (widget.onCtrlBackward ?? widget.onBackward)?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (node, event) => _onKeyEvent(event),
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
      ),
    );
  }
}

class _ColorGroup {
  static int _idSeed = 0;
  final int id = _idSeed++;
  String color;
  List<_SizeRow> rows;
  final FocusNode colorFocus = FocusNode();
  bool autoAddedNextColor = false;
  _ColorGroup({
    required this.color,
    required this.rows,
  });

  void dispose() {
    colorFocus.dispose();
    for (final r in rows) {
      r.dispose();
    }
  }
}

class _SizeRow {
  static int _idSeed = 0;
  final int id = _idSeed++;
  String size = '';
  int price = 0;
  int stock = 0;
  final FocusNode sizeFocus = FocusNode();
  final FocusNode stockFocus = FocusNode();
  final FocusNode priceFocus = FocusNode();
  bool autoAddedNextSize = false;

  void dispose() {
    sizeFocus.dispose();
    stockFocus.dispose();
    priceFocus.dispose();
  }
}
