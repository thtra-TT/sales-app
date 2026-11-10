import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../data/invoice_pdf.dart';

enum _InvoiceAction { preview, share }

/// Bấm "Xuất hóa đơn": chọn Xem trước / In hoặc Tải về / Chia sẻ PDF.
Future<void> showInvoiceSheet(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final choice = await showModalBottomSheet<_InvoiceAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Xem trước / In'),
            subtitle: const Text('Mở bản xem trước, in hoặc lưu thành PDF'),
            onTap: () => Navigator.pop(ctx, _InvoiceAction.preview),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Tải về / Chia sẻ PDF'),
            subtitle: const Text('Lưu file hoặc gửi cho khách qua Zalo, email...'),
            onTap: () => Navigator.pop(ctx, _InvoiceAction.share),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  await _export(context, ref, order, share: choice == _InvoiceAction.share);
}

Future<void> _export(
  BuildContext context,
  WidgetRef ref,
  Order order, {
  required bool share,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final sellerName = ref.read(profileProvider).value?.fullName ?? '';

  // Hộp thoại chờ (tạo PDF + tải font lần đầu mất vài giây)
  var loadingOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  void closeLoading() {
    if (loadingOpen) {
      loadingOpen = false;
      navigator.pop();
    }
  }

  try {
    final bytes = await buildInvoicePdf(order: order, sellerName: sellerName);
    closeLoading();
    final filename = 'HoaDon-${order.code}.pdf';
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else {
      await Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
    }
  } catch (e) {
    closeLoading();
    messenger.showSnackBar(
      SnackBar(content: Text('Không xuất được hóa đơn: ${errorText(e)}')),
    );
  }
}