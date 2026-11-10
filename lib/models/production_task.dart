import 'enums.dart';
import 'json_helpers.dart';

/// 1 dòng của view `production_tasks` (bên kỹ thuật).
/// Chỉ có sản phẩm của đơn đã thanh toán, không có thông tin khách hay giá.
class ProductionTask {
  final String id; // = order_items.id
  final String orderCode;
  final String productName;
  final String itemName;
  final int quantity;
  final ProductionStatus productionStatus;
  final DateTime? paidAt;

  const ProductionTask({
    required this.id,
    required this.orderCode,
    required this.productName,
    required this.itemName,
    required this.quantity,
    required this.productionStatus,
    this.paidAt,
  });

  factory ProductionTask.fromJson(Map<String, dynamic> j) => ProductionTask(
        id: j['id'] as String,
        orderCode: j['order_code'] as String? ?? '',
        productName: j['product_name'] as String? ?? '',
        itemName: j['item_name'] as String? ?? '',
        quantity: j['quantity'] as int,
        productionStatus:
            ProductionStatus.fromString(j['production_status'] as String?),
        paidAt: toDate(j['paid_at']),
      );
}