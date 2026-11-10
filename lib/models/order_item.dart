import 'enums.dart';
import 'json_helpers.dart';

class OrderItem {
  final String id;
  final String orderId;
  final String productItemId;
  final String productName; // snapshot lúc tạo đơn
  final String itemName; // snapshot lúc tạo đơn
  final double unitPrice; // snapshot lúc tạo đơn
  final int quantity;
  final double lineTotal;
  final ProductionStatus productionStatus;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productItemId,
    required this.productName,
    required this.itemName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    required this.productionStatus,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'] as String,
        orderId: j['order_id'] as String,
        productItemId: j['product_item_id'] as String,
        productName: j['product_name'] as String? ?? '',
        itemName: j['item_name'] as String? ?? '',
        unitPrice: toDouble(j['unit_price']),
        quantity: j['quantity'] as int,
        lineTotal: toDouble(j['line_total']),
        productionStatus:
            ProductionStatus.fromString(j['production_status'] as String?),
      );

  /// Giá và tên do trigger ở DB tự điền, client chỉ gửi item + số lượng.
  static Map<String, dynamic> toInsertJson({
    required String orderId,
    required String productItemId,
    required int quantity,
  }) =>
      {
        'order_id': orderId,
        'product_item_id': productItemId,
        'quantity': quantity,
      };
}