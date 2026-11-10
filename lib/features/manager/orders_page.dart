import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';
import 'order_detail_page.dart';

class _Opt<T> {
  final T? value;
  final String label;
  const _Opt(this.value, this.label);
}

/// Chip bấm vào mở menu chọn giá trị lọc.
class _FilterMenu<T> extends StatelessWidget {
  final String title;
  final List<_Opt<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  const _FilterMenu({
    required this.title,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.value == value,
        orElse: () => options.first);
    return PopupMenuButton<_Opt<T>>(
      onSelected: (o) => onChanged(o.value),
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem(value: o, child: Text(o.label)),
      ],
      child: Chip(
        avatar: value == null ? null : const Icon(Icons.filter_alt, size: 16),
        label: Text('$title: ${current.label}'),
      ),
    );
  }
}

/// UC14 – Xem toàn bộ đơn và lọc.
class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  PaymentStatus? _payment;
  DeliveryStatus? _delivery;
  String? _sellerId;
  DateTimeRange? _range;

  List<({String id, String name})> _sellers = [];
  late Future<List<Order>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    ref.read(managerRepositoryProvider).fetchSellers().then((s) {
      if (mounted) setState(() => _sellers = s);
    }).catchError((_) {});
  }

  Future<List<Order>> _load() => ref.read(managerRepositoryProvider).fetchOrders(
        payment: _payment,
        delivery: _delivery,
        sellerId: _sellerId,
        range: _range,
      );

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (r != null) {
      _range = r;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Đơn hàng'),
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _reload,
                icon: const Icon(Icons.refresh)),
            const LogoutButton(),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 0, children: [
                _FilterMenu<PaymentStatus>(
                  title: 'Thanh toán',
                  value: _payment,
                  options: [
                    const _Opt(null, 'Tất cả'),
                    for (final s in PaymentStatus.values) _Opt(s, s.label),
                  ],
                  onChanged: (v) {
                    _payment = v;
                    _reload();
                  },
                ),
                _FilterMenu<DeliveryStatus>(
                  title: 'Giao hàng',
                  value: _delivery,
                  options: [
                    const _Opt(null, 'Tất cả'),
                    for (final s in DeliveryStatus.values) _Opt(s, s.label),
                  ],
                  onChanged: (v) {
                    _delivery = v;
                    _reload();
                  },
                ),
                _FilterMenu<String>(
                  title: 'Người bán',
                  value: _sellerId,
                  options: [
                    const _Opt(null, 'Tất cả'),
                    for (final s in _sellers) _Opt(s.id, s.name),
                  ],
                  onChanged: (v) {
                    _sellerId = v;
                    _reload();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(_range == null
                      ? 'Ngày: Tất cả'
                      : '${fmtDate(_range!.start)} – ${fmtDate(_range!.end)}'),
                  onPressed: _pickRange,
                ),
                if (_range != null)
                  ActionChip(
                    label: const Text('Xoá lọc ngày'),
                    onPressed: () {
                      _range = null;
                      _reload();
                    },
                  ),
              ]),
            ),
          ),
          Expanded(
            child: FutureBody<List<Order>>(
              future: _future,
              onRetry: _reload,
              builder: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                      child: Text('Không có đơn nào khớp bộ lọc.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _OrderTile(
                      order: orders[i],
                      onChanged: _reload,
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final VoidCallback onChanged;
  const _OrderTile({required this.order, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Card(
      child: ListTile(
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.id)),
          );
          if (changed == true) onChanged();
        },
        title: Row(children: [
          Expanded(
              child: Text(o.code,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(money(o.total),
              style: const TextStyle(
                  color: kPriceColor, fontWeight: FontWeight.w800)),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${o.customer?.name ?? '-'} · ${o.sellerName ?? '-'}\n'
                '${fmtDateTime(o.createdAt)}'),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              StatusChip(o.paymentStatus.label,
                  o.isPaid ? Colors.green : Colors.orange),
              StatusChip(
                  o.deliveryStatus.label,
                  o.deliveryStatus == DeliveryStatus.delivered
                      ? Colors.green
                      : Colors.blueGrey),
            ]),
          ]),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}