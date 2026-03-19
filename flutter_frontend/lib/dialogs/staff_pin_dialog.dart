import 'package:flutter/material.dart';
import '../utils/app_mode_manager.dart';

class RolePinDialog extends StatefulWidget {
  final AppMode requestedRole;
  const RolePinDialog({super.key, required this.requestedRole});

  @override
  State<RolePinDialog> createState() => _RolePinDialogState();
}

class _RolePinDialogState extends State<RolePinDialog> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  String get _roleLabel =>
      widget.requestedRole == AppMode.orderer ? 'Người soạn đơn' : 'Người soạn hàng';

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
    final success = await AppModeManager.verifyPin(_pinController.text, widget.requestedRole);
    setState(() => _isLoading = false);
    if (success) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _errorMsg = 'PIN sai. Thử lại!');
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('🔐 PIN — $_roleLabel'),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}

// backward compat alias
class StaffPinDialog extends RolePinDialog {
  const StaffPinDialog({super.key}) : super(requestedRole: AppMode.orderer);
}
