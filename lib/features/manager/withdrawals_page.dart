import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

/// UC17 / UC18 – Danh sách yêu cầu rút tiền.
class WithdrawalsPage extends ConsumerStatefulWidget {
  const WithdrawalsPage({super.key});

  @override
  ConsumerState<WithdrawalsPage> createState() => _WithdrawalsPageState();
}

class _WithdrawalsPageState extends ConsumerState<WithdrawalsPage> {
  WithdrawStatus? _filter = WithdrawStatus.pending;
  late Future<List<WithdrawalRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<WithdrawalRequest>> _load() =>
      ref.read(managerRepositoryProvider).fetchWithdrawals(status: _filter);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Color _color(WithdrawStatus s) => switch (s) {
        WithdrawStatus.pending => Colors.orange,
        WithdrawStatus.approved => Colors.green,
        WithdrawStatus.rejected => Colors.red,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Yêu cầu rút tiền'),
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _reload,
                icon: const Icon(Icons.refresh)),
            const LogoutButton(),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: _filter == null,
                onSelected: (_) {
                  _filter = null;
                  _reload();
                },
              ),
              for (final s in WithdrawStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _filter == s,
                  onSelected: (_) {
                    _filter = s;
                    _reload();
                  },
                ),
            ]),
          ),
          Expanded(
            child: FutureBody<List<WithdrawalRequest>>(
              future: _future,
              onRetry: _reload,
              builder: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('Không có yêu cầu nào.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final w = list[i];
                      return Card(
                        child: ListTile(
                          onTap: () async {
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                  builder: (_) => WithdrawalDetailPage(request: w)),
                            );
                            if (changed == true) _reload();
                          },
                          title: Row(children: [
                            Expanded(
                                child: Text(w.sellerName ?? 'Người bán (chưa đặt tên)',
                                    style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text(money(w.amount),
                                style: const TextStyle(
                                    color: kPriceColor, fontWeight: FontWeight.w800)),
                          ]),
                          subtitle: Text(fmtDateTime(w.createdAt)),
                          trailing: StatusChip(w.status.label, _color(w.status)),
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

class WithdrawalDetailPage extends ConsumerStatefulWidget {
  final WithdrawalRequest request;
  const WithdrawalDetailPage({super.key, required this.request});

  @override
  ConsumerState<WithdrawalDetailPage> createState() =>
      _WithdrawalDetailPageState();
}

class _WithdrawalDetailPageState extends ConsumerState<WithdrawalDetailPage> {
  late Future<double> _balance;
  Future<String>? _existingProof;
  Uint8List? _proofBytes;
  String? _proofName;
  bool _busy = false;

  WithdrawalRequest get _r => widget.request;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(managerRepositoryProvider);
    _balance = repo.fetchWalletBalance(_r.sellerId);
    if (_r.proofUrl != null) {
      _existingProof = repo.signedProofUrl(_r.proofUrl!);
    }
  }

  Future<void> _pickProof() async {
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _proofBytes = bytes;
        _proofName = x.name;
      });
    } catch (e) {
      showSnack(context, 'Không chọn được ảnh: ${errorText(e)}', error: true);
    }
  }

  Future<void> _approve() async {
    // 5a
    if (_proofBytes == null) {
      return showSnack(context, 'Hãy tải ảnh minh chứng chuyển khoản trước khi duyệt.',
          error: true);
    }
    final ok = await _confirm('Duyệt yêu cầu',
        'Xác nhận đã chuyển ${money(_r.amount)} cho ${_r.sellerName ?? 'người bán'}?');
    if (ok != true) return;

    final repo = ref.read(managerRepositoryProvider);
    setState(() => _busy = true);
    try {
      final path = await repo.uploadWithdrawProof(
        requestId: _r.id,
        bytes: _proofBytes!,
        fileName: _proofName ?? 'proof.jpg',
      );
      await repo.approveWithdrawal(_r.id, path);
      if (!mounted) return;
      showSnack(context, 'Đã duyệt yêu cầu rút tiền.');
      Navigator.of(context).pop(true);
    } catch (e) {
      // 6a / 6b: số dư không đủ, đã xử lý bởi người khác... (message từ trigger)
      showSnack(context, errorText(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(managerRepositoryProvider).rejectWithdrawal(_r.id, reason);
      if (!mounted) return;
      showSnack(context, 'Đã từ chối yêu cầu.');
      Navigator.of(context).pop(true);
    } catch (e) {
      showSnack(context, errorText(e), error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(String title, String msg) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ')),
            FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xác nhận')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu rút tiền')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_r.sellerName ?? 'Người bán (chưa đặt tên)'),
              subtitle: Text('Yêu cầu lúc ${fmtDateTime(_r.createdAt)}'),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Số tiền yêu cầu'),
              trailing: Text(money(_r.amount),
                  style: theme.textTheme.titleMedium),
            ),
            FutureBuilder<double>(
              future: _balance,
              builder: (_, s) => ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Số dư hiện tại'),
                trailing: Text(s.hasData
                    ? money(s.data!)
                    : s.hasError
                        ? 'Lỗi tải'
                        : '...'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Trạng thái'),
              trailing: Text(_r.status.label),
            ),
            if (_r.processedAt != null)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Xử lý lúc'),
                trailing: Text(fmtDateTime(_r.processedAt)),
              ),
            if (_r.note != null && _r.note!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.notes),
                title: const Text('Ghi chú / lý do'),
                subtitle: Text(_r.note!),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_r.isPending) ..._pendingActions(theme) else ..._processedProof(),
      ]),
    );
  }

  List<Widget> _pendingActions(ThemeData theme) => [
        Text(
          'Chuyển khoản thủ công cho người bán bên ngoài hệ thống, '
          'sau đó tải ảnh minh chứng lên rồi bấm Duyệt.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickProof,
          icon: const Icon(Icons.upload_file),
          label: Text(_proofBytes == null
              ? 'Chọn ảnh minh chứng'
              : 'Đổi ảnh minh chứng'),
        ),
        if (_proofBytes != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_proofBytes!, height: 240, fit: BoxFit.contain),
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _approve,
          icon: const Icon(Icons.check),
          label: const Text('Duyệt'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: theme.colorScheme.error),
          onPressed: _busy ? null : _reject,
          icon: const Icon(Icons.close),
          label: const Text('Từ chối'),
        ),
      ];

  List<Widget> _processedProof() {
    if (_existingProof == null) return const [];
    return [
      const Text('Ảnh minh chứng'),
      const SizedBox(height: 8),
      FutureBuilder<String>(
        future: _existingProof,
        builder: (_, s) {
          if (s.hasError) return Text(errorText(s.error!));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(s.data!, fit: BoxFit.contain),
          );
        },
      ),
    ];
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Từ chối yêu cầu'),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Lý do *', errorText: _err),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {
              final t = _c.text.trim();
              if (t.isEmpty) {
                setState(() => _err = 'Vui lòng nhập lý do');
                return;
              }
              Navigator.pop(context, t);
            },
            child: const Text('Từ chối'),
          ),
        ],
      );
}