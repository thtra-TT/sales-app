import '../../../models/models.dart';

/// 1 dòng đang chọn trong đơn nháp: 1 item (của 1 sản phẩm nào đó) + số lượng.
class OrderLine {
  const OrderLine(
    this.item,
    this.qty,
    this.productName, {
    this.productImageUrl,
  });

  final ProductItem item;
  final int qty;
  final String productName;
  final String? productImageUrl;

  String get productId => item.productId;
  double get total => item.price * qty;

  /// Ảnh của item, nếu chưa có thì dùng ảnh của sản phẩm.
  String? get imageUrl => item.imageUrl ?? productImageUrl;
}