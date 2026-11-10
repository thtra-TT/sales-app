import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../seller/widgets/paged_search_list.dart';
import 'data/production_providers.dart';
import 'widgets/task_card.dart';

class ProductionHome extends ConsumerStatefulWidget {
  const ProductionHome({super.key});

  @override
  ConsumerState<ProductionHome> createState() => _ProductionHomeState();
}

class _ProductionHomeState extends ConsumerState<ProductionHome> {
  ProductionStatus? _filter; // null = tất cả
  final _ctrl = PagedListController();
  final Set<String> _updating = {}; // id các dòng đang gửi cập nhật
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tự tải lại mỗi 60 giây để thấy đơn mới vừa thanh toán
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _ctrl.refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _changeStatus(ProductionTask t, ProductionStatus s) async {
    setState(() => _updating.add(t.id));
    try {
      await ref
          .read(productionRepoProvider)
          .setStatus(itemId: t.id, status: s);
      await _ctrl.refresh();
    } catch (e) {
      _toast(errorText(e));
    } finally {
      if (mounted) setState(() => _updating.remove(t.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản xuất kỹ thuật'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _ctrl.refresh,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------- Lọc trạng thái ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final s in ProductionStatus.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                ],
              ),
            ),
          ),

          // ---------- Danh sách sản phẩm cần làm ----------
          Expanded(
            child: PagedSearchList<ProductionTask>(
              key: ValueKey(_filter), // đổi bộ lọc -> tải lại từ đầu
              controller: _ctrl,
              hint: 'Tìm theo mã đơn, sản phẩm, mục...',
              emptyText: 'Chưa có sản phẩm nào cần làm.\n'
                  'Chỉ hiện sản phẩm của đơn đã thanh toán.',
              pageSize: 20,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              fetch: (q, off, lim) =>
                  ref.read(productionRepoProvider).fetchTasks(
                        status: _filter,
                        query: q,
                        offset: off,
                        limit: lim,
                      ),
              itemBuilder: (context, t) => TaskCard(
                task: t,
                updating: _updating.contains(t.id),
                onStatusChanged: (s) => _changeStatus(t, s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}