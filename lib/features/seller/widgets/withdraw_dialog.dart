import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../data/seller_providers.dart';

/// Dialog nhập số tiền rút. Trả về true nếu gửi yêu cầu thành công.
class WithdrawDialog extends ConsumerStatefulWidget {
  const WithdrawDialog({super.key, required this.available});
  final double available;

  @override
  ConsumerState<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends ConsumerState<WithdrawDialog> {
  final _amount = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Nhập số tiền hợp lệ');
      return;
    }
    if (amount > widget.available) {
      setState(() => _error = 'Vượt quá số dư khả dụng');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(sellerRepoProvider).requestWithdraw(amount.toDouble());
      ref.invalidate(myWithdrawalsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yêu cầu rút tiền'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Số dư khả dụng: ${formatMoney(widget.available)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Số tiền muốn rút (đ)',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }
}