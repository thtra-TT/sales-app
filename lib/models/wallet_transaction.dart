import 'enums.dart';
import 'json_helpers.dart';

class WalletTransaction {
  final String id;
  final String sellerId;
  final WalletTxType type;
  final double amount; // cộng hoa hồng: dương, rút tiền: âm
  final String? orderId;
  final String? withdrawalId;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.sellerId,
    required this.type,
    required this.amount,
    this.orderId,
    this.withdrawalId,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) =>
      WalletTransaction(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        type: WalletTxType.fromString(j['type'] as String?),
        amount: toDouble(j['amount']),
        orderId: j['order_id'] as String?,
        withdrawalId: j['withdrawal_id'] as String?,
        createdAt: toDate(j['created_at']),
      );
}