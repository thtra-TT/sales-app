import 'enums.dart';
import 'json_helpers.dart';

/// 1 dòng của view `sales_ledger` (sổ bán hàng của quản lý).
class SalesLedgerEntry {
  final DateTime saleDate;
  final String orderCode;
  final String seller;
  final String productName;
  final String itemName;
  final int quantity;
  final double lineTotal;
  final PaymentStatus paymentStatus;
  final double orderTotal;

  const SalesLedgerEntry({
    required this.saleDate,
    required this.orderCode,
    required this.seller,
    required this.productName,
    required this.itemName,
    required this.quantity,
    required this.lineTotal,
    required this.paymentStatus,
    required this.orderTotal,
  });

  factory SalesLedgerEntry.fromJson(Map<String, dynamic> j) => SalesLedgerEntry(
        saleDate: DateTime.parse(j['sale_date'] as String),
        orderCode: j['order_code'] as String? ?? '',
        seller: j['seller'] as String? ?? '',
        productName: j['product_name'] as String? ?? '',
        itemName: j['item_name'] as String? ?? '',
        quantity: j['quantity'] as int,
        lineTotal: toDouble(j['line_total']),
        paymentStatus: PaymentStatus.fromString(j['payment_status'] as String?),
        orderTotal: toDouble(j['order_total']),
      );
}