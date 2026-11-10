import 'package:flutter/material.dart';

import '../../../core/format.dart';

/// Ảnh sản phẩm bo góc, có khung chờ khi đang tải hoặc chưa có ảnh.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.url,
    this.size = 72,
    this.radius = 8,
  });

  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = resolveImageUrl(url);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final placeholder = Container(
      color: const Color(0xFFF0F0F0),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: cs.outline, size: size * 0.4),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: resolved == null
            ? placeholder
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                cacheWidth: (size * dpr).round(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
                errorBuilder: (context, error, stack) => placeholder,
              ),
      ),
    );
  }
}