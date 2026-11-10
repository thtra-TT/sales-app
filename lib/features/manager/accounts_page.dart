import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

Color _roleColor(UserRole r) => switch (r) {
      UserRole.seller => Colors.blue,
      UserRole.production => Colors.purple,
      UserRole.manager => kBrand,
    };

/// Quản lý tài khoản: xem danh sách, tạo tài khoản người bán / sản xuất.
class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  UserRole? _filter;
  late Future<List<AccountRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AccountRow>> _load() =>
      ref.read(managerRepositoryProvider).fetchAccounts(role: _filter);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _create() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AccountFormPage()),
    );
    if (ok == true) {
      if (mounted) showSnack(context, 'Đã tạo tài khoản.');
      _reload();
    }
  }

  Future<void> _edit(AccountRow a) async {
    final res = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _EditDialog(account: a),
    );
    if (res == null) return;
    try {
      await ref.read(managerRepositoryProvider).updateAccount(
            id: a.id,
            fullName: res.$1,
            phone: res.$2,
          );
      if (mounted) showSnack(context, 'Đã cập nhật.');
      _reload();
    } catch (e) {
      showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _toggleActive(AccountRow a) async {
    final lock = a.isActive;
    final name = a.fullName?.isNotEmpty == true ? a.fullName! : (a.email ?? 'tài khoản này');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(lock ? 'Khoá tài khoản' : 'Mở khoá tài khoản'),
        content: Text(lock
            ? '$name sẽ không đăng nhập được nữa. Dữ liệu đơn hàng, ví vẫn giữ nguyên. '
                'Phiên đang mở có thể còn hiệu lực tối đa khoảng 1 giờ.'
            : '$name sẽ đăng nhập lại được bình thường.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: lock ? Colors.red : kBrand,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lock ? 'Khoá' : 'Mở khoá'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(managerRepositoryProvider).setAccountActive(a.id, !lock);
      if (mounted) showSnack(context, lock ? 'Đã khoá tài khoản.' : 'Đã mở khoá tài khoản.');
      _reload();
    } catch (e) {
      showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _resetPassword(AccountRow a) async {
    final pass = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(account: a),
    );
    if (pass == null) return;
    try {
      await ref.read(managerRepositoryProvider).resetPassword(a.id, pass);
      if (mounted) {
        showSnack(context, 'Đã đặt lại mật khẩu. Hãy gửi mật khẩu mới cho nhân viên.');
      }
    } catch (e) {
      showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý tài khoản'),
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _reload,
                icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab_accounts',
          onPressed: _create,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Tạo tài khoản'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: _filter == null,
                  onSelected: (_) {
                    _filter = null;
                    _reload();
                  },
                ),
                for (final r in UserRole.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: _filter == r,
                    onSelected: (_) {
                      _filter = r;
                      _reload();
                    },
                  ),
              ]),
            ),
          ),
          Expanded(
            child: FutureBody<List<AccountRow>>(
              future: _future,
              onRetry: _reload,
              builder: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('Chưa có tài khoản nào.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final a = list[i];
                      final canEdit = a.role != UserRole.manager;
                      return Card(
                        child: Opacity(
                          opacity: a.isActive ? 1 : 0.6,
                          child: ListTile(
                            onTap: canEdit ? () => _edit(a) : null,
                            leading: CircleAvatar(
                              backgroundColor:
                                  _roleColor(a.role).withValues(alpha: 0.15),
                              child: Icon(
                                  a.isActive ? Icons.person : Icons.lock_outline,
                                  color: _roleColor(a.role)),
                            ),
                            title: Text(
                              a.fullName?.isNotEmpty == true
                                  ? a.fullName!
                                  : 'Chưa đặt tên',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (a.email != null) Text(a.email!),
                                if (a.phone != null && a.phone!.isNotEmpty)
                                  Text(a.phone!),
                                if (a.role == UserRole.seller &&
                                    a.totalCommission != null) ...[
                                  const SizedBox(height: 4),
                                  Text.rich(TextSpan(children: [
                                    const TextSpan(text: 'Hoa hồng đã nhận: '),
                                    TextSpan(
                                      text: money(a.totalCommission!),
                                      style: const TextStyle(
                                          color: kPriceColor,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    TextSpan(text: ' (${a.commissionOrders ?? 0} đơn)'),
                                  ])),
                                ],
                                if (a.role == UserRole.seller && a.walletBalance != null)
                                  Text('Số dư ví: ${money(a.walletBalance!)}'),
                                const SizedBox(height: 4),
                                Wrap(spacing: 6, children: [
                                  StatusChip(a.role.label, _roleColor(a.role)),
                                  if (!a.isActive)
                                    const StatusChip('Đã khoá', Colors.red),
                                ]),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: canEdit
                                ? PopupMenuButton<String>(
                                    onSelected: (v) {
                                      switch (v) {
                                        case 'edit':
                                          _edit(a);
                                        case 'password':
                                          _resetPassword(a);
                                        case 'active':
                                          _toggleActive(a);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                          value: 'edit', child: Text('Sửa thông tin')),
                                      const PopupMenuItem(
                                          value: 'password',
                                          child: Text('Đặt lại mật khẩu')),
                                      PopupMenuItem(
                                        value: 'active',
                                        child: Text(
                                          a.isActive ? 'Khoá tài khoản' : 'Mở khoá tài khoản',
                                          style: TextStyle(
                                              color: a.isActive ? Colors.red : Colors.green),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

class _EditDialog extends StatefulWidget {
  final AccountRow account;
  const _EditDialog({required this.account});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _name = TextEditingController(text: widget.account.fullName ?? '');
  late final _phone = TextEditingController(text: widget.account.phone ?? '');
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sửa tài khoản'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: 'Họ tên *', errorText: _err),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {
              if (_name.text.trim().isEmpty) {
                setState(() => _err = 'Không được để trống');
                return;
              }
              final p = _phone.text.trim();
              Navigator.pop(context, (_name.text.trim(), p.isEmpty ? null : p));
            },
            child: const Text('Lưu'),
          ),
        ],
      );
}

class _ResetPasswordDialog extends StatefulWidget {
  final AccountRow account;
  const _ResetPasswordDialog({required this.account});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _pass = TextEditingController();
  bool _show = false;
  String? _err;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  void _generate() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    setState(() {
      _pass.text = List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
      _show = true; // hiện ra để quản lý đọc / sao chép gửi cho nhân viên
      _err = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return AlertDialog(
      title: const Text('Đặt lại mật khẩu'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${a.fullName ?? a.email ?? ''}'.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: !_show,
          decoration: InputDecoration(
            labelText: 'Mật khẩu mới *',
            errorText: _err,
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: _show ? 'Ẩn' : 'Hiện',
                icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _show = !_show),
              ),
              IconButton(
                tooltip: 'Sao chép',
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _pass.text));
                  showSnack(context, 'Đã sao chép mật khẩu.');
                },
              ),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Tạo ngẫu nhiên'),
          ),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            if (_pass.text.length < 6) {
              setState(() => _err = 'Ít nhất 6 ký tự');
              return;
            }
            Navigator.pop(context, _pass.text);
          },
          child: const Text('Đặt lại'),
        ),
      ],
    );
  }
}

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key});

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  UserRole _role = UserRole.seller;
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    if (_name.text.trim().isEmpty) {
      return showSnack(context, 'Họ tên không được để trống.', error: true);
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return showSnack(context, 'Email không hợp lệ.', error: true);
    }
    if (_pass.text.length < 6) {
      return showSnack(context, 'Mật khẩu phải có ít nhất 6 ký tự.', error: true);
    }
    setState(() => _saving = true);
    try {
      final phone = _phone.text.trim();
      await ref.read(managerRepositoryProvider).createAccount(
            email: email,
            password: _pass.text,
            fullName: _name.text.trim(),
            phone: phone.isEmpty ? null : phone,
            role: _role,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      showSnack(context, errorText(e), error: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tạo tài khoản')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Vai trò', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                  value: UserRole.seller,
                  icon: Icon(Icons.point_of_sale),
                  label: Text('Người bán')),
              ButtonSegment(
                  value: UserRole.production,
                  icon: Icon(Icons.precision_manufacturing_outlined),
                  label: Text('Sản xuất')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Họ tên *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email đăng nhập *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Mật khẩu *',
              helperText: 'Ít nhất 6 ký tự. Hãy gửi mật khẩu này cho nhân viên.',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Tạo tài khoản'),
          ),
        ]),
      );
}