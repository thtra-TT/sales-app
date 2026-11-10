import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/models.dart';
import '../data/seller_providers.dart';
import '../widgets/paged_search_list.dart';
import '../widgets/product_image.dart';

/// Chọn 1 sản phẩm: tìm theo tên, tải từng trang, có ảnh. Trả về Product.
class ProductPickerPage extends ConsumerWidget {
  const ProductPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn sản phẩm')),
      body: PagedSearchList<Product>(
        hint: 'Tìm sản phẩm theo tên...',
        emptyText: 'Không tìm thấy sản phẩm nào',
        padding: const EdgeInsets.only(bottom: 24),
        fetch: (q, off, lim) => ref
            .read(sellerRepoProvider)
            .searchProducts(query: q, offset: off, limit: lim),
        itemBuilder: (context, p) {
          final hasDesc = p.description != null && p.description!.isNotEmpty;
          return Column(
            children: [
              Material(
                color: cs.surface,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(p),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ProductImage(url: p.imageUrl, size: 72),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (hasDesc) ...[
                                const SizedBox(height: 4),
                                Text(
                                  p.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: cs.outline),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 96),
            ],
          );
        },
      ),
    );
  }
}