import 'json_helpers.dart';

class ProductItem {
  final String id;
  final String productId;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isActive;

  const ProductItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    this.imageUrl,
    this.isActive = true,
  });

  factory ProductItem.fromJson(Map<String, dynamic> j) => ProductItem(
        id: j['id'] as String,
        productId: j['product_id'] as String,
        name: j['name'] as String,
        price: toDouble(j['price']),
        imageUrl: j['image_url'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  /// Dùng khi thêm item mới cho 1 sản phẩm (quản lý).
  static Map<String, dynamic> toInsertJson({
    required String productId,
    required String name,
    required double price,
    String? imageUrl,
  }) =>
      {
        'product_id': productId,
        'name': name,
        'price': price,
        'image_url': imageUrl,
      };
}