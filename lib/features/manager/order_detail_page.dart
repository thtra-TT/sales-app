import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

/// UC14 (chi tiết đơn) + UC15 (cập nhật trạng thái giao hàng).
class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late Future<Order> _future;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(managerRepositoryProvider).fetchOrder(widget.orderId);
  }

  void _reload() => setState(() =>
      _future = ref.read(managerRepositoryProvider).fetchOrder(widget.orderId));

  Future<void> _setDelivery(Order o, DeliveryStatus s) async {
    if (s == o.deliveryStatus || _busy) return;

    // 2a: chưa xong sản xuất -> cảnh báo nhưng vẫn cho quản lý quyết định
    final notDone = o.items.any((i) => i.productionStatus != ProductionStatus.done);
    if (s == DeliveryStatus.delivered && notDone) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Đơn chưa hoàn thành sản xuất'),
          content: const Text(
              'Còn item chưa hoàn thành. Vẫn đánh dấu là đã giao?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ')),
            FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Vẫn đánh dấu')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(managerRepositoryProvider).setDeliveryStatus(o.id, s);
      _changed = true;
      if (mounted) showSnack(context, 'Đã cập nhật: ${s.label}');
      _reload();
    } catch (e) {
      showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _prodColor(ProductionStatus s) => switch (s) {
        ProductionStatus.pending => Colors.grey,
        ProductionStatus.inProgress => Colors.orange,
        ProductionStatus.done => Colors.green,
      };

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(_changed);
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Chi tiết đơn')),
          body: FutureBody<Order>(
            future: _future,
            onRetry: _reload,
            builder: _buildBody,
          ),
        ),
      );

  Widget _buildBody(Order o) {
    final c = o.customer;
    final theme = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(o.code, style: theme.textTheme.titleLarge),
      Text('Tạo lúc ${fmtDateTime(o.createdAt)} · Người bán: ${o.sellerName ?? '-'}'),
      const SizedBox(height: 12),
      Card(
        child: Column(children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(c?.name ?? '-'),
            subtitle: Text([
              if (c?.phone != null) c!.phone!,
              if (c?.contactChannel != null) c!.contactChannel!,
              if (c?.address != null) c!.address!,
            ].join(' · ')),
          ),
          if (o.needInvoice)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Cần xuất hoá đơn'),
              subtitle: Text(o.invoiceInfo?.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join('\n') ??
                  ''),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Text('Sản phẩm', style: theme.textTheme.titleMedium),
      for (final i in o.items)
        Card(
          child: ListTile(
            title: Text('${i.productName} – ${i.itemName}'),
            subtitle: Text('${i.quantity} × ${money(i.unitPrice)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(i.lineTotal),
                    style: const TextStyle(
                        color: kPriceColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                StatusChip(i.productionStatus.label, _prodColor(i.productionStatus)),
              ],
            ),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _kv('Tạm tính', money(o.subtotal)),
            _kv('Giảm giá', '${o.discountPercent}%'),
            _kv('Tổng', money(o.total), bold: true, color: kPriceColor),
            const Divider(),
            _kv('Thanh toán', o.paymentStatus.label),
            if (o.paymentMethod != null) _kv('Hình thức', o.paymentMethod!),
            if (o.paidAt != null) _kv('Thanh toán lúc', fmtDateTime(o.paidAt)),
          ]),
        ),
      ),
      if (o.paymentProofUrl != null) ...[
        const SizedBox(height: 8),
        Text('Ảnh minh chứng thanh toán', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _PaymentProof(key: ValueKey(o.paymentProofUrl), path: o.paymentProofUrl!),
      ],
      const SizedBox(height: 8),
      Text('Giao hàng', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      SegmentedButton<DeliveryStatus>(
        segments: [
          for (final s in DeliveryStatus.values)
            ButtonSegment(value: s, label: Text(s.label)),
        ],
        selected: {o.deliveryStatus},
        onSelectionChanged:
            _busy ? null : (sel) => _setDelivery(o, sel.first),
      ),
      if (o.deliveryUpdatedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Cập nhật lúc ${fmtDateTime(o.deliveryUpdatedAt)}',
              style: theme.textTheme.bodySmall),
        ),
    ]);
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k),
          Text(v,
              style: TextStyle(
                  color: color,
                  fontSize: bold ? 16 : null,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ]),
      );
}


/// Ảnh minh chứng thanh toán (bucket private -> dùng signed URL).
class _PaymentProof extends ConsumerStatefulWidget {
  final String path;
  const _PaymentProof({super.key, required this.path});

  @override
  ConsumerState<_PaymentProof> createState() => _PaymentProofState();
}

class _PaymentProofState extends ConsumerState<_PaymentProof> {
  late final Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = ref.read(managerRepositoryProvider).signedPaymentProofUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _url,
        builder: (context, s) {
          if (s.hasError) return Text('Không tải được ảnh: ${errorText(s.error!)}');
          if (!s.hasData) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()));
          }
          final url = s.data!;
          return GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(child: Image.network(url)),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Text('Không hiển thị được ảnh.'),
              ),
            ),
          );
        },
      );
}