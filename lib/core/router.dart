import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/auth/splash_page.dart';
import '../features/manager/manager_home.dart';
import '../features/production/production_home.dart';
import '../features/seller/seller_home.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Mỗi khi đăng nhập/đăng xuất hoặc profile đổi -> chạy lại redirect.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(userIdProvider, (_, __) => refresh.value++);
  ref.listen(profileProvider, (_, __) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 1. Chưa đăng nhập -> /login
      final uid = ref.read(userIdProvider);
      if (uid == null) return loc == '/login' ? null : '/login';

      // 2. Đã đăng nhập nhưng chưa có profile của đúng user này -> /splash
      final profile = ref.read(profileProvider).value;
      if (profile == null || profile.id != uid) {
        return loc == '/splash' ? null : '/splash';
      }

      // 3. Có role -> chỉ được ở khu vực của role đó
      final home = profile.role.homePath;
      return loc.startsWith(home) ? null : home;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/seller', builder: (_, __) => const SellerHome()),
      GoRoute(path: '/production', builder: (_, __) => const ProductionHome()),
      GoRoute(path: '/manager', builder: (_, __) => const ManagerHome()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});