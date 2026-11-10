import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> _editQty(
  BuildContext context,
  int value,
  ValueChanged<int> onChanged,
) async {
  final v = await showDialog<int>(
    context: context,
    builder: (_) => _QtyDialog(initial: value),
  );
  if (v != null) onChanged(math.min(9999, math.max(0, v)));
}

/// Bộ chỉnh số lượng kiểu Shopee: khung viền  −  |  số  |  +
/// Bấm vào con số để gõ trực tiếp (vd 50). Giảm về 0 thì bỏ dòng đó.
class QtyBox extends StatelessWidget {
  const QtyBox({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final line = BorderSide(color: Colors.grey.shade400);
    return Container(
      height: 30,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Cell(
            onTap: value > 0 ? () => onChanged(value - 1) : null,
            icon: Icons.remove,
          ),
          Container(
            decoration: BoxDecoration(border: Border(left: line, right: line)),
            child: InkWell(
              onTap: () => _editQty(context, value, onChanged),
              child: SizedBox(
                width: 40,
                height: 30,
                child: Center(
                  child: Text('$value', style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ),
          _Cell(onTap: () => onChanged(value + 1), icon: Icons.add),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.onTap, required this.icon});
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? Colors.grey.shade400 : Colors.black87,
          ),
        ),
      );
}

/// Bản gọn cũ (nút tròn). Vẫn giữ lại để các chỗ khác dùng nếu cần.
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _editQty(context, value, onChanged),
            child: Container(
              constraints: const BoxConstraints(minWidth: 32),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      );
}

class _QtyDialog extends StatefulWidget {
  const _QtyDialog({required this.initial});
  final int initial;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial == 0 ? '' : '${widget.initial}',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Nhập số lượng'),
        content: TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (s) => Navigator.pop(context, int.tryParse(s)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(_ctrl.text)),
            child: const Text('OK'),
          ),
        ],
      );
}