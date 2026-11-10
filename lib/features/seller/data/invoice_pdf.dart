import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/format.dart';
import '../../../core/shop_info.dart';
import '../../../core/vn_number_words.dart';
import '../../../models/models.dart';

const _brand = PdfColor.fromInt(0xFFEE4D2D);

/// Tạo file PDF hóa đơn (A4) cho 1 đơn hàng.
/// Font Roboto tải từ Google Fonts lần đầu (cần mạng), có hỗ trợ tiếng Việt.
Future<Uint8List> buildInvoicePdf({
  required Order order,
  required String sellerName,
}) async {
  final regular = await PdfGoogleFonts.robotoRegular();
  final bold = await PdfGoogleFonts.robotoBold();
  final italic = await PdfGoogleFonts.robotoItalic();

  final doc = pw.Document(
    title: 'Hóa đơn ${order.code}',
    author: ShopInfo.name,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: regular, bold: bold, italic: italic),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${order.code} · Trang ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (ctx) => [
        _header(order),
        pw.SizedBox(height: 12),
        pw.Divider(color: PdfColors.grey400, thickness: 0.8),
        pw.SizedBox(height: 10),
        _infoRow(order, sellerName),
        if (order.needInvoice) ...[
          pw.SizedBox(height: 10),
          _vatBox(order),
        ],
        pw.SizedBox(height: 14),
        _itemsTable(order),
        pw.SizedBox(height: 10),
        _totals(order),
        pw.SizedBox(height: 8),
        _amountInWords(order),
        pw.SizedBox(height: 10),
        _paymentStatus(order),
        pw.SizedBox(height: 28),
        _signatures(sellerName),
        pw.SizedBox(height: 20),
        pw.Center(
          child: pw.Text(
            ShopInfo.footerNote,
            style: pw.TextStyle(
              fontStyle: pw.FontStyle.italic,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

// ---------------------------------------------------------------------------

pw.Widget _text(
  String s, {
  double size = 10,
  bool bold = false,
  PdfColor? color,
  pw.TextAlign? align,
}) =>
    pw.Text(
      s,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    );

pw.Widget _cell(
  String s, {
  pw.TextAlign align = pw.TextAlign.left,
  bool bold = false,
  PdfColor? color,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: _text(s, align: align, bold: bold, color: color),
    );

pw.Widget _kv(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 78,
            child: _text(label, color: PdfColors.grey700),
          ),
          pw.Expanded(child: _text(value.isEmpty ? '-' : value)),
        ],
      ),
    );

pw.Widget _header(Order order) {
  final lines = <String>[
    if (ShopInfo.address.isNotEmpty) ShopInfo.address,
    if (ShopInfo.phone.isNotEmpty) 'ĐT: ${ShopInfo.phone}',
    if (ShopInfo.email.isNotEmpty) 'Email: ${ShopInfo.email}',
    if (ShopInfo.taxCode.isNotEmpty) 'MST: ${ShopInfo.taxCode}',
  ];
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _text(ShopInfo.name, size: 15, bold: true),
            pw.SizedBox(height: 4),
            for (final l in lines) _text(l, color: PdfColors.grey800),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _text('HÓA ĐƠN BÁN HÀNG', size: 17, bold: true, color: _brand),
          pw.SizedBox(height: 4),
          _text('Số: ${order.code}', bold: true),
          _text('Ngày: ${formatDateTime(order.createdAt)}'),
        ],
      ),
    ],
  );
}

pw.Widget _box({required String title, required List<pw.Widget> children}) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(title, bold: true, color: _brand),
          pw.SizedBox(height: 5),
          ...children,
        ],
      ),
    );

