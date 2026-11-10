import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Hiện khi đã đăng nhập nhưng đang tải profile (hoặc tải lỗi).
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final noProfile = profile.hasValue && profile.value == null;

    String? message;
    if (noProfile) {
      message = 'Không tìm thấy hồ sơ người dùng. Hãy liên hệ quản trị viên.';
    } else if (profile.hasError) {
      message = 'Không tải được hồ sơ: ${profile.error}';
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message == null)
                const CircularProgressIndicator()
              else ...[
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(profileProvider),
                  child: const Text('Thử lại'),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}