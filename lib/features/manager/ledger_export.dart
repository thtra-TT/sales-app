import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/models.dart';
import 'manager_common.dart';

/// Cộng dồn số liệu sổ bán hàng (dùng cho màn hình và file xuất).
class LedgerTotals {
  double gross = 0; // tổng tiền hàng (trước giảm giá)
  final _orders = <String, ({double total, bool paid})>{};

  void add(SalesLedgerEntry e) {
    gross += e.lineTotal;
    _orders[e.orderCode] =
        (total: e.orderTotal, paid: e.paymentStatus == PaymentStatus.paid);
  }

  int get orderCount => _orders.length;
  double get net => _orders.values.fold(0, (s, o) => s + o.total);
  double get paid =>
      _orders.values.where((o) => o.paid).fold(0, (s, o) => s + o.total);
}

String _title(DateTimeRange r) => r.start == r.end
    ? 'Sổ bán hàng ngày ${fmtDate(r.start)}'
    : 'Sổ bán hàng ${fmtDate(r.start)} – ${fmtDate(r.end)}';

String _fileBase(DateTimeRange r) {
  final f = DateFormat('yyyyMMdd');
  return 'so-ban-hang_${f.format(r.start)}_${f.format(r.end)}';
}

LedgerTotals _totals(List<SalesLedgerEntry> rows) {
  final t = LedgerTotals();
  for (final e in rows) {
    t.add(e);
  }
  return t;
}

// ---------------------------------------------------------------- Excel

Future<void> exportLedgerExcel(
    DateTimeRange range, List<SalesLedgerEntry> rows) async {
  final t = _totals(rows);
  final excel = Excel.createExcel();
  const sheetName = 'Sổ bán hàng';
  excel.rename('Sheet1', sheetName);
  final sh = excel[sheetName];

  sh.appendRow([TextCellValue(_title(range))]);
  sh.appendRow([
    TextCellValue('Số đơn'),
    IntCellValue(t.orderCount),
    TextCellValue('Tiền hàng'),
    DoubleCellValue(t.gross),
    TextCellValue('Tổng đơn sau giảm giá'),
    DoubleCellValue(t.net),
    TextCellValue('Đã thanh toán'),
    DoubleCellValue(t.paid),
    TextCellValue('Chưa thanh toán'),
    DoubleCellValue(t.net - t.paid),
  ]);
  sh.appendRow(<CellValue>[]);
  sh.appendRow([
    for (final h in const [
      'Ngày', 'Mã đơn', 'Người bán', 'Sản phẩm', 'Item', 'Số lượng',
      'Thành tiền', 'Thanh toán',
    ])
      TextCellValue(h),
  ]);
  for (final e in rows) {
    sh.appendRow([
      TextCellValue(fmtDate(e.saleDate)),
      TextCellValue(e.orderCode),
      TextCellValue(e.seller),
      TextCellValue(e.productName),
      TextCellValue(e.itemName),
      IntCellValue(e.quantity),
      DoubleCellValue(e.lineTotal),
      TextCellValue(e.paymentStatus.label),
    ]);
  }

  final bytes = excel.encode();
  if (bytes == null) throw 'Không tạo được file Excel.';
  await FileSaver.instance.saveFile(
    name: _fileBase(range),
    bytes: Uint8List.fromList(bytes),
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}

// ------------------------------------------------------------------ PDF

Future<void> exportLedgerPdf(
    DateTimeRange range, List<SalesLedgerEntry> rows) async {
  final t = _totals(rows);
  // Font Noto Sans (có tiếng Việt) tải từ Google Fonts, cần có mạng.
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: base, bold: bold));

  pw.Widget cell(String text,
          {bool header = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );

  final headers = const [
    'Ngày', 'Mã đơn', 'Người bán', 'Sản phẩm', 'Item', 'SL', 'Thành tiền',
    'Thanh toán',
  ];

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(24),
    build: (ctx) => [
      pw.Text(_title(range),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('Số đơn: ${t.orderCount}   ·   Tiền hàng: ${money(t.gross)}   ·   '
          'Tổng đơn sau giảm giá: ${money(t.net)}'),
      pw.Text('Đã thanh toán: ${money(t.paid)}   ·   '
          'Chưa thanh toán: ${money(t.net - t.paid)}'),
      pw.SizedBox(height: 10),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.2),
          1: pw.FlexColumnWidth(1.7),
          2: pw.FlexColumnWidth(1.8),
          3: pw.FlexColumnWidth(2.2),
          4: pw.FlexColumnWidth(1.8),
          5: pw.FlexColumnWidth(0.6),
          6: pw.FlexColumnWidth(1.5),
          7: pw.FlexColumnWidth(1.3),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [for (final h in headers) cell(h, header: true)],
          ),
          for (final e in rows)
            pw.TableRow(children: [
              cell(fmtDate(e.saleDate)),
              cell(e.orderCode),
              cell(e.seller),
              cell(e.productName),
              cell(e.itemName),
              cell('${e.quantity}', align: pw.TextAlign.right),
              cell(money(e.lineTotal), align: pw.TextAlign.right),
              cell(e.paymentStatus.label),
            ]),
        ],
      ),
    ],
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Trang ${ctx.pageNumber}/${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8)),
    ),
  ));

  await Printing.sharePdf(
    bytes: await doc.save(),
    filename: '${_fileBase(range)}.pdf',
  );
}