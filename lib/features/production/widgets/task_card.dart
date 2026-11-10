import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../models/models.dart';
import '../../seller/widgets/product_image.dart';
import '../../seller/widgets/status_chip.dart';

/// 1 thẻ = 1 sản phẩm (item) cần làm của 1 đơn, có ảnh.
/// Trạng thái chỉ đi tới: Chưa làm -> Đang làm -> Hoàn thành. Các bước đã qua
/// bị khóa, khi đã hoàn thành thì không đổi được nữa.
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

  Widget _control() {
    final cur = task.productionStatus;

    if (cur == ProductionStatus.done) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 8),
            Text(
              'Đã hoàn thành',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ProductionStatus>(
        showSelectedIcon: false,
        segments: <ButtonSegment<ProductionStatus>>[
          for (final s in ProductionStatus.values)
            ButtonSegment<ProductionStatus>(
              value: s,
              enabled: s.index >= cur.index, // khóa các bước đã qua
              label: Text(s.label, style: const TextStyle(fontSize: 12)),
            ),
        ],
        selected: {cur},
        onSelectionChanged: updating
            ? null
            : (set) {
                final s = set.first;
                if (s.index > cur.index) onStatusChanged(s);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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

            // Ảnh + sản phẩm + mục + số lượng
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImage(url: task.imageUrl, size: 84),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 84,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.itemName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Số lượng: × ${task.quantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Đơn thanh toán lúc ${formatDateTime(task.paidAt)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),

            _control(),
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