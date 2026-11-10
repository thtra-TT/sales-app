import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart'
    show FileOptions, SupabaseClient;

import '../../../models/models.dart';

/// Toàn bộ lệnh gọi Supabase của role Người bán.
/// Quyền thật sự do RLS ở database quyết định, ví dụ người bán chỉ thấy đơn của mình.
/// Các hàm search* / fetch*Page đều phân trang (offset + limit) để chạy tốt
/// khi có hàng nghìn sản phẩm, item, khách hàng, đơn hàng.
class SellerRepository {
  SellerRepository(this._db);
  final SupabaseClient _db;

  static const _orderSelect = '*, customers(*), order_items(*)';

  /// Bỏ ký tự đặc biệt để không làm hỏng câu lọc của PostgREST.
  static String _term(String q) =>
      q.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  // ---------- Đơn hàng ----------
  Future<List<Order>> fetchOrdersPage({
    PaymentStatus? status,
    String query = '',
    required int offset,
    required int limit,
  }) async {
    final term = _term(query);
    var q = _db.from('orders').select(_orderSelect);
    if (status != null) q = q.eq('payment_status', status.value);
    if (term.isNotEmpty) q = q.ilike('code', '%$term%');
    final rows = await q
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map(Order.fromJson).toList();
  }

  Future<Order> fetchOrder(String id) async {
    final row =
        await _db.from('orders').select(_orderSelect).eq('id', id).single();
    return Order.fromJson(row);
  }

  /// Gọi hàm create_order (tạo đơn + các dòng trong 1 transaction).
  Future<String> createOrder({
    required String customerId,
    required bool needInvoice,
    Map<String, dynamic>? invoiceInfo,
    required Map<String, int> quantities, // product_item_id -> số lượng
  }) async {
    final res = await _db.rpc('create_order', params: {
      'p_customer_id': customerId,
      'p_need_invoice': needInvoice,
      'p_invoice_info': invoiceInfo,
      'p_items': [
        for (final e in quantities.entries)
          {'product_item_id': e.key, 'quantity': e.value},
      ],
    });
    return res as String;
  }

  /// Upload ảnh minh chứng rồi chuyển đơn sang "đã thanh toán".
  /// Hoa hồng, ví, rank do trigger ở DB tự xử lý.
  Future<void> markPaid({
    required String orderId,
    required String uid,
    required String method,
    required Uint8List bytes,
    required String ext,
  }) async {
    final e = ext.toLowerCase();
    final mime = switch (e) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    // Thư mục đầu tiên phải là uid (theo policy của storage)
    final path = '$uid/$orderId-${DateTime.now().millisecondsSinceEpoch}.$e';

    await _db.storage
        .from('payment-proofs')
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));

    await _db.from('orders').update({
      'payment_method': method,
      'payment_proof_url': path,
      'payment_status': 'paid',
    }).eq('id', orderId);
  }

  // ---------- Sản phẩm / item / khách hàng (tìm kiếm + phân trang) ----------
  Future<List<Product>> searchProducts({
    String query = '',
    required int offset,
    required int limit,
  }) async {
    final term = _term(query);
    var q = _db.from('products').select().eq('is_active', true);
    if (term.isNotEmpty) q = q.ilike('name', '%$term%');
    final rows =
        await q.order('name').order('id').range(offset, offset + limit - 1);
    return rows.map(Product.fromJson).toList();
  }

  Future<List<ProductItem>> searchProductItems({
    required String productId,
    String query = '',
    required int offset,
    required int limit,
  }) async {
    final term = _term(query);
    var q = _db
        .from('product_items')
        .select()
        .eq('product_id', productId)
        .eq('is_active', true);
    if (term.isNotEmpty) q = q.ilike('name', '%$term%');
    final rows =
        await q.order('name').order('id').range(offset, offset + limit - 1);
    return rows.map(ProductItem.fromJson).toList();
  }

  Future<List<Customer>> searchCustomers({
    String query = '',
    required int offset,
    required int limit,
  }) async {
    final term = _term(query);
    var q = _db.from('customers').select();
    if (term.isNotEmpty) {
      q = q.or('name.ilike.%$term%,phone.ilike.%$term%');
    }
    final rows = await q
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return rows.map(Customer.fromJson).toList();
  }

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? contactChannel,
    String? address,
  }) async {
    final row = await _db
        .from('customers')
        .insert(Customer.toInsertJson(
          name: name,
          phone: phone,
          contactChannel: contactChannel,
          address: address,
        ))
        .select()
        .single();
    return Customer.fromJson(row);
  }

  // ---------- Rank / ví / rút tiền ----------
  Future<List<MemberRank>> fetchRanks() async {
    final rows = await _db.from('member_ranks').select().order('min_spent');
    return rows.map(MemberRank.fromJson).toList();
  }

  Future<List<WalletTransaction>> fetchWalletTransactions() async {
    final rows = await _db
        .from('wallet_transactions')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(WalletTransaction.fromJson).toList();
  }

  Future<List<WithdrawalRequest>> fetchWithdrawals() async {
    final rows = await _db
        .from('withdrawal_requests')
        .select()
        .order('created_at', ascending: false);
    return rows.map(WithdrawalRequest.fromJson).toList();
  }

  Future<void> requestWithdraw(double amount) async {
    await _db
        .from('withdrawal_requests')
        .insert(WithdrawalRequest.toInsertJson(amount: amount));
  }

  // ---------- Thông báo ----------
  Future<List<AppNotification>> fetchNotifications() async {
    final rows = await _db
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }
}