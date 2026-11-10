import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';
import 'orders_page.dart';
import 'paged_list.dart';

/// Danh sách khách hàng của mọi người bán (quản lý chỉ xem).
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _tick = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _apply(String text) {
    final t = text.trim();
    if (t != _query) {
      setState(() {
        _query = t;
        _tick++;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Khách hàng'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _tick++),
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (t) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 450), () {
                  if (mounted) _apply(t);
                });
              },
              onSubmitted: (t) {
                _debounce?.cancel();
                _apply(t);
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc SĐT',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _debounce?.cancel();
                          _apply('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: PagedList<CustomerRow>(
              key: ValueKey('$_tick|$_query'),
              emptyText: 'Không có khách hàng nào.',
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              fetch: (offset, limit) =>
                  ref.read(managerRepositoryProvider).fetchCustomers(
                        search: _query,
                        offset: offset,
                        limit: limit,
                      ),
              itemBuilder: (context, c) => Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CustomerOrdersPage(customer: c))),
                  leading: CircleAvatar(
                    backgroundColor: kBrand.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_outline, color: kBrand),
                  ),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                    if (c.contactChannel != null && c.contactChannel!.isNotEmpty)
                      c.contactChannel!,
                    'Người bán: ${c.sellerName ?? '-'}',
                  ].join(' · ')),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${c.orderCount}',
                          style: const TextStyle(
                              color: kPriceColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const Text('đơn', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

/// Thông tin 1 khách + các đơn của khách đó.
class CustomerOrdersPage extends ConsumerStatefulWidget {
  final CustomerRow customer;
  const CustomerOrdersPage({super.key, required this.customer});

  @override
  ConsumerState<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends ConsumerState<CustomerOrdersPage> {
  int _tick = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(children: [
            if (c.phone != null && c.phone!.isNotEmpty)
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(c.phone!)),
            if (c.contactChannel != null && c.contactChannel!.isNotEmpty)
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.chat_outlined),
                  title: Text(c.contactChannel!)),
            if (c.address != null && c.address!.isNotEmpty)
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(c.address!)),
            ListTile(
              dense: true,
              leading: const Icon(Icons.badge_outlined),
              title: Text('Người bán phụ trách: ${c.sellerName ?? '-'}'),
              subtitle: Text('Tạo lúc ${fmtDateTime(c.createdAt)}'),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Đơn hàng', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        Expanded(
          child: PagedList<Order>(
            key: ValueKey(_tick),
            emptyText: 'Khách này chưa có đơn nào.',
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            fetch: (offset, limit) =>
                ref.read(managerRepositoryProvider).fetchOrders(
                      customerId: c.id,
                      offset: offset,
                      limit: limit,
                    ),
            itemBuilder: (_, o) => OrderTile(
              order: o,
              onChanged: () => setState(() => _tick++),
            ),
          ),
        ),
      ]),
    );
  }
}