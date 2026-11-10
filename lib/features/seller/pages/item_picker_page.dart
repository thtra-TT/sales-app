import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../models/models.dart';
import '../data/order_line.dart';
import '../data/seller_providers.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/paged_search_list.dart';
import '../widgets/product_image.dart';
import '../widgets/qty_stepper.dart';

/// Chọn các mục (item) của 1 sản phẩm: có ảnh, tìm kiếm, tải từng trang.
/// Bấm "Thêm" hoặc bấm vào dòng để +1, bấm vào con số để gõ số lượng.
/// `initial` chỉ gồm các dòng của sản phẩm này. Trả về Map<itemId, OrderLine>
/// (cũng chỉ của sản phẩm này).
class ItemPickerPage extends ConsumerStatefulWidget {
  const ItemPickerPage({
    super.key,
    required this.product,
    required this.initial,
  });
  final Product product;
  final Map<String, OrderLine> initial;

  @override
  ConsumerState<ItemPickerPage> createState() => _ItemPickerPageState();
}

class _ItemPickerPageState extends ConsumerState<ItemPickerPage> {
  late final Map<String, OrderLine> _lines = Map.of(widget.initial);

  void _set(ProductItem item, int qty) {
    setState(() {
      if (qty <= 0) {
        _lines.remove(item.id);
      } else {
        _lines[item.id] = OrderLine(
          item,
          qty,
          widget.product.name,
          productImageUrl: widget.product.imageUrl,
        );
      }
    });
  }

  double get _subtotal =>
      _lines.values.fold<double>(0, (sum, l) => sum + l.total);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      // Bấm nút quay lại cũng giữ nguyên lựa chọn (giống giỏ hàng)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_lines);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.product.name),
          actions: [
            TextButton(
              onPressed: _lines.isEmpty ? null : () => setState(_lines.clear),
              child: const Text('Bỏ chọn hết'),
            ),
          ],
        ),
        body: PagedSearchList<ProductItem>(
          hint: 'Tìm mục trong "${widget.product.name}"...',
          emptyText: 'Không tìm thấy mục nào',
          padding: const EdgeInsets.only(bottom: 24),
          fetch: (q, off, lim) => ref.read(sellerRepoProvider).searchProductItems(
                productId: widget.product.id,
                query: q,
                offset: off,
                limit: lim,
              ),
          itemBuilder: (context, item) {
            final qty = _lines[item.id]?.qty ?? 0;
            return Column(
              children: [
                Material(
                  color: qty > 0
                      ? cs.primaryContainer.withValues(alpha: 0.35)
                      : cs.surface,
                  child: InkWell(
                    onTap: () => _set(item, qty + 1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ProductImage(
                            url: item.imageUrl ?? widget.product.imageUrl,
                            size: 76,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 76,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          formatMoney(item.price),
                                          style: TextStyle(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (qty == 0)
                                        SizedBox(
                                          height: 30,
                                          child: OutlinedButton(
                                            onPressed: () => _set(item, 1),
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(64, 30),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 14,
                                              ),
                                              foregroundColor: cs.primary,
                                              side: BorderSide(
                                                color: cs.primary,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            child: const Text('Thêm'),
                                          ),
                                        )
                                      else
                                        QtyBox(
                                          value: qty,
                                          onChanged: (v) => _set(item, v),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 100),
              ],
            );
          },
        ),
        bottomNavigationBar: ActionBottomBar(
          caption: 'Đã chọn ${_lines.length} mục',
          amount: formatMoney(_subtotal),
          buttonLabel: 'Xong',
          onPressed: () => Navigator.of(context).pop(_lines),
        ),
      ),
    );
  }
}