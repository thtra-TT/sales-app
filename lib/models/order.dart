import 'customer.dart';
import 'enums.dart';
import 'json_helpers.dart';
import 'order_item.dart';

class Order {
  final String id;
  final String code;
  final String sellerId;
  final String customerId;
  final bool needInvoice;
  final Map<String, dynamic>? invoiceInfo; // tên cty, MST, địa chỉ, email...
  final double subtotal;
  final double discountPercent; // chốt lúc tạo đơn
  final double total;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;
  final String? paymentProofUrl; // path trong bucket payment-proofs
  final DateTime? paidAt;
  final double? commissionPercent; // chốt lúc chuyển đã thanh toán
  final double? commissionAmount;
  final DeliveryStatus deliveryStatus;
  final DateTime? deliveryUpdatedAt; // cột tuỳ chọn, xem manager_migration.sql
  final DateTime? createdAt;

  // Có giá trị khi select kèm quan hệ:
  //   customers(*), order_items(*), profiles(full_name)
  final Customer? customer;
  final List<OrderItem> items;
  final String? sellerName;

  const Order({
    required this.id,
    required this.code,
    required this.sellerId,
    required this.customerId,
    required this.needInvoice,
    required this.subtotal,
    required this.discountPercent,
    required this.total,
    required this.paymentStatus,
    required this.deliveryStatus,
    this.invoiceInfo,
    this.paymentMethod,
    this.paymentProofUrl,
    this.paidAt,
    this.commissionPercent,
    this.commissionAmount,
    this.deliveryUpdatedAt,
    this.createdAt,
    this.customer,
    this.items = const [],
    this.sellerName,
  });

  bool get isPaid => paymentStatus == PaymentStatus.paid;

  factory Order.fromJson(Map<String, dynamic> j) {
    final cust = j['customers'] as Map<String, dynamic>?;
    final seller = j['profiles'] as Map<String, dynamic>?;
    return Order(
      id: j['id'] as String,
      code: j['code'] as String? ?? '',
      sellerId: j['seller_id'] as String,
      customerId: j['customer_id'] as String,
      needInvoice: j['need_invoice'] as bool? ?? false,
      invoiceInfo: j['invoice_info'] as Map<String, dynamic>?,
      subtotal: toDouble(j['subtotal']),
      discountPercent: toDouble(j['discount_percent']),
      total: toDouble(j['total']),
      paymentStatus: PaymentStatus.fromString(j['payment_status'] as String?),
      paymentMethod: j['payment_method'] as String?,
      paymentProofUrl: j['payment_proof_url'] as String?,
      paidAt: toDate(j['paid_at']),
      commissionPercent: toDoubleOrNull(j['commission_percent']),
      commissionAmount: toDoubleOrNull(j['commission_amount']),
      deliveryStatus: DeliveryStatus.fromString(j['delivery_status'] as String?),
      deliveryUpdatedAt: toDate(j['delivery_updated_at']),
      createdAt: toDate(j['created_at']),
      customer: cust == null ? null : Customer.fromJson(cust),
      items: ((j['order_items'] as List?) ?? const [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      sellerName: seller?['full_name'] as String?,
    );
  }

  /// Tạo đơn mới: seller_id, mã đơn, % giảm giá do DB tự xử lý.
  static Map<String, dynamic> toInsertJson({
    required String customerId,
    bool needInvoice = false,
    Map<String, dynamic>? invoiceInfo,
  }) =>
      {
        'customer_id': customerId,
        'need_invoice': needInvoice,
        'invoice_info': invoiceInfo,
      };
}