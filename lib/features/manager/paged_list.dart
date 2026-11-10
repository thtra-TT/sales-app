import 'package:flutter/material.dart';

import 'manager_common.dart';

/// Danh sách tải theo trang (cuộn gần cuối tự tải tiếp, có nút "Xem thêm").
/// Muốn tải lại từ đầu khi bộ lọc đổi: đổi `key` của widget này.
class PagedList<T> extends StatefulWidget {
  final Future<List<T>> Function(int offset, int limit) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;
  final String emptyText;
  final EdgeInsets padding;

  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.pageSize = 30,
    this.emptyText = 'Không có dữ liệu.',
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 88),
  });

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final _scroll = ScrollController();
  final _items = <T>[];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 300) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.fetch(_items.length, widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= widget.pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(errorText(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _refresh, child: const Text('Thử lại')),
            ]),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(children: [
          const SizedBox(height: 120),
          Center(child: Text(widget.emptyText)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i < _items.length) return widget.itemBuilder(context, _items[i]);
          // chân danh sách
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return TextButton(
              onPressed: _loadMore,
              child: Text('Lỗi: ${errorText(_error!)}. Bấm để thử lại'),
            );
          }
          if (_hasMore) {
            return TextButton(onPressed: _loadMore, child: const Text('Xem thêm'));
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('Đã hiện hết', style: TextStyle(color: Colors.grey)),
            ),
          );
        },
      ),
    );
  }
}