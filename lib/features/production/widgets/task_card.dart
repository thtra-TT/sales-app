import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../models/models.dart';
import '../../seller/widgets/status_chip.dart';

/// 1 thẻ = 1 sản phẩm (item) cần làm của 1 đơn.
/// Đổi trạng thái bằng 1 chạm vào thanh 3 nút ở dưới.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.updating,
    required this.onStatusChanged,
  });

  final ProductionTask task;
  final bool updating;
  final ValueChanged<ProductionStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mã đơn + trạng thái hiện tại
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.orderCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                productionChip(task.productionStatus),
              ],
            ),
            const SizedBox(height: 10),

            // Sản phẩm - mục - số lượng
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.productName, style: tt.titleMedium),
                      const SizedBox(height: 2),
                      Text(task.itemName),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '× ${task.quantity}',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Đơn thanh toán lúc ${formatDateTime(task.paidAt)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // Cập nhật trạng thái
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ProductionStatus>(
                showSelectedIcon: false,
                segments: <ButtonSegment<ProductionStatus>>[
                  for (final s in ProductionStatus.values)
                    ButtonSegment<ProductionStatus>(
                      value: s,
                      label: Text(s.label, style: const TextStyle(fontSize: 12)),
                    ),
                ],
                selected: {task.productionStatus},
                onSelectionChanged: updating
                    ? null
                    : (set) {
                        final s = set.first;
                        if (s != task.productionStatus) onStatusChanged(s);
                      },
              ),
            ),
            if (updating)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
    );
  }
}