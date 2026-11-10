import 'enums.dart';
import 'json_helpers.dart';

class WithdrawalRequest {
  final String id;
  final String sellerId;
  final double amount;
  final WithdrawStatus status;
  final String? proofUrl; // path ảnh chuyển khoản trong bucket withdraw-proofs
  final String? note;
  final String? processedBy;
  final DateTime? createdAt;
  final DateTime? processedAt;

  /// Có giá trị khi select kèm `profiles(full_name)` (màn hình quản lý).
  final String? sellerName;

  const WithdrawalRequest({
    required this.id,
    required this.sellerId,
    required this.amount,
    required this.status,
    this.proofUrl,
    this.note,
    this.processedBy,
    this.createdAt,
    this.processedAt,
    this.sellerName,
  });

  bool get isPending => status == WithdrawStatus.pending;

  factory WithdrawalRequest.fromJson(Map<String, dynamic> j) {
    final seller = j['profiles'] as Map<String, dynamic>?;
    return WithdrawalRequest(
      id: j['id'] as String,
      sellerId: j['seller_id'] as String,
      amount: toDouble(j['amount']),
      status: WithdrawStatus.fromString(j['status'] as String?),
      proofUrl: j['proof_url'] as String?,
      note: j['note'] as String?,
      processedBy: j['processed_by'] as String?,
      createdAt: toDate(j['created_at']),
      processedAt: toDate(j['processed_at']),
      sellerName: seller?['full_name'] as String?,
    );
  }

  /// Người bán gửi yêu cầu: seller_id và status do DB/RLS xử lý.
  static Map<String, dynamic> toInsertJson({required double amount}) =>
      {'amount': amount};
}