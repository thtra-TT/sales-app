import 'dart:typed_data';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show SupabaseClient, FileOptions;

import '../../core/providers.dart';
import '../../models/json_helpers.dart' show toDate;
import '../../models/models.dart';

final managerRepositoryProvider = Provider<ManagerRepository>(
  (ref) => ManagerRepository(ref.watch(supabaseProvider)),
);

class ItemInput {
  final String name;
  final double price;
  final String? imageUrl;
  const ItemInput(this.name, this.price, [this.imageUrl]);
}

class AccountRow {
  final String id;
  final String? fullName;
  final String? phone;
  final String? email;
  final UserRole role;
  final bool isActive;
  const AccountRow({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.email,
    this.isActive = true,
  });

  factory AccountRow.fromJson(Map<String, dynamic> j) => AccountRow(
        id: j['id'] as String,
        fullName: j['full_name'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        role: UserRole.fromString(j['role'] as String?),
        isActive: j['is_active'] as bool? ?? true,
      );
}

class AuditLog {
  final int id;
  final String? actorName;
  final String action; // vd: withdrawal.approve
  final Map<String, dynamic> detail;
  final DateTime? createdAt;
  const AuditLog({
    required this.id,
    required this.action,
    required this.detail,
    this.actorName,
    this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['id'] as int,
        actorName: j['actor_name'] as String?,
        action: j['action'] as String,
        detail: Map<String, dynamic>.from((j['detail'] as Map?) ?? const {}),
        createdAt: toDate(j['created_at']),
      );
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
    String? imageUrl,
    required List<ItemInput> items,
  }) async {
    final p = await _db
        .from('products')
        .insert({
          ...Product.toInsertJson(name: name, description: description),
          'image_url': imageUrl,
        })
        .select()
        .single();
    final id = p['id'] as String;
    try {
      await _db.from('product_items').insert([
        for (final i in items)
          {
            ...ProductItem.toInsertJson(
                productId: id, name: i.name, price: i.price),
            'image_url': i.imageUrl,
          },
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
    required String? imageUrl,
    required bool isActive,
  }) async {
    final r = await _db
        .from('products')
        .update({
          'name': name,
          'description': description,
          'image_url': imageUrl,
          'is_active': isActive,
        })
        .eq('id', id)
        .select();
    _mustAffect(r, 'cập nhật sản phẩm');
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required double price,
    required String? imageUrl,
    required bool isActive,
  }) async {
    final r = await _db
        .from('product_items')
        .update({
          'name': name,
          'price': price,
          'image_url': imageUrl,
          'is_active': isActive,
        })
        .eq('id', id)
        .select();
    _mustAffect(r, 'cập nhật item');
  }

  Future<void> addItem({
    required String productId,
    required String name,
    required double price,
    String? imageUrl,
  }) async {
    await _db.from('product_items').insert({
      ...ProductItem.toInsertJson(productId: productId, name: name, price: price),
      'image_url': imageUrl,
    });
  }

  /// Bucket `product-images` để public -> lưu thẳng URL công khai vào image_url.
  Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dot = fileName.lastIndexOf('.');
    var ext = dot >= 0 ? fileName.substring(dot + 1).toLowerCase() : 'jpg';
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
    final path = 'img/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _db.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext',
          ),
        );
    return _db.storage.from('product-images').getPublicUrl(path);
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

  // ---------------- Quản lý tài khoản ----------------

  Future<List<AccountRow>> fetchAccounts({UserRole? role}) async {
    var q = _db
        .from('profiles')
        .select('id, full_name, phone, email, role, is_active');
    if (role != null) q = q.eq('role', role.name);
    final data = await q.order('created_at', ascending: false);
    return data.map<AccountRow>(AccountRow.fromJson).toList();
  }

  /// Thao tác cần service role -> gọi Edge Function `create-user`.
  Future<void> _callAccountFunction(Map<String, dynamic> body) async {
    final res = await _db.functions.invoke('create-user', body: body);
    final d = res.data;
    if (d is Map && d['error'] != null) throw d['error'].toString();
  }

  Future<void> createAccount({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required UserRole role,
  }) =>
      _callAccountFunction({
        'action': 'create',
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': role.name,
      });

  Future<void> setAccountActive(String id, bool active) =>
      _callAccountFunction({'action': 'set_active', 'id': id, 'active': active});

  Future<void> resetPassword(String id, String password) => _callAccountFunction(
      {'action': 'reset_password', 'id': id, 'password': password});

  Future<void> updateAccount({
    required String id,
    required String fullName,
    String? phone,
  }) async {
    final r = await _db
        .from('profiles')
        .update({'full_name': fullName, 'phone': phone})
        .eq('id', id)
        .select();
    _mustAffect(r, 'cập nhật tài khoản');
  }

  // ---------------- Nhật ký thao tác ----------------

  /// [prefix] lọc theo nhóm hành động, vd 'withdrawal.' / 'item.' / 'rank.'
  Future<List<AuditLog>> fetchAuditLogs({String? prefix, int limit = 100}) async {
    var q = _db.from('audit_logs').select();
    if (prefix != null) q = q.like('action', '$prefix%');
    final data = await q.order('created_at', ascending: false).limit(limit);
    return data.map<AuditLog>(AuditLog.fromJson).toList();
  }
}