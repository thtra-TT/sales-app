import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../data/seller_providers.dart';
import '../widgets/common.dart';
import '../widgets/invoice_actions.dart';
import '../widgets/product_image.dart';
import '../widgets/proof_image.dart';
import '../widgets/status_chip.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(orderAsync.value?.code ?? 'Đơn hàng'),
        actions: [
          if (orderAsync.value != null)
            IconButton(
              tooltip: 'Xuất hóa đơn',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () =>
                  showInvoiceSheet(context, ref, orderAsync.value!),
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: errorText(e),
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
        data: _body,
      ),
    );
  }

  /// Gom các dòng của đơn theo tên sản phẩm (giữ thứ tự xuất hiện).
  Map<String, List<OrderItem>> _groupByProduct(List<OrderItem> items) {
    final m = <String, List<OrderItem>>{};
    for (final it in items) {
      (m[it.productName] ??= []).add(it);
    }
    return m;
  }

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

  Widget _body(Order o) {
    final cs = Theme.of(context).colorScheme;
    final c = o.customer;
    final inv = o.invoiceInfo ?? const <String, dynamic>{};
    final discountAmount = o.subtotal - o.total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // --- Đầu đơn ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.code,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDateTime(o.createdAt),
                        style: TextStyle(color: cs.onSurfaceVariant),
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
          ),
        ),

        // --- Xuất hóa đơn ---
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => showInvoiceSheet(context, ref, o),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Xuất hóa đơn (PDF)'),
          ),
        ),

        // --- Khách hàng ---
        const SectionTitle('Khách hàng'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                InfoRow('Tên', c?.name ?? ''),
                InfoRow('Số điện thoại', c?.phone ?? ''),
                InfoRow('Kênh liên lạc', c?.contactChannel ?? ''),
                InfoRow('Địa chỉ', c?.address ?? ''),
              ],
            ),
          ),
        ),

        // --- Hóa đơn ---
        if (o.needInvoice) ...[
          const SectionTitle('Xuất hóa đơn'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  InfoRow('Tên công ty', '${inv['company'] ?? ''}'),
                  InfoRow('Mã số thuế', '${inv['tax_code'] ?? ''}'),
                  InfoRow('Địa chỉ', '${inv['address'] ?? ''}'),
                  InfoRow('Email', '${inv['email'] ?? ''}'),
                ],
              ),
            ),
          ),
        ],

        // --- Sản phẩm (nhóm theo sản phẩm, có ảnh) ---
        const SectionTitle('Sản phẩm'),
        for (final entry in _groupByProduct(o.items).entries)
          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                // Dùng Material (không dùng ColoredBox) để ListTile hiển thị đúng
                Material(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Text(
                      formatMoney(
                        entry.value.fold<double>(0, (s, i) => s + i.lineTotal),
                      ),
                    ),
                  ),
                ),
                for (final it in entry.value) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProductImage(url: it.imageUrl, size: 72),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.itemName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatMoney(it.unitPrice)} × ${it.quantity}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                ),
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
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 96),
                ],
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                InfoRow('Tạm tính', formatMoney(o.subtotal)),
                InfoRow(
                  'Giảm giá (${formatPercent(o.discountPercent)}%)',
                  discountAmount > 0 ? '-${formatMoney(discountAmount)}' : '0 đ',
                ),
                InfoRow('Thành tiền', formatMoney(o.total), bold: true),
              ],
            ),
          ),
        ),

        // --- Thanh toán ---
        if (o.isPaid) ...[
          const SectionTitle('Thanh toán'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  InfoRow('Phương thức', paymentMethodLabel(o.paymentMethod)),
                  InfoRow('Thời gian', formatDateTime(o.paidAt)),
                  InfoRow(
                    'Hoa hồng (${formatPercent(o.commissionPercent ?? 0)}%)',
                    '+${formatMoney(o.commissionAmount ?? 0)}',
                    bold: true,
                  ),
                  if (o.paymentProofUrl != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              ),
            ),
          ),
        ] else ...[
          const SectionTitle('Cập nhật thanh toán'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phương thức thanh toán'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in paymentMethods.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _method == e.key,
                          onSelected: (_) => setState(() => _method = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Ảnh minh chứng thanh toán *'),
                  const SizedBox(height: 8),
                  _proofPicker(cs),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_saving || _proofBytes == null)
                          ? null
                          : () => _markPaid(o),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: const Text('Xác nhận đã thanh toán'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hoa hồng được tính theo hạng tại thời điểm xác nhận '
                    'thanh toán, không phải lúc tạo đơn. Chỉ đơn đã thanh toán '
                    'mới được chuyển sang bên kỹ thuật.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}