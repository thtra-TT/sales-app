import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

/// UC13 – Danh sách sản phẩm, tạo / sửa / ngừng hoạt động.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(managerRepositoryProvider).fetchProducts();
  }

  void _reload() => setState(
      () => _future = ref.read(managerRepositoryProvider).fetchProducts());

  Future<void> _open([Product? p]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(product: p)),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Sản phẩm'),
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _reload,
                icon: const Icon(Icons.refresh)),
            const LogoutButton(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm sản phẩm'),
        ),
        body: FutureBody<List<Product>>(
          future: _future,
          onRetry: _reload,
          builder: (list) {
            if (list.isEmpty) {
              return const Center(child: Text('Chưa có sản phẩm nào.'));
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  return Card(
                    child: ListTile(
                      onTap: () => _open(p),
                      title: Row(children: [
                        Flexible(child: Text(p.name)),
                        if (!p.isActive) ...[
                          const SizedBox(width: 8),
                          const StatusChip('Ngừng', Colors.grey),
                        ],
                      ]),
                      subtitle: Text(p.items.isEmpty
                          ? 'Chưa có item'
                          : p.items
                              .map((e) =>
                                  '${e.name}: ${money(e.price)}${e.isActive ? '' : ' (tắt)'}')
                              .join('\n')),
                      isThreeLine: p.items.length > 1,
                      trailing: const Icon(Icons.edit_outlined),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
}

class _ItemDraft {
  final String? id; // null = item mới
  final TextEditingController name;
  final TextEditingController price;
  bool isActive;

  _ItemDraft({this.id, String name = '', String price = '', this.isActive = true})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price);

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class ProductFormPage extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormPage({super.key, this.product});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _items = <_ItemDraft>[];
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _desc.text = p.description ?? '';
      _isActive = p.isActive;
      for (final i in p.items) {
        _items.add(_ItemDraft(
          id: i.id,
          name: i.name,
          price: i.price.toStringAsFixed(0),
          isActive: i.isActive,
        ));
      }
    } else {
      _items.add(_ItemDraft());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // 4a / 4b
    if (_name.text.trim().isEmpty) {
      return showSnack(context, 'Tên sản phẩm không được để trống.', error: true);
    }
    if (_items.isEmpty) {
      return showSnack(context, 'Sản phẩm phải có ít nhất một item.', error: true);
    }
    final inputs = <ItemInput>[];
    for (final i in _items) {
      final n = i.name.text.trim();
      final price = parseMoney(i.price.text);
      if (n.isEmpty) {
        return showSnack(context, 'Tên item không được để trống.', error: true);
      }
      if (price == null || price < 0) {
        return showSnack(context, 'Giá của "$n" phải là số lớn hơn hoặc bằng 0.',
            error: true);
      }
      inputs.add(ItemInput(n, price));
    }

    final repo = ref.read(managerRepositoryProvider);
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _saving = true);
    try {
      if (!_isEdit) {
        await repo.createProduct(
            name: _name.text.trim(), description: desc, items: inputs);
      } else {
        await repo.updateProduct(
          id: widget.product!.id,
          name: _name.text.trim(),
          description: desc,
          isActive: _isActive,
        );
        for (var k = 0; k < _items.length; k++) {
          final d = _items[k];
          if (d.id == null) {
            await repo.addItem(
                productId: widget.product!.id,
                name: inputs[k].name,
                price: inputs[k].price);
          } else {
            await repo.updateItem(
                id: d.id!,
                name: inputs[k].name,
                price: inputs[k].price,
                isActive: d.isActive);
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      showSnack(context, errorText(e), error: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            if (_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang hoạt động'),
                subtitle: const Text(
                    'Tắt = người bán không thấy; đơn cũ không bị ảnh hưởng'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            const SizedBox(height: 16),
            Text('Item', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var k = 0; k < _items.length; k++) _itemRow(k),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_ItemDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Thêm item'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lưu'),
            ),
          ],
        ),
      );

  Widget _itemRow(int k) {
    final d = _items[k];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: d.name,
                decoration: const InputDecoration(labelText: 'Tên item'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: d.price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá (đ)'),
              ),
            ),
          ]),
          Row(children: [
            if (d.id != null)
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Hoạt động'),
                  value: d.isActive,
                  onChanged: (v) => setState(() => d.isActive = v),
                ),
              )
            else ...[
              const Spacer(),
              IconButton(
                tooltip: 'Bỏ item này',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                  _items.removeAt(k).dispose();
                }),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}