import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

// ---------------------------------------------------------------------------
// Ảnh: hiển thị + chọn ảnh
// ---------------------------------------------------------------------------

Widget _thumb(String? url, double size, {double radius = 8}) => ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null
            ? ColoredBox(
                color: const Color(0xFFF0F0F0),
                child: Icon(Icons.image_outlined,
                    size: size * 0.45, color: Colors.grey),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: const Color(0xFFF0F0F0),
                  child: Icon(Icons.broken_image_outlined,
                      size: size * 0.45, color: Colors.grey),
                ),
              ),
      ),
    );

/// Trạng thái ảnh của 1 sản phẩm / item trong form.
class _ImageSlot {
  String? url; // ảnh đã có trên server
  Uint8List? bytes; // ảnh mới vừa chọn, chưa upload
  String? fileName;
  _ImageSlot({this.url});
  bool get has => bytes != null || url != null;
}

class _ImageBox extends StatelessWidget {
  final _ImageSlot slot;
  final double size;
  final VoidCallback onChanged;
  const _ImageBox(
      {required this.slot, required this.size, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (x == null) return;
      slot.bytes = await x.readAsBytes();
      slot.fileName = x.name;
      onChanged();
    } catch (e) {
      showSnack(context, 'Không chọn được ảnh: ${errorText(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (slot.bytes != null) {
      content = Image.memory(slot.bytes!, fit: BoxFit.cover);
    } else if (slot.url != null) {
      content = Image.network(slot.url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined, color: Colors.grey));
    } else {
      content = Icon(Icons.add_a_photo_outlined,
          size: size * 0.35, color: kBrand);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        Positioned.fill(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pick(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: const Color(0xFFFFF3EA),
                child: SizedBox.expand(child: Center(child: content)),
              ),
            ),
          ),
        ),
        if (slot.has)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () {
                slot.bytes = null;
                slot.fileName = null;
                slot.url = null;
                onChanged();
              },
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// UC13 – Danh sách sản phẩm
// ---------------------------------------------------------------------------

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

  void _reload() {
    setState(() {
      _future = ref.read(managerRepositoryProvider).fetchProducts();
    });
  }

  Future<void> _open([Product? p]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductFormPage(product: p)),
    );
    if (saved == true) _reload();
  }

  String _priceRange(Product p) {
    final prices = p.items.where((i) => i.isActive).map((i) => i.price).toList();
    if (prices.isEmpty) return 'Chưa có item đang hoạt động';
    prices.sort();
    return prices.first == prices.last
        ? money(prices.first)
        : '${money(prices.first)} – ${money(prices.last)}';
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
          heroTag: 'fab_products',
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                itemCount: list.length,
                itemBuilder: (_, i) => _productCard(list[i]),
              ),
            );
          },
        ),
      );

  Widget _productCard(Product p) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(p),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _thumb(p.imageUrl, 84, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    if (!p.isActive) const StatusChip('Ngừng', Colors.grey),
                  ]),
                  const SizedBox(height: 4),
                  Text(_priceRange(p),
                      style: const TextStyle(
                          color: kPriceColor, fontWeight: FontWeight.w800)),
                  if (p.items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final it in p.items)
                        Opacity(
                          opacity: it.isActive ? 1 : 0.45,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              border: Border.all(color: const Color(0xFFE5E5E5)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              _thumb(it.imageUrl ?? p.imageUrl, 22, radius: 11),
                              const SizedBox(width: 5),
                              Text(it.name, style: const TextStyle(fontSize: 12)),
                            ]),
                          ),
                        ),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Form tạo / sửa
// ---------------------------------------------------------------------------

class _ItemDraft {
  final String? id; // null = item mới
  final TextEditingController name;
  final TextEditingController price;
  final _ImageSlot image;
  bool isActive;

  _ItemDraft({
    this.id,
    String name = '',
    String price = '',
    String? imageUrl,
    this.isActive = true,
  })  : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        image = _ImageSlot(url: imageUrl);

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
  late final _ImageSlot _image;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _image = _ImageSlot(url: p?.imageUrl);
    if (p != null) {
      _name.text = p.name;
      _desc.text = p.description ?? '';
      _isActive = p.isActive;
      for (final i in p.items) {
        _items.add(_ItemDraft(
          id: i.id,
          name: i.name,
          price: i.price.toStringAsFixed(0),
          imageUrl: i.imageUrl,
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

  /// Ảnh mới -> upload rồi trả URL; ảnh cũ -> giữ URL; đã xoá -> null.
  Future<String?> _resolve(ManagerRepository repo, _ImageSlot s) async {
    if (s.bytes != null) {
      return repo.uploadProductImage(
          bytes: s.bytes!, fileName: s.fileName ?? 'image.jpg');
    }
    return s.url;
  }

  Future<void> _save() async {
    // 4a / 4b
    if (_name.text.trim().isEmpty) {
      return showSnack(context, 'Tên sản phẩm không được để trống.', error: true);
    }
    if (_items.isEmpty) {
      return showSnack(context, 'Sản phẩm phải có ít nhất một item.', error: true);
    }
    final prices = <double>[];
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
      prices.add(price);
    }

    final repo = ref.read(managerRepositoryProvider);
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    setState(() => _saving = true);
    try {
      // Upload ảnh trước, rồi mới ghi DB.
      final productUrl = await _resolve(repo, _image);
      final itemUrls = <String?>[];
      for (final d in _items) {
        itemUrls.add(await _resolve(repo, d.image));
      }

      if (!_isEdit) {
        await repo.createProduct(
          name: _name.text.trim(),
          description: desc,
          imageUrl: productUrl,
          items: [
            for (var k = 0; k < _items.length; k++)
              ItemInput(_items[k].name.text.trim(), prices[k], itemUrls[k]),
          ],
        );
      } else {
        await repo.updateProduct(
          id: widget.product!.id,
          name: _name.text.trim(),
          description: desc,
          imageUrl: productUrl,
          isActive: _isActive,
        );
        for (var k = 0; k < _items.length; k++) {
          final d = _items[k];
          final n = d.name.text.trim();
          if (d.id == null) {
            await repo.addItem(
                productId: widget.product!.id,
                name: n,
                price: prices[k],
                imageUrl: itemUrls[k]);
          } else {
            await repo.updateItem(
                id: d.id!,
                name: n,
                price: prices[k],
                imageUrl: itemUrls[k],
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
        appBar: AppBar(title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ImageBox(slot: _image, size: 96, onChanged: () => setState(() {})),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Chạm vào khung để chọn ảnh sản phẩm',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ImageBox(slot: d.image, size: 72, onChanged: () => setState(() {})),
          const SizedBox(width: 12),
          Expanded(
            child: Column(children: [
              TextField(
                controller: d.name,
                decoration: const InputDecoration(labelText: 'Tên item'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: d.price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá (đ)'),
              ),
              if (d.id != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Hoạt động'),
                  value: d.isActive,
                  onChanged: (v) => setState(() => d.isActive = v),
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Bỏ item này',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _items.removeAt(k).dispose();
                    }),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}