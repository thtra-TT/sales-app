import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../data/seller_providers.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/common.dart';
import '../widgets/proof_image.dart';
import '../widgets/status_chip.dart';

/// Chi tiết đơn hàng, cùng phong cách với màn tạo đơn:
/// các khối trắng phẳng trên nền xám, thanh dưới cùng hiện tổng tiền
/// + nút xác nhận thanh toán (khi đơn chưa thanh toán).
class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  String _method = 'transfer';
  Uint8List? _proofBytes;
  String _proofExt = 'jpg';
  bool _saving = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _extOf(String name) {
    final i = name.lastIndexOf('.');
    final e = i < 0 ? 'jpg' : name.substring(i + 1).toLowerCase();
    return const ['jpg', 'jpeg', 'png', 'webp'].contains(e) ? e : 'jpg';
  }

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickProof() async {
    var source = ImageSource.gallery;
    if (_isMobile) {
      final s = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (s == null) return;
      source = s;
    }
    try {
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _proofBytes = bytes;
        _proofExt = _extOf(file.name);
      });
    } catch (e) {
      _toast('Không chọn được ảnh: ${errorText(e)}');
    }
  }

  Future<void> _markPaid(Order o) async {
    if (_proofBytes == null) {
      _toast('Hãy chọn ảnh minh chứng thanh toán');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: Text(
          'Đơn ${o.code} sẽ chuyển sang "Đã thanh toán", hoa hồng được cộng '
          'vào ví theo hạng hiện tại của bạn và không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final uid = ref.read(userIdProvider);
    final bytes = _proofBytes;
    if (uid == null || bytes == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(sellerRepoProvider).markPaid(
            orderId: o.id,
            uid: uid,
            method: _method,
            bytes: bytes,
            ext: _proofExt,
          );
      ref.invalidate(orderDetailProvider(o.id));
      ref.invalidate(profileProvider); // cập nhật ví, hạng
      ref.invalidate(myWalletTxProvider);
      if (mounted) setState(() => _proofBytes = null);
      _toast('Đã cập nhật thanh toán');
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final order = orderAsync.value;

    return Scaffold(
      appBar: AppBar(title: Text(order?.code ?? 'Đơn hàng')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: errorText(e),
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
        data: _body,
      ),
      bottomNavigationBar: (order == null || order.isPaid)
          ? null
          : ActionBottomBar(
              caption: 'Thành tiền',
              amount: formatMoney(order.total),
              note: null,
              buttonLabel: 'Xác nhận đã thanh toán',
              dimmed: _proofBytes == null,
              busy: _saving,
              onPressed: () => _markPaid(order),
            ),
    );
  }

  // ---------- Helpers ----------

  /// Gom các dòng của đơn theo tên sản phẩm (giữ thứ tự xuất hiện).
  Map<String, List<OrderItem>> _groupByProduct(List<OrderItem> items) {
    final m = <String, List<OrderItem>>{};
    for (final it in items) {
      (m[it.productName] ??= []).add(it);
    }
    return m;
  }

  /// Khối trắng phẳng có tiêu đề (icon + chữ đậm) và divider.
  Widget _block(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            const Divider(height: 1),
            child,
          ],
        ),
      );

  Widget _kv(
    ColorScheme cs,
    String label,
    String value, {
    Color? color,
    bool bold = false,
    double size = 14,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: TextStyle(
                  color: bold ? null : cs.onSurfaceVariant,
                  fontWeight: bold ? FontWeight.w600 : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                value.isEmpty ? '-' : value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: color,
                  fontSize: size,
                  fontWeight: bold ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _kvList(List<Widget> rows) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(children: rows),
      );

  // ---------- Các khối giao diện ----------

  Widget _headerBlock(Order o, ColorScheme cs) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        color: cs.surface,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long_outlined, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.code,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDateTime(o.createdAt),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                paymentChip(o.paymentStatus),
                if (o.isPaid) ...[
                  const SizedBox(height: 6),
                  deliveryChip(o.deliveryStatus),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _customerBlock(Order o, ColorScheme cs) {
    final c = o.customer;
    final detail = c == null
        ? ''
        : [c.contactChannel, c.address]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: c == null
                ? const Text('Không có thông tin khách hàng')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (c.phone != null && c.phone!.isNotEmpty)
                              TextSpan(
                                text: '   ${c.phone}',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(OrderItem it, Order o, ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2_outlined, color: cs.outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMoney(it.unitPrice)} × ${it.quantity}',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  if (o.isPaid) ...[
                    const SizedBox(height: 6),
                    productionChip(it.productionStatus),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMoney(it.lineTotal),
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );

  Widget _groupBlock(
    String name,
    List<OrderItem> items,
    Order o,
    ColorScheme cs,
  ) {
    final total = items.fold<double>(0, (s, i) => s + i.lineTotal);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final it in items) ...[
            _itemRow(it, o, cs),
            const Divider(height: 1, indent: 84),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Tổng (${items.length} mục): ',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                Text(
                  formatMoney(total),
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBlock(Order o, ColorScheme cs) {
    final discountAmount = o.subtotal - o.total;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết thanh toán',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          _kv(cs, 'Tổng tiền hàng', formatMoney(o.subtotal)),
          _kv(
            cs,
            'Giảm giá (${formatPercent(o.discountPercent)}%)',
            discountAmount > 0 ? '-${formatMoney(discountAmount)}' : '0 đ',
            color: discountAmount > 0 ? cs.primary : null,
          ),
          const Divider(height: 16),
          _kv(
            cs,
            'Thành tiền',
            formatMoney(o.total),
            color: cs.primary,
            bold: true,
            size: 17,
          ),
        ],
      ),
    );
  }

  Widget _invoiceBlock(Order o, ColorScheme cs) {
    final inv = o.invoiceInfo ?? const <String, dynamic>{};
    return _block(
      cs,
      icon: Icons.description_outlined,
      title: 'Xuất hóa đơn',
      child: _kvList([
        _kv(cs, 'Tên công ty', '${inv['company'] ?? ''}'),
        _kv(cs, 'Mã số thuế', '${inv['tax_code'] ?? ''}'),
        _kv(cs, 'Địa chỉ', '${inv['address'] ?? ''}'),
        _kv(cs, 'Email', '${inv['email'] ?? ''}'),
      ]),
    );
  }

  Widget _paidBlock(Order o, ColorScheme cs) => _block(
        cs,
        icon: Icons.verified_outlined,
        title: 'Thanh toán',
        child: Column(
          children: [
            _kvList([
              _kv(cs, 'Phương thức', paymentMethodLabel(o.paymentMethod)),
              _kv(cs, 'Thời gian', formatDateTime(o.paidAt)),
              _kv(
                cs,
                'Hoa hồng (${formatPercent(o.commissionPercent ?? 0)}%)',
                '+${formatMoney(o.commissionAmount ?? 0)}',
                color: cs.primary,
                bold: true,
              ),
            ]),
            if (o.paymentProofUrl != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ảnh minh chứng\n(nhấn để xem lớn)',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                    ProofThumbnail(
                      bucket: 'payment-proofs',
                      path: o.paymentProofUrl!,
                      size: 80,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _proofPicker(ColorScheme cs) {
    final bytes = _proofBytes;
    if (bytes == null) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _saving ? null : _pickProof,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Chọn ảnh minh chứng'),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThumbFrame(
          size: 96,
          onTap: () => showMemoryImage(context, bytes, title: 'Ảnh minh chứng'),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đã chọn ảnh minh chứng',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${(bytes.length / 1024).round()} KB · nhấn vào ảnh để xem',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _pickProof,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Đổi ảnh'),
                  ),
                  TextButton.icon(
                    onPressed:
                        _saving ? null : () => setState(() => _proofBytes = null),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _payUpdateBlock(ColorScheme cs) => _block(
        cs,
        icon: Icons.payments_outlined,
        title: 'Cập nhật thanh toán',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phương thức thanh toán',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in paymentMethods.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _method == e.key,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _method = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Ảnh minh chứng thanh toán *',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 8),
              _proofPicker(cs),
              const SizedBox(height: 12),
              Text(
                'Hoa hồng được tính theo hạng tại thời điểm xác nhận '
                'thanh toán, không phải lúc tạo đơn. Chỉ đơn đã thanh toán '
                'mới được chuyển sang bên kỹ thuật.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );

  Widget _body(Order o) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _headerBlock(o, cs),
        _customerBlock(o, cs),
        for (final entry in _groupByProduct(o.items).entries)
          _groupBlock(entry.key, entry.value, o, cs),
        if (o.needInvoice) _invoiceBlock(o, cs),
        _summaryBlock(o, cs),
        if (o.isPaid) _paidBlock(o, cs) else _payUpdateBlock(cs),
      ],
    );
  }
}