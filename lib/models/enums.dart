/// Các enum khớp với kiểu enum trong database.
/// `value` là chuỗi lưu trong DB, `label` là chữ hiển thị trên giao diện.

enum PaymentStatus {
  unpaid('unpaid', 'Chưa thanh toán'),
  paid('paid', 'Đã thanh toán');

  const PaymentStatus(this.value, this.label);
  final String value;
  final String label;

  static PaymentStatus fromString(String? v) => values.firstWhere(
        (e) => e.value == v,
        orElse: () => PaymentStatus.unpaid,
      );
}

enum DeliveryStatus {
  pending('pending', 'Chưa giao'),
  delivered('delivered', 'Đã giao');

  const DeliveryStatus(this.value, this.label);
  final String value;
  final String label;

  static DeliveryStatus fromString(String? v) => values.firstWhere(
        (e) => e.value == v,
        orElse: () => DeliveryStatus.pending,
      );
}

enum ProductionStatus {
  pending('pending', 'Chưa làm'),
  inProgress('in_progress', 'Đang làm'),
  done('done', 'Hoàn thành');

  const ProductionStatus(this.value, this.label);
  final String value;
  final String label;

  static ProductionStatus fromString(String? v) => values.firstWhere(
        (e) => e.value == v,
        orElse: () => ProductionStatus.pending,
      );
}

enum WithdrawStatus {
  pending('pending', 'Chờ duyệt'),
  approved('approved', 'Đã duyệt'),
  rejected('rejected', 'Từ chối');

  const WithdrawStatus(this.value, this.label);
  final String value;
  final String label;

  static WithdrawStatus fromString(String? v) => values.firstWhere(
        (e) => e.value == v,
        orElse: () => WithdrawStatus.pending,
      );
}

enum WalletTxType {
  commission('commission', 'Hoa hồng'),
  withdraw('withdraw', 'Rút tiền');

  const WalletTxType(this.value, this.label);
  final String value;
  final String label;

  static WalletTxType fromString(String? v) => values.firstWhere(
        (e) => e.value == v,
        orElse: () => WalletTxType.commission,
      );
}