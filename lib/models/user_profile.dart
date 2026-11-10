enum UserRole {
  seller,
  production,
  manager;

  static UserRole fromString(String? v) => UserRole.values.firstWhere(
        (r) => r.name == v,
        orElse: () => UserRole.seller,
      );

  String get homePath => '/$name';

  String get label => switch (this) {
        UserRole.seller => 'Người bán',
        UserRole.production => 'Sản xuất kỹ thuật',
        UserRole.manager => 'Quản lý',
      };
}

class UserProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final UserRole role;
  final String? rankName;
  final double discountPercent;
  final double commissionPercent;
  final double totalSpent;
  final double walletBalance;

  const UserProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.rankName,
    this.discountPercent = 0,
    this.commissionPercent = 0,
    this.totalSpent = 0,
    this.walletBalance = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rank = json['member_ranks'] as Map<String, dynamic>?;
    double num0(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      rankName: rank?['name'] as String?,
      discountPercent: num0(rank?['discount_percent']),
      commissionPercent: num0(rank?['commission_percent']),
      totalSpent: num0(json['total_spent']),
      walletBalance: num0(json['wallet_balance']),
    );
  }
}