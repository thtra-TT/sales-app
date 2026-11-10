import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import 'accounts_page.dart';
import 'audit_log_page.dart';
import 'ranks_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final name = profile?.fullName?.isNotEmpty == true
        ? profile!.fullName!
        : 'Chưa đặt tên';

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [kBrand, kBrandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings_outlined,
                  color: kBrand, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                Text(profile?.role.label ?? '',
                    style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const _Section('Hệ thống'),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined, color: kBrand),
              title: const Text('Quản lý tài khoản'),
              subtitle: const Text('Tạo tài khoản người bán, kỹ thuật sản xuất'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const AccountsPage()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined, color: kBrand),
              title: const Text('Hạng thành viên'),
              subtitle: const Text('Ngưỡng chi tiêu, giảm giá, hoa hồng'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const RanksPage()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history, color: kBrand),
              title: const Text('Nhật ký thao tác'),
              subtitle: const Text('Ai duyệt rút tiền, đổi giá, đổi hạng, khoá tài khoản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _go(context, const AuditLogPage()),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF757575))),
      );
}