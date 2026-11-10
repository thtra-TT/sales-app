import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../../models/models.dart';

/// Role Sản xuất kỹ thuật chỉ làm việc với view `production_tasks`:
/// mỗi dòng là 1 sản phẩm (item) của 1 đơn ĐÃ THANH TOÁN, không có khách hàng,
/// không có giá tiền, không có thông tin đơn hàng.
class ProductionRepository {
  ProductionRepository(this._db);
  final SupabaseClient _db;

  static String _term(String q) =>
      q.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  /// Phân trang + lọc trạng thái + tìm theo mã đơn / sản phẩm / mục.
  /// Sắp xếp: việc chưa làm lên trước, trong cùng trạng thái thì đơn thanh toán
  /// sớm nhất làm trước.
  Future<List<ProductionTask>> fetchTasks({
    ProductionStatus? status,
    String query = '',
    required int offset,
    required int limit,
  }) async {
    final term = _term(query);
    var q = _db.from('production_tasks').select();
    if (status != null) q = q.eq('production_status', status.value);
    if (term.isNotEmpty) {
      q = q.or(
        'order_code.ilike.%$term%,'
        'product_name.ilike.%$term%,'
        'item_name.ilike.%$term%',
      );
    }
    final rows = await q
        .order('production_status')
        .order('paid_at')
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map(ProductionTask.fromJson).toList();
  }

  /// Gọi hàm set_production_status ở DB (kiểm tra quyền + chỉ đơn đã thanh toán).
  Future<void> setStatus({
    required String itemId,
    required ProductionStatus status,
  }) async {
    await _db.rpc('set_production_status', params: {
      'p_item_id': itemId,
      'p_status': status.value,
    });
  }
}