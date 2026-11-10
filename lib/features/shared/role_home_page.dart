import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

/// Khung tạm cho 3 role: hiện thông tin tài khoản + nút đăng xuất.
class RoleHomePage extends ConsumerWidget {
  final String title;
  final IconData icon;
  final bool showWallet;
  final List<String> upcoming;

  const RoleHomePage({
    super.key,
    required this.title,
    required this.icon,
    required this.upcoming,
    this.showWallet = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final money = NumberFormat.decimalPattern('vi_VN');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(profile?.fullName?.isNotEmpty == true
                  ? profile!.fullName!
                  : 'Chưa đặt tên'),
              subtitle: Text(profile?.role.label ?? ''),
            ),
          ),
          if (showWallet && profile != null) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text('Hạng: ${profile.rankName ?? '-'}'),
                    subtitle: Text(
                      'Giảm giá ${profile.discountPercent}% · '
                      'Hoa hồng ${profile.commissionPercent}%',
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Số dư ví'),
                    trailing: Text('${money.format(profile.walletBalance)} đ'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Sắp làm', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in upcoming)
            ListTile(
              dense: true,
              leading: const Icon(Icons.check_box_outline_blank),
              title: Text(s),
            ),
        ],
      ),
    );
  }
}