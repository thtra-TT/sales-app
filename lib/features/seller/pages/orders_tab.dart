import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../models/models.dart';
import '../data/seller_providers.dart';
import '../widgets/paged_search_list.dart';
import '../widgets/product_image.dart';
import '../widgets/status_chip.dart';
import 'order_detail_page.dart';

class OrdersTab extends ConsumerStatefulWidget {
  const OrdersTab({super.key, required this.controller});
  final PagedListController controller;

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab> {
  PaymentStatus? _filter; // null = tất cả

  Future<void> _open(Order o) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: o.id)),
    );
    if (mounted) widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final s in PaymentStatus.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _filter == s,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PagedSearchList<Order>(
            key: ValueKey(_filter), // đổi bộ lọc -> tải lại từ đầu
            controller: widget.controller,
            hint: 'Tìm theo mã đơn (vd: DH2611...)',
            emptyText: 'Chưa có đơn hàng nào',
            pageSize: 20,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            fetch: (q, off, lim) => ref.read(sellerRepoProvider).fetchOrdersPage(
                  status: _filter,
                  query: q,
                  offset: off,
                  limit: lim,
                ),
            itemBuilder: (context, o) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OrderCard(order: o, onTap: () => _open(o)),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});
  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = order;

    final names = <String>[];
    for (final i in o.items) {
      if (!names.contains(i.productName)) names.add(i.productName);
    }
    final productName = names.isEmpty
        ? 'Đơn hàng'
        : names.length == 1
            ? names.first
            : '${names.first} +${names.length - 1} sản phẩm';
    final image = o.items.isEmpty ? null : o.items.first.imageUrl;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mã đơn + trạng thái
              Row(
                children: [
                  Expanded(
                    child: Text(
                      o.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  paymentChip(o.paymentStatus),
                  if (o.isPaid) ...[
                    const SizedBox(width: 6),
                    deliveryChip(o.deliveryStatus),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Ảnh + tên sản phẩm + khách hàng
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImage(url: image, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${o.customer?.name ?? 'Khách hàng'} · ${o.items.length} mục',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDateTime(o.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Thành tiền
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Thành tiền: ',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  Text(
                    formatMoney(o.total),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}