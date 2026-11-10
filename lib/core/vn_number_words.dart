/// Đọc số tiền thành chữ tiếng Việt: 1250000 -> "Một triệu hai trăm năm mươi nghìn đồng".

const _digits = [
  'không',
  'một',
  'hai',
  'ba',
  'bốn',
  'năm',
  'sáu',
  'bảy',
  'tám',
  'chín',
];
const _units = ['', 'nghìn', 'triệu', 'tỷ', 'nghìn tỷ', 'triệu tỷ'];

/// Đọc 1 nhóm 3 chữ số (0..999). [full] = true khi không phải nhóm đầu
/// (phải đọc "không trăm" / "lẻ" cho đúng, vd 1.005.000).
String _readTriple(int n, {required bool full}) {
  final h = n ~/ 100;
  final t = (n % 100) ~/ 10;
  final u = n % 10;
  final parts = <String>[];

  if (h > 0 || full) parts.add('${_digits[h]} trăm');

  if (t > 1) {
    parts.add('${_digits[t]} mươi');
    if (u == 1) {
      parts.add('mốt');
    } else if (u == 5) {
      parts.add('lăm');
    } else if (u > 0) {
      parts.add(_digits[u]);
    }
  } else if (t == 1) {
    parts.add('mười');
    if (u == 5) {
      parts.add('lăm');
    } else if (u > 0) {
      parts.add(_digits[u]);
    }
  } else if (u > 0) {
    if (h > 0 || full) parts.add('lẻ');
    parts.add(_digits[u]);
  }
  return parts.join(' ');
}

/// Trả về chuỗi rỗng nếu số quá lớn để đọc.
String vnMoneyInWords(num amount) {
  var n = amount.round();
  if (n <= 0) return 'Không đồng';

  final groups = <int>[];
  while (n > 0) {
    groups.add(n % 1000);
    n ~/= 1000;
  }
  if (groups.length > _units.length) return '';

  final parts = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    if (g == 0) continue;
    final words = _readTriple(g, full: i != groups.length - 1);
    parts.add(_units[i].isEmpty ? words : '$words ${_units[i]}');
  }
  final s = parts.join(' ');
  return '${s[0].toUpperCase()}${s.substring(1)} đồng';
}