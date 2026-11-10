import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import 'common.dart';

/// Cho phép bên ngoài yêu cầu danh sách tải lại (vẫn giữ ô tìm kiếm + vị trí cuộn).
class PagedListController {
  Future<void> Function()? _reload;

  /// Trả về Future để bên ngoài có thể `await` cho tới khi tải xong.
  Future<void> refresh() => _reload?.call() ?? Future<void>.value();
}

/// Danh sách có ô tìm kiếm (debounce) + tải thêm khi cuộn gần cuối.
/// Mọi thứ chạy phía server (ilike + range) nên 1000 hay 100.000 dòng đều nhẹ.
class PagedSearchList<T> extends StatefulWidget {
  const PagedSearchList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.hint = 'Tìm kiếm...',
    this.emptyText = 'Không có dữ liệu',
    this.pageSize = 30,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 24),
    this.controller,
  });

  final Future<List<T>> Function(String query, int offset, int limit) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String hint;
  final String emptyText;
  final int pageSize;
  final EdgeInsetsGeometry padding;
  final PagedListController? controller;

  @override
  State<PagedSearchList<T>> createState() => _PagedSearchListState<T>();
}

class _PagedSearchListState<T> extends State<PagedSearchList<T>> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final List<T> _items = [];
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _gen = 0; // tăng mỗi lần reset để bỏ qua kết quả cũ về muộn

  @override
  void initState() {
    super.initState();
    widget.controller?._reload = _reload;
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant PagedSearchList<T> old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._reload == _reload) old.controller?._reload = null;
      widget.controller?._reload = _reload;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._reload == _reload) widget.controller?._reload = null;
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _gen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.fetch(_query, _items.length, widget.pageSize);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length >= widget.pageSize;
        _loading = false;
      });
      _fillIfShort();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Nếu danh sách ngắn hơn màn hình thì không cuộn được -> tự tải thêm.
  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore || _loading || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0) _loadMore();
    });
  }

  void _resetAndLoad() {
    _gen++;
    setState(() {
      _items.clear();
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    _loadMore();
  }

  /// Tải lại đúng số dòng đang hiển thị (giữ vị trí cuộn).
  Future<void> _reload() async {
    final gen = ++_gen;
    final count = math.min(math.max(_items.length, widget.pageSize), 500);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.fetch(_query, 0, count);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page);
        _hasMore = page.length >= count;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onChanged(String v) {
    setState(() {}); // cập nhật nút xóa chữ
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = v.trim();
      if (q == _query) return;
      _query = q;
      _resetAndLoad();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _search,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _onChanged('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return ErrorView(message: errorText(_error!), onRetry: _resetAndLoad);
      }
      return Center(child: Text(widget.emptyText));
    }
    final showFooter = _hasMore || _error != null;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + (showFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < _items.length) return widget.itemBuilder(context, _items[i]);
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: OutlinedButton(
                  onPressed: _loadMore,
                  child: const Text('Không tải được, thử lại'),
                ),
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}