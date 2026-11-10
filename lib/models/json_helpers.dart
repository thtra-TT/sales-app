/// Hàm tiện ích đọc JSON từ Supabase (numeric có thể về int hoặc double).
double toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;

double? toDoubleOrNull(dynamic v) => (v as num?)?.toDouble();

DateTime? toDate(dynamic v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();