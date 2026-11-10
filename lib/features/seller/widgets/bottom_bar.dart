import 'package:flutter/material.dart';

/// Thanh dưới cùng kiểu Shopee: bên trái là tổng tiền, bên phải là nút to.
class ActionBottomBar extends StatelessWidget {
  const ActionBottomBar({
    super.key,
    required this.caption,
    required this.amount,
    required this.buttonLabel,
    required this.onPressed,
    this.note,
    this.busy = false,
    this.dimmed = false,
  });

  final String caption;
  final String amount;
  final String? note;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool busy;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      if (note != null)
                        Text(
                          note!,
                          style: TextStyle(fontSize: 11, color: cs.primary),
                        ),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: busy ? null : onPressed,
                child: Container(
                  width: 128,
                  color: dimmed ? Colors.grey.shade400 : cs.primary,
                  alignment: Alignment.center,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}