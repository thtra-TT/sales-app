import 'json_helpers.dart';

class Customer {
  final String id;
  final String sellerId;
  final String name;
  final String? phone;
  final String? contactChannel; // Zalo / Facebook / ...
  final String? address;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.sellerId,
    required this.name,
    this.phone,
    this.contactChannel,
    this.address,
    this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        contactChannel: j['contact_channel'] as String?,
        address: j['address'] as String?,
        createdAt: toDate(j['created_at']),
      );

  /// seller_id tự lấy từ auth.uid() ở DB nên không cần gửi.
  static Map<String, dynamic> toInsertJson({
    required String name,
    String? phone,
    String? contactChannel,
    String? address,
  }) =>
      {
        'name': name,
        'phone': phone,
        'contact_channel': contactChannel,
        'address': address,
      };
}