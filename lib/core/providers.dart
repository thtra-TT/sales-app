import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient, AuthState;

import '../models/user_profile.dart';

final supabaseProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Luồng sự kiện đăng nhập / đăng xuất của Supabase.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

/// id người dùng hiện tại (null = chưa đăng nhập).
/// Chỉ thay đổi khi đổi user, không đổi khi token tự refresh.
final userIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseProvider);
  final uid = ref.watch(
    authStateProvider.select((s) => s.value?.session?.user.id),
  );
  return uid ?? client.auth.currentUser?.id;
});

/// Hồ sơ (role, rank, ví) của người dùng hiện tại.
final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final uid = ref.watch(userIdProvider);
  if (uid == null) return null;

  final data = await ref
      .watch(supabaseProvider)
      .from('profiles')
      .select('*, member_ranks(name, discount_percent, commission_percent)')
      .eq('id', uid)
      .maybeSingle();

  if (data == null) return null;
  return UserProfile.fromJson(data);
});