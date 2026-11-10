import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'customers_page.dart';
import 'ledger_page.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

/// 1,2tr / 350k / 900
String _compact(double v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}tr';
  }
  if (v >= 1000) return '${(v / 1000).round()}k';
  return v.round().toString();
}

/// Màn hình Tổng quan: doanh thu hôm nay, việc cần xử lý, doanh thu 7 ngày.
class DashboardPage extends ConsumerStatefulWidget {
  final void Function({PaymentStatus? payment, DeliveryStatus? delivery}) onOpenOrders;
  final VoidCallback onOpenWithdrawals;
  const DashboardPage({
    super.key,
    required this.onOpenOrders,
    required this.onOpenWithdrawals,
  });

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(managerRepositoryProvider).fetchDashboard();
  }

  void _reload() {
    setState(() {
      _future = ref.read(managerRepositoryProvider).fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(profileProvider).value?.fullName;
    return Scaffold(
      appBar: AppBar(
        title: Text(name?.isNotEmpty == true ? 'Xin chào, $name' : 'Tổng quan'),
        actions: [
          IconButton(
              tooltip: 'Tải lại',
              onPressed: _reload,
              icon: const Icon(Icons.refresh)),
          const LogoutButton(),
        ],
      ),
      body: FutureBody<Map<String, dynamic>>(
        future: _future,
        onRetry: _reload,
        builder: _buildBody,
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> d) {
    final theme = Theme.of(context);
    final last7 = ((d['last7'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(padding: const EdgeInsets.all(12), children: [
        // Doanh thu hôm nay
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [kBrand, kBrandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Doanh thu hôm nay',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(money(_n(d['revenue_today'])),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${_i(d['paid_orders_today'])} đơn đã thanh toán · '
              '${_i(d['orders_today'])} đơn mới tạo',
              style: const TextStyle(color: Colors.white),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: _StatCard(
              icon: Icons.hourglass_bottom,
              color: Colors.orange,
              title: 'Chưa thanh toán',
              value: '${_i(d['unpaid_orders'])} đơn',
              sub: money(_n(d['unpaid_amount'])),
              onTap: () => widget.onOpenOrders(payment: PaymentStatus.unpaid),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.local_shipping_outlined,
              color: Colors.blue,
              title: 'Chờ giao hàng',
              value: '${_i(d['undelivered_orders'])} đơn',
              sub: 'Đã thanh toán, chưa giao',
              onTap: () => widget.onOpenOrders(
                  payment: PaymentStatus.paid, delivery: DeliveryStatus.pending),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _StatCard(
          icon: Icons.payments_outlined,
          color: _i(d['pending_withdrawals']) > 0 ? Colors.red : Colors.green,
          title: 'Yêu cầu rút tiền chờ duyệt',
          value: '${_i(d['pending_withdrawals'])} yêu cầu',
          sub: money(_n(d['pending_withdrawal_amount'])),
          onTap: widget.onOpenWithdrawals,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Doanh thu 7 ngày qua (đã thanh toán)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _Bars(days: last7),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: _ShortcutCard(
              icon: Icons.menu_book_outlined,
              label: 'Sổ bán hàng',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LedgerPage())),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ShortcutCard(
              icon: Icons.groups_outlined,
              label: 'Khách hàng',
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CustomersPage())),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, value, sub;
  final VoidCallback onTap;
  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 12)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ]),
          ),
        ),
      );
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Icon(icon, color: kBrand, size: 28),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

/// Biểu đồ cột đơn giản (không cần thư viện).
class _Bars extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _Bars({required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const Text('Chưa có dữ liệu.');
    final values = [for (final d in days) _n(d['revenue'])];
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    const chartH = 110.0;

    return SizedBox(
      height: chartH + 40,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var k = 0; k < days.length; k++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(values[k] > 0 ? _compact(values[k]) : '',
                  style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 2),
              Container(
                height: maxV <= 0 ? 2 : (values[k] / maxV * chartH).clamp(2, chartH),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: k == days.length - 1 ? kBrand : kBrand.withValues(alpha: 0.4),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 4),
              Text(_dayLabel(days[k]['date'] as String? ?? ''),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
      ]),
    );
  }

  String _dayLabel(String iso) {
    final p = iso.split('-'); // yyyy-MM-dd
    return p.length == 3 ? '${p[2]}/${p[1]}' : iso;
  }
}