import 'package:flutter/material.dart';
import '../services/api_service.dart';
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
    try {
      final role = widget.requestedRole == AppMode.orderer ? 'orderer' : 'picker';
      final login = await ApiService.loginByPin(pin: _pinController.text.trim(), requestedRole: role);
      await AppModeManager.setSession(
        widget.requestedRole,
        employeeId: (login['id'] ?? 0) as int,
        employeeName: (login['name'] ?? '').toString(),
        employeeRole: (login['role'] ?? '').toString(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() => _errorMsg = 'PIN sai. Thử lại!');
      _pinController.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        MouseRegion(
          cursor: _isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
        ),
        MouseRegion(
          cursor: _isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onConfirm,
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Xác nhận'),
          ),
        ),
      ],
    );
  }
}

// backward compat alias
class StaffPinDialog extends RolePinDialog {
  const StaffPinDialog({super.key}) : super(requestedRole: AppMode.orderer);
}
