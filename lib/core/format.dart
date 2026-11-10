import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException, StorageException, Supabase;

final _money = NumberFormat.decimalPattern('vi_VN');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

String formatMoney(num v) => '${_money.format(v)} đ';

String formatDateTime(DateTime? d) => d == null ? '-' : _dateTime.format(d);

/// 5.0 -> "5", 7.5 -> "7.5"
String formatPercent(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

String? nullIfEmpty(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// Phương thức thanh toán: key lưu trong DB -> chữ hiển thị.
const paymentMethods = <String, String>{
  'cash': 'Tiền mặt',
  'transfer': 'Chuyển khoản',
  'other': 'Khác',
};

String paymentMethodLabel(String? v) => paymentMethods[v] ?? (v ?? '-');

const contactChannels = <String>[
  'Zalo',
  'Facebook',
  'Instagram',
  'TikTok',
  'Điện thoại',
  'Khác',
];

/// Lấy câu thông báo lỗi dễ đọc (kể cả lỗi `raise exception` từ trigger).
String errorText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  if (e is AuthException) return e.message;
  return e.toString();
}

/// Bucket public chứa ảnh sản phẩm (dùng khi cột image_url chỉ lưu đường dẫn file).
const productImageBucket = 'product-images';

/// image_url có thể là link đầy đủ (https://...) hoặc đường dẫn trong bucket
/// `product-images`. Trả về link dùng được, hoặc null nếu chưa có ảnh.
String? resolveImageUrl(String? v) {
  final s = v?.trim();
  if (s == null || s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  return Supabase.instance.client.storage
      .from(productImageBucket)
      .getPublicUrl(s);
}