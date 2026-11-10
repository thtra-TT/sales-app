import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';
import 'seller_repository.dart';

final sellerRepoProvider = Provider<SellerRepository>(
  (ref) => SellerRepository(ref.watch(supabaseProvider)),
);

// Các provider dữ liệu riêng của từng người dùng đều watch userIdProvider
// để tự tải lại khi đổi tài khoản.

final orderDetailProvider =
    FutureProvider.autoDispose.family<Order, String>((ref, id) {
  ref.watch(userIdProvider);
  return ref.watch(sellerRepoProvider).fetchOrder(id);
});

final ranksProvider = FutureProvider<List<MemberRank>>((ref) {
  return ref.watch(sellerRepoProvider).fetchRanks();
});

final myWalletTxProvider =
    FutureProvider.autoDispose<List<WalletTransaction>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(sellerRepoProvider).fetchWalletTransactions();
});

final myWithdrawalsProvider =
    FutureProvider.autoDispose<List<WithdrawalRequest>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(sellerRepoProvider).fetchWithdrawals();
});

final myNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(sellerRepoProvider).fetchNotifications();
});

/// Một file trong Supabase Storage (bucket + đường dẫn).
typedef StorageFile = ({String bucket, String path});

/// Link tạm (1 giờ) để xem ảnh trong bucket private.
final signedUrlProvider =
    FutureProvider.autoDispose.family<String, StorageFile>((ref, file) {
  return ref
      .watch(supabaseProvider)
      .storage
      .from(file.bucket)
      .createSignedUrl(file.path, 3600);
});