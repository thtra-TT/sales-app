import 'json_helpers.dart';
import 'product_item.dart';

class Product {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  /// Có giá trị khi select kèm `product_items(*)`.
  final List<ProductItem> items;

  const Product({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
    this.items = const [],
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        imageUrl: j['image_url'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: toDate(j['created_at']),
        items: ((j['product_items'] as List?) ?? const [])
            .map((e) => ProductItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Dùng khi tạo sản phẩm mới (quản lý).
  static Map<String, dynamic> toInsertJson({
    required String name,
    String? description,
    String? imageUrl,
  }) =>
      {'name': name, 'description': description, 'image_url': imageUrl};
}