import 'package:flutter/material.dart';

import '../../../models/models.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

StatusChip paymentChip(PaymentStatus s) => StatusChip(
      label: s.label,
      color: s == PaymentStatus.paid
          ? Colors.green.shade700
          : Colors.orange.shade800,
    );

StatusChip deliveryChip(DeliveryStatus s) => StatusChip(
      label: s.label,
      color: s == DeliveryStatus.delivered
          ? Colors.teal.shade700
          : Colors.blueGrey.shade600,
    );

StatusChip productionChip(ProductionStatus s) => StatusChip(
      label: s.label,
      color: switch (s) {
        ProductionStatus.pending => Colors.blueGrey.shade600,
        ProductionStatus.inProgress => Colors.blue.shade700,
        ProductionStatus.done => Colors.green.shade700,
      },
    );

StatusChip withdrawChip(WithdrawStatus s) => StatusChip(
      label: s.label,
      color: switch (s) {
        WithdrawStatus.pending => Colors.orange.shade800,
        WithdrawStatus.approved => Colors.green.shade700,
        WithdrawStatus.rejected => Colors.red.shade700,
      },
    );