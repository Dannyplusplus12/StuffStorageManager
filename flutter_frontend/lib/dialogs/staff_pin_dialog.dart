import 'package:flutter/material.dart';
import '../utils/app_mode_manager.dart';

class StaffPinDialog extends StatefulWidget {
  const StaffPinDialog({super.key});

  @override
  State<StaffPinDialog> createState() => _StaffPinDialogState();
}

class _StaffPinDialogState extends State<StaffPinDialog> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onConfirm() async {
    if (_pinController.text.isEmpty) {
      setState(() => _errorMsg = 'Nhập mã PIN');
      return;
    }

    setState(() => _isLoading = true);
    
    bool success = await AppModeManager.verifyPin(_pinController.text);
    
    setState(() => _isLoading = false);
    
    if (success) {
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã kích hoạt chế độ MANAGER'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() => _errorMsg = 'PIN sai. Thử lại!');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🔐 Nhập mã PIN nhân viên'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '• • • •',
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              errorText: _errorMsg,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (_) => setState(() => _errorMsg = null),
            onSubmitted: (_) => _isLoading ? null : _onConfirm(),
          ),
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMsg!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _onConfirm,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}
