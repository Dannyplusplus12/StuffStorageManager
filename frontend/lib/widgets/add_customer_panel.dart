import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddCustomerPanel extends StatefulWidget {
  final VoidCallback onAdded;
  const AddCustomerPanel({super.key, required this.onAdded});
  @override
  State<AddCustomerPanel> createState() => _AddCustomerPanelState();
}

class _AddCustomerPanelState extends State<AddCustomerPanel> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _debtCtrl = TextEditingController(text: '0');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _debtCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên'), backgroundColor: Colors.red));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final areas = await ApiService.getAreas();
      if (areas.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Chưa có khu vực. Vui lòng tạo khu vực trước.'), backgroundColor: Colors.red));
        return;
      }
      await ApiService.createCustomer(
        name: name,
        phone: _phoneCtrl.text.trim(),
        debt: int.tryParse(_debtCtrl.text.replaceAll('.', '')) ?? 0,
        areaId: areas.first.id,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Đã thêm khách hàng mới!'), backgroundColor: Colors.green));
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _debtCtrl.text = '0';
      widget.onAdded();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Text('Tên khách hàng (*):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'VD: Anh Tuấn'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Số điện thoại:'),
          const SizedBox(height: 4),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(hintText: 'VD: 0912345678'), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          const Text('Dư nợ ban đầu (VNĐ):'),
          const SizedBox(height: 4),
          TextField(controller: _debtCtrl, decoration: const InputDecoration(hintText: '0'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(
            height: 45,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ElevatedButton(onPressed: _save, child: const Text('Lưu Khách Hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
