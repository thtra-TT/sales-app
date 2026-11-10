import 'json_helpers.dart';

/// Đặt tên AppNotification để không trùng với class Notification của Flutter.
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String? proofUrl; // ảnh minh chứng chuyển khoản (nếu có)
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.proofUrl,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        proofUrl: j['proof_url'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: toDate(j['created_at']),
      );
}