pw.Widget _infoRow(Order order, String sellerName) {
  final c = order.customer;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _box(
          title: 'KHÁCH HÀNG',
          children: [
            _kv('Họ tên', c?.name ?? ''),
            _kv('Điện thoại', c?.phone ?? ''),
            _kv('Liên lạc', c?.contactChannel ?? ''),
            _kv('Địa chỉ', c?.address ?? ''),
          ],
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: _box(
          title: 'THÔNG TIN ĐƠN HÀNG',
          children: [
            _kv('Mã đơn', order.code),
            _kv('Ngày lập', formatDateTime(order.createdAt)),
            _kv('NV bán hàng', sellerName),
            _kv(
              'Thanh toán',
              order.isPaid
                  ? 'Đã thanh toán (${paymentMethodLabel(order.paymentMethod)})'
                  : 'Chưa thanh toán',
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _vatBox(Order order) {
  final inv = order.invoiceInfo ?? const <String, dynamic>{};
  String v(String k) => '${inv[k] ?? ''}';
  return _box(
    title: 'THÔNG TIN XUẤT HÓA ĐƠN',
    children: [
      _kv('Đơn vị', v('company')),
      _kv('Mã số thuế', v('tax_code')),
      _kv('Địa chỉ', v('address')),
      _kv('Email', v('email')),
    ],
  );
}

pw.Widget _itemsTable(Order order) {
  final header = pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
    children: [
      _cell('STT', align: pw.TextAlign.center, bold: true),
      _cell('Tên hàng', bold: true),
      _cell('SL', align: pw.TextAlign.center, bold: true),
      _cell('Đơn giá', align: pw.TextAlign.right, bold: true),
      _cell('Thành tiền', align: pw.TextAlign.right, bold: true),
    ],
  );

  final rows = <pw.TableRow>[];
  for (var i = 0; i < order.items.length; i++) {
    final it = order.items[i];
    rows.add(
      pw.TableRow(
        children: [
          _cell('${i + 1}', align: pw.TextAlign.center),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(it.itemName),
                _text(it.productName, size: 8.5, color: PdfColors.grey600),
              ],
            ),
          ),
          _cell('${it.quantity}', align: pw.TextAlign.center),
          _cell(formatMoney(it.unitPrice), align: pw.TextAlign.right),
          _cell(formatMoney(it.lineTotal), align: pw.TextAlign.right),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    columnWidths: const {
      0: pw.FixedColumnWidth(32),
      1: pw.FlexColumnWidth(4),
      2: pw.FixedColumnWidth(36),
      3: pw.FlexColumnWidth(1.6),
      4: pw.FlexColumnWidth(1.8),
    },
    children: [header, ...rows],
  );
}

pw.Widget _totals(Order order) {
  final discount = order.subtotal - order.total;
  pw.Widget row(String l, String v, {bool big = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: _text(l, size: big ? 11.5 : 10, bold: big),
            ),
            _text(v, size: big ? 13 : 10, bold: big, color: color),
          ],
        ),
      );

  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: 250,
      child: pw.Column(
        children: [
          row('Tạm tính', formatMoney(order.subtotal)),
          row(
            'Giảm giá (${formatPercent(order.discountPercent)}%)',
            discount > 0 ? '-${formatMoney(discount)}' : '0 đ',
          ),
          pw.Divider(color: PdfColors.grey500, thickness: 0.6),
          row(
            'TỔNG THANH TOÁN',
            formatMoney(order.total),
            big: true,
            color: _brand,
          ),
        ],
      ),
    ),
  );
}

pw.Widget _amountInWords(Order order) {
  final words = vnMoneyInWords(order.total);
  if (words.isEmpty) return pw.SizedBox();
  return pw.RichText(
    text: pw.TextSpan(
      style: const pw.TextStyle(fontSize: 10),
      children: [
        const pw.TextSpan(text: 'Số tiền bằng chữ: '),
        pw.TextSpan(
          text: words,
          style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );
}

pw.Widget _paymentStatus(Order order) {
  final paid = order.isPaid;
  final color = paid ? PdfColors.green700 : PdfColors.orange800;
  final detail = paid
      ? 'Phương thức: ${paymentMethodLabel(order.paymentMethod)}'
          ' · Lúc: ${formatDateTime(order.paidAt)}'
      : 'Vui lòng thanh toán theo thỏa thuận với nhân viên bán hàng.';
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: color, width: 0.8),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      children: [
        _text(
          paid ? 'ĐÃ THANH TOÁN' : 'CHƯA THANH TOÁN',
          bold: true,
          color: color,
          size: 11,
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(child: _text(detail, color: PdfColors.grey800, size: 9.5)),
      ],
    ),
  );
}

pw.Widget _signatures(String sellerName) {
  pw.Widget sign(String title, String name) => pw.Column(
        children: [
          _text(title, bold: true),
          _text('(Ký, ghi rõ họ tên)', size: 8.5, color: PdfColors.grey600),
          pw.SizedBox(height: 46),
          if (name.isNotEmpty) _text(name),
        ],
      );
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
    children: [
      sign('Khách hàng', ''),
      sign('Người lập phiếu', sellerName),
    ],
  );
}