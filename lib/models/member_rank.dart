import 'json_helpers.dart';

class MemberRank {
  final int id;
  final String name;
  final double minSpent;
  final double discountPercent;
  final double commissionPercent;

  const MemberRank({
    required this.id,
    required this.name,
    required this.minSpent,
    required this.discountPercent,
    required this.commissionPercent,
  });

  factory MemberRank.fromJson(Map<String, dynamic> j) => MemberRank(
        id: j['id'] as int,
        name: j['name'] as String,
        minSpent: toDouble(j['min_spent']),
        discountPercent: toDouble(j['discount_percent']),
        commissionPercent: toDouble(j['commission_percent']),
      );
}