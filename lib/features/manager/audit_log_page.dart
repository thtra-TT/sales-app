import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

class _Group {
  final String label;
  final String? prefix;
  const _Group(this.label, this.prefix);
}

const _groups = [
  _Group('Tất cả', null),
  _Group('Rút tiền', 'withdrawal.'),
  _Group('Sản phẩm / giá', 'item.'),
  _Group('Hạng', 'rank.'),
  _Group('Giao hàng', 'order.'),
  _Group('Sản xuất', 'production.'),
  _Group('Tài khoản', 'account.'),
];

double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
String _pct(dynamic v) {
  final d = _n(v);
  return '${d == d.roundToDouble() ? d.toInt() : d}%';
}

String _production(dynamic v) => switch (v) {
      'pending' => 'Chờ sản xuất',
      'in_progress' => 'Đang sản xuất',
      'done' => 'Hoàn thành',
      _ => '$v',
    };

String _delivery(dynamic v) => v == 'delivered' ? 'Đã giao' : 'Chưa giao';
String _role(dynamic v) => switch (v) {
      'seller' => 'người bán',
      'production' => 'sản xuất',
      'manager' => 'quản lý',
      _ => '$v',
    };

/// Biến 1 dòng log thành câu tiếng Việt dễ đọc.
String describe(AuditLog l) {
  final d = l.detail;
  switch (l.action) {
    case 'withdrawal.approve':
      return 'Duyệt rút tiền ${money(_n(d['amount']))} cho ${d['seller_name'] ?? 'người bán'}';
    case 'withdrawal.reject':
      final note = d['note'];
      return 'Từ chối rút tiền ${money(_n(d['amount']))} của ${d['seller_name'] ?? 'người bán'}'
          '${note != null ? ' (lý do: $note)' : ''}';
    case 'item.price_change':
      return 'Đổi giá ${d['product']} – ${d['item']}: '
          '${money(_n(d['old']))} → ${money(_n(d['new']))}';
    case 'item.activate':
      return 'Bật item ${d['product']} – ${d['item']}';
    case 'item.deactivate':
      return 'Tắt item ${d['product']} – ${d['item']}';
    case 'product.activate':
      return 'Bật sản phẩm ${d['product']}';
    case 'product.deactivate':
      return 'Tắt sản phẩm ${d['product']}';
    case 'rank.create':
      return 'Tạo hạng ${d['name']}: từ ${money(_n(d['min_spent']))}, '
          'giảm ${_pct(d['discount'])}, hoa hồng ${_pct(d['commission'])}';
    case 'rank.update':
      final o = Map<String, dynamic>.from((d['old'] as Map?) ?? {});
      final n = Map<String, dynamic>.from((d['new'] as Map?) ?? {});
      final parts = <String>[
        if (o['name'] != n['name']) 'tên ${o['name']} → ${n['name']}',
        if (_n(o['min_spent']) != _n(n['min_spent']))
          'ngưỡng ${money(_n(o['min_spent']))} → ${money(_n(n['min_spent']))}',
        if (_n(o['discount']) != _n(n['discount']))
          'giảm giá ${_pct(o['discount'])} → ${_pct(n['discount'])}',
        if (_n(o['commission']) != _n(n['commission']))
          'hoa hồng ${_pct(o['commission'])} → ${_pct(n['commission'])}',
      ];
      return 'Sửa hạng ${n['name']}: ${parts.join(', ')}';
    case 'order.delivery':
      return 'Đơn ${d['code']}: ${_delivery(d['from'])} → ${_delivery(d['to'])}';
    case 'production.status':
      return 'Đơn ${d['code']} – ${d['product']} – ${d['item']} × ${d['quantity']}: '
          '${_production(d['from'])} → ${_production(d['to'])}';
    case 'account.create':
      return 'Tạo tài khoản ${d['name']} (${_role(d['role'])}, ${d['email']})';
    case 'account.lock':
      return 'Khoá tài khoản ${d['name']} (${_role(d['role'])})';
    case 'account.unlock':
      return 'Mở khoá tài khoản ${d['name']} (${_role(d['role'])})';
    case 'account.reset_password':
      return 'Đặt lại mật khẩu cho ${d['name']} (${_role(d['role'])})';
    default:
      return l.action;
  }
}

(IconData, Color) _style(String action) {
  if (action.startsWith('withdrawal.approve')) return (Icons.payments_outlined, Colors.green);
  if (action.startsWith('withdrawal.')) return (Icons.payments_outlined, Colors.red);
  if (action.startsWith('item.') || action.startsWith('product.')) {
    return (Icons.sell_outlined, kBrand);
  }
  if (action.startsWith('rank.')) return (Icons.workspace_premium_outlined, Colors.amber.shade800);
  if (action.startsWith('order.')) return (Icons.local_shipping_outlined, Colors.blue);
  if (action.startsWith('production.')) {
    return (Icons.precision_manufacturing_outlined, Colors.purple);
  }
  if (action == 'account.lock') return (Icons.lock_outline, Colors.red);
  if (action == 'account.unlock') return (Icons.lock_open_outlined, Colors.green);
  if (action.startsWith('account.')) return (Icons.manage_accounts_outlined, Colors.purple);
  return (Icons.history, Colors.grey);
}

class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key});

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  static const _pageSize = 100;
  _Group _group = _groups.first;
  int _limit = _pageSize;
  late Future<List<AuditLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AuditLog>> _load() => ref
      .read(managerRepositoryProvider)
      .fetchAuditLogs(prefix: _group.prefix, limit: _limit);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nhật ký thao tác'),
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _reload,
                icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final g in _groups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g.label),
                      selected: _group == g,
                      onSelected: (_) {
                        _group = g;
                        _limit = _pageSize;
                        _reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBody<List<AuditLog>>(
              future: _future,
              onRetry: _reload,
              builder: (logs) {
                if (logs.isEmpty) {
                  return const Center(child: Text('Chưa có thao tác nào được ghi.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: logs.length + (logs.length >= _limit ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == logs.length) {
                        return TextButton(
                          onPressed: () {
                            _limit += _pageSize;
                            _reload();
                          },
                          child: const Text('Xem thêm'),
                        );
                      }
                      final l = logs[i];
                      final (icon, color) = _style(l.action);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(describe(l)),
                          subtitle: Text(
                              '${l.actorName ?? 'Không rõ'} · ${fmtDateTime(l.createdAt)}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      );
}