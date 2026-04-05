import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class EditLogDialog extends StatefulWidget {
  final int custId;
  final Map<String, dynamic>? data; // null = create, non-null = edit
  const EditLogDialog({super.key, required this.custId, this.data});
  @override
  State<EditLogDialog> createState() => _EditLogDialogState();
}

class _EditLogDialogState extends State<EditLogDialog> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amtCtrl;
  late final TextEditingController _dtCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _descCtrl = TextEditingController(text: d?['desc'] ?? '');
    final amt = d?['amount'];
    _amtCtrl = TextEditingController(text: amt != null ? '$amt' : '');
    _dtCtrl = TextEditingController(text: d?['date'] ?? _nowStr());
  }

  String _nowStr() {
    final n = DateTime.now();
    return '${n.year}-${_z(n.month)}-${_z(n.day)} ${_z(n.hour)}:${_z(n.minute)}';
  }

  String _z(int v) => v.toString().padLeft(2, '0');

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    _dtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = int.tryParse(_amtCtrl.text.replaceAll('.', ''));
    if (amt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ'), backgroundColor: Colors.red));
      return;
    }
    try {
      final dt = _dtCtrl.text.trim().isEmpty ? null : _dtCtrl.text.trim();
      final logId = widget.data?['log_id'];
      if (logId != null) {
        await ApiService.updateDebtLog(widget.custId, logId, changeAmount: amt, note: _descCtrl.text.trim(), createdAt: dt);
      } else {
        await ApiService.createDebtLog(widget.custId, changeAmount: amt, note: _descCtrl.text.trim(), createdAt: dt);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.data != null ? 'Sửa điều chỉnh' : 'Thêm điều chỉnh công nợ',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                  color: kTextSecondary,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text('Nhập số âm để thu tiền, số dương để tăng nợ', style: TextStyle(color: kTextSecondary)),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Nội dung')),
            const SizedBox(height: 8),
            TextField(controller: _amtCtrl, decoration: const InputDecoration(labelText: 'Số tiền (VD: -100000 hoặc 100000)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: _dtCtrl, decoration: const InputDecoration(labelText: 'Ngày giờ (YYYY-MM-DD HH:MM)')),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton(onPressed: _save, child: const Text('Lưu điều chỉnh')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
