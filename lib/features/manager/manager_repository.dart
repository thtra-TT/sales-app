import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, FileOptions;

import '../../core/providers.dart';
import '../../models/models.dart';

final managerRepositoryProvider = Provider<ManagerRepository>(
  (ref) => ManagerRepository(ref.watch(supabaseProvider)),
);

class ItemInput {
  final String name;
  final double price;
  const ItemInput(this.name, this.price);
}

class ManagerRepository {
  final SupabaseClient _db;
  ManagerRepository(this._db);

  static const _orderSelect =
      '*, customers(*), order_items(*), profiles(full_name)';

  /// RLS không báo lỗi khi từ chối ghi, chỉ trả 0 dòng -> tự kiểm tra.
  void _mustAffect(List rows, String what) {
    if (rows.isEmpty) {
      throw 'Không $what được (không có quyền hoặc dữ liệu không tồn tại).';
    }
  }

  // ---------------- UC13: sản phẩm ----------------

  Future<List<Product>> fetchProducts() async {
    final data = await _db
        .from('products')
        .select('*, product_items(*)')
        .order('created_at', ascending: false);
    return data.map<Product>(Product.fromJson).toList();
  }

  Future<void> createProduct({
    required String name,
    String? description,
    required List<ItemInput> items,
  }) async {
    final p = await _db
        .from('products')
        .insert(Product.toInsertJson(name: name, description: description))
        .select()
        .single();
    final id = p['id'] as String;
    try {
      await _db.from('product_items').insert([
        for (final i in items)
          ProductItem.toInsertJson(
              productId: id, name: i.name, price: i.price),
      ]);
    } catch (_) {
      // Chưa có đơn nào dùng -> xoá hẳn để không để lại sản phẩm rỗng.
      await _db.from('products').delete().eq('id', id);
      rethrow;
    }
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    String? description,
    required bool isActive,
  }) async {
    final r = await _db
        .from('products')
        .update({'name': name, 'description': description, 'is_active': isActive})
        .eq('id', id)
        .select();
    _mustAffect(r, 'cập nhật sản phẩm');
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required double price,
    required bool isActive,
  }) async {
    final r = await _db
        .from('product_items')
        .update({'name': name, 'price': price, 'is_active': isActive})
        .eq('id', id)
        .select();
    _mustAffect(r, 'cập nhật item');
  }

  Future<void> addItem({
    required String productId,
    required String name,
    required double price,
  }) async {
    await _db.from('product_items').insert(
        ProductItem.toInsertJson(productId: productId, name: name, price: price));
  }

  // ---------------- UC14 / UC15: đơn hàng ----------------

  Future<List<({String id, String name})>> fetchSellers() async {
    final data = await _db
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'seller')
        .order('full_name');
    return [
      for (final e in data)
        (id: e['id'] as String, name: (e['full_name'] as String?) ?? 'Chưa đặt tên'),
    ];
  }

  Future<List<Order>> fetchOrders({
    PaymentStatus? payment,
    DeliveryStatus? delivery,
    String? sellerId,
    DateTimeRange? range,
  }) async {
    var q = _db.from('orders').select(_orderSelect);
    if (payment != null) q = q.eq('payment_status', payment.value);
    if (delivery != null) q = q.eq('delivery_status', delivery.value);
    if (sellerId != null) q = q.eq('seller_id', sellerId);
    if (range != null) {
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day)
          .add(const Duration(days: 1));
      q = q
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String());
    }
    final data = await q.order('created_at', ascending: false);
    return data.map<Order>(Order.fromJson).toList();
  }

  Future<Order> fetchOrder(String id) async {
    final data =
        await _db.from('orders').select(_orderSelect).eq('id', id).single();
    return Order.fromJson(data);
  }

  Future<void> setDeliveryStatus(String orderId, DeliveryStatus status) async {
    final r = await _db
        .from('orders')
        .update({'delivery_status': status.value})
        .eq('id', orderId)
        .select();
    _mustAffect(r, 'cập nhật giao hàng');
  }

  Future<String> signedPaymentProofUrl(String path) =>
      _db.storage.from('payment-proofs').createSignedUrl(path, 3600);

  // ---------------- UC16: sổ bán hàng ----------------

  Future<List<SalesLedgerEntry>> fetchLedger(DateTimeRange range) async {
    final f = DateFormat('yyyy-MM-dd');
    final data = await _db
        .from('sales_ledger')
        .select()
        .gte('sale_date', f.format(range.start))
        .lte('sale_date', f.format(range.end))
        .order('sale_date', ascending: false)
        .order('order_code', ascending: false);
    return data.map<SalesLedgerEntry>(SalesLedgerEntry.fromJson).toList();
  }

  // ---------------- UC17 / UC18: rút tiền ----------------

  Future<List<WithdrawalRequest>> fetchWithdrawals({WithdrawStatus? status}) async {
    // withdrawal_requests có 2 FK tới profiles (seller_id, processed_by)
    // -> phải chỉ rõ seller_id, nếu không PostgREST báo mơ hồ.
    var q = _db.from('withdrawal_requests').select('*, profiles!seller_id(full_name)');
    if (status != null) q = q.eq('status', status.value);
    final data = await q.order('created_at', ascending: false);
    return data.map<WithdrawalRequest>(WithdrawalRequest.fromJson).toList();
  }

  Future<double> fetchWalletBalance(String sellerId) async {
    final d = await _db
        .from('profiles')
        .select('wallet_balance')
        .eq('id', sellerId)
        .single();
    return (d['wallet_balance'] as num?)?.toDouble() ?? 0;
  }

  Future<String> uploadWithdrawProof({
    required String requestId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dot = fileName.lastIndexOf('.');
    var ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'jpg';
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
    final path = '$requestId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('withdraw-proofs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext',
          ),
        );
    return path;
  }

  Future<String> signedProofUrl(String path) =>
      _db.storage.from('withdraw-proofs').createSignedUrl(path, 3600);

  /// Trigger ở DB lo: trừ ví, ghi sổ ví, gửi thông báo kèm minh chứng.
  Future<void> approveWithdrawal(String id, String proofPath) async {
    final r = await _db
        .from('withdrawal_requests')
        .update({'status': 'approved', 'proof_url': proofPath})
        .eq('id', id)
        .select();
    _mustAffect(r, 'duyệt yêu cầu');
  }

  Future<void> rejectWithdrawal(String id, String reason) async {
    final r = await _db
        .from('withdrawal_requests')
        .update({'status': 'rejected', 'note': reason})
        .eq('id', id)
        .select();
    _mustAffect(r, 'từ chối yêu cầu');
  }

  // ---------------- UC19: hạng thành viên ----------------

  Future<List<MemberRank>> fetchRanks() async {
    final data = await _db.from('member_ranks').select().order('min_spent');
    return data.map<MemberRank>(MemberRank.fromJson).toList();
  }

  Future<void> saveRank({
    int? id,
    required String name,
    required double minSpent,
    required double discountPercent,
    required double commissionPercent,
  }) async {
    final body = {
      'name': name,
      'min_spent': minSpent,
      'discount_percent': discountPercent,
      'commission_percent': commissionPercent,
    };
    if (id == null) {
      await _db.from('member_ranks').insert(body);
    } else {
      final r = await _db.from('member_ranks').update(body).eq('id', id).select();
      _mustAffect(r, 'cập nhật hạng (đã chạy sql/manager_migration.sql chưa?)');
    }
  }
}