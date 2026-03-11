import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
    return AlertDialog(
      title: Text(widget.data != null ? 'Sửa điều chỉnh' : 'Thêm điều chỉnh công nợ'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Nội dung')),
          const SizedBox(height: 8),
          TextField(controller: _amtCtrl, decoration: const InputDecoration(labelText: 'Số tiền (VD: -100000 hoặc 100000)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: _dtCtrl, decoration: const InputDecoration(labelText: 'Ngày giờ (YYYY-MM-DD HH:MM)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        ElevatedButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
