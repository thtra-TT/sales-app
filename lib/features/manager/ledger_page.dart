import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'ledger_export.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

/// UC16 – Sổ bán hàng theo ngày (ghi theo NGÀY TẠO ĐƠN, có tách số đã thanh toán).
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  late DateTimeRange _range;
  late Future<List<SalesLedgerEntry>> _future;
  List<SalesLedgerEntry> _rows = const []; // dữ liệu đang hiển thị, dùng để xuất file
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    _range = DateTimeRange(start: today, end: today); // mặc định hôm nay
    _future = _load();
  }

  Future<List<SalesLedgerEntry>> _load() =>
      ref.read(managerRepositoryProvider).fetchLedger(_range);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _pick() async {
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
  Widget build(BuildContext context) {
    final same = _range.start == _range.end;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ bán hàng'),
        actions: [
          IconButton(
              tooltip: 'Tải lại',
              onPressed: _reload,
              icon: const Icon(Icons.refresh)),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            PopupMenuButton<bool>(
              tooltip: 'Xuất file',
              icon: const Icon(Icons.file_download_outlined),
              onSelected: _export,
              itemBuilder: (_) => const [
                PopupMenuItem(value: true, child: Text('Xuất Excel (.xlsx)')),
                PopupMenuItem(value: false, child: Text('Xuất PDF')),
              ],
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.date_range),
            label: Text(same
                ? fmtDate(_range.start)
                : '${fmtDate(_range.start)} – ${fmtDate(_range.end)}'),
          ),
        ),
        Expanded(
          child: FutureBody<List<SalesLedgerEntry>>(
            future: _future,
            onRetry: _reload,
            builder: _buildList,
          ),
        ),
      ]),
    );
  }

  Future<void> _export(bool excel) async {
    if (_rows.isEmpty) {
      return showSnack(context, 'Không có dữ liệu để xuất.', error: true);
    }
    setState(() => _exporting = true);
    try {
      if (excel) {
        await exportLedgerExcel(_range, _rows);
        if (mounted) showSnack(context, 'Đã xuất file Excel.');
      } else {
        await exportLedgerPdf(_range, _rows);
      }
    } catch (e) {
      showSnack(context, 'Xuất file thất bại: ${errorText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildList(List<SalesLedgerEntry> rows) {
    _rows = rows;
    if (rows.isEmpty) {
      return const Center(child: Text('Không có dữ liệu trong khoảng ngày này.'));
    }
    final byDay = <DateTime, List<SalesLedgerEntry>>{};
    final all = LedgerTotals();
    for (final e in rows) {
      byDay.putIfAbsent(e.saleDate, () => []).add(e);
      all.add(e);
    }
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [kBrand, kBrandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: _summary('Tổng cả kỳ', all, theme, color: Colors.white),
          ),
        ),
        for (final entry in byDay.entries) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final t = LedgerTotals();
            for (final e in entry.value) {
              t.add(e);
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _summary(fmtDate(entry.key), t, theme),
                  const Divider(),
                  for (final e in entry.value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${e.productName} – ${e.itemName} × ${e.quantity}'),
                                Text('${e.orderCode} · ${e.seller}',
                                    style: theme.textTheme.bodySmall),
                              ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(money(e.lineTotal),
              style: const TextStyle(
                  color: kPriceColor, fontWeight: FontWeight.w700)),
                          StatusChip(
                              e.paymentStatus.label,
                              e.paymentStatus == PaymentStatus.paid
                                  ? Colors.green
                                  : Colors.orange),
                        ]),
                      ]),
                    ),
                ]),
              ),
            );
          }),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Sổ ghi theo ngày tạo đơn. "Thực thu" = tổng đơn sau giảm giá; '
            '"Tiền hàng" = tổng các dòng trước giảm giá.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _summary(String title, LedgerTotals t, ThemeData theme, {Color? color}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$title · ${t.orderCount} đơn',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Tiền hàng: ${money(t.gross)}'),
        Text('Tổng đơn (sau giảm giá): ${money(t.net)}'),
        Text('Đã thanh toán: ${money(t.paid)} · '
            'Chưa: ${money(t.net - t.paid)}'),
      ]);
}