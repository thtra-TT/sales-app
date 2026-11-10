import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import 'manager_common.dart';
import 'manager_repository.dart';

/// UC19 – Cấu hình hạng thành viên.
class RanksPage extends ConsumerStatefulWidget {
  const RanksPage({super.key});

  @override
  ConsumerState<RanksPage> createState() => _RanksPageState();
}

class _RankInput {
  final String name;
  final double minSpent, discount, commission;
  const _RankInput(this.name, this.minSpent, this.discount, this.commission);
}

class _RanksPageState extends ConsumerState<RanksPage> {
  late Future<List<MemberRank>> _future;
  List<MemberRank> _current = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MemberRank>> _load() async {
    final r = await ref.read(managerRepositoryProvider).fetchRanks();
    _current = r;
    return r;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _edit([MemberRank? rank]) async {
    final input = await showDialog<_RankInput>(
      context: context,
      builder: (_) => _RankDialog(editing: rank, all: _current),
    );
    if (input == null) return;
    try {
      await ref.read(managerRepositoryProvider).saveRank(
            id: rank?.id,
            name: input.name,
            minSpent: input.minSpent,
            discountPercent: input.discount,
            commissionPercent: input.commission,
          );
      if (mounted) showSnack(context, 'Đã lưu hạng "${input.name}".');
      _reload();
    } catch (e) {
      showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Hạng thành viên'),
          actions: [
            IconButton(
                tooltip: 'Tải lại',
                onPressed: _reload,
                icon: const Icon(Icons.refresh)),
            const LogoutButton(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm hạng'),
        ),
        body: FutureBody<List<MemberRank>>(
          future: _future,
          onRetry: _reload,
          builder: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              for (final r in list)
                Card(
                  child: ListTile(
                    onTap: () => _edit(r),
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(r.name),
                    subtitle: Text('Từ ${money(r.minSpent)}\n'
                        'Giảm giá ${r.discountPercent}% · Hoa hồng ${r.commissionPercent}%'),
                    isThreeLine: true,
                    trailing: r.minSpent == 0
                        ? const StatusChip('Mặc định', Colors.blue)
                        : const Icon(Icons.edit_outlined),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Thay đổi chỉ ảnh hưởng các đơn tạo sau đó.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
}

class _RankDialog extends StatefulWidget {
  final MemberRank? editing;
  final List<MemberRank> all;
  const _RankDialog({required this.editing, required this.all});

  @override
  State<_RankDialog> createState() => _RankDialogState();
}

class _RankDialogState extends State<_RankDialog> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _min = TextEditingController(
      text: widget.editing?.minSpent.toStringAsFixed(0) ?? '');
  late final _disc = TextEditingController(
      text: widget.editing?.discountPercent.toString() ?? '0');
  late final _comm = TextEditingController(
      text: widget.editing?.commissionPercent.toString() ?? '0');
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _disc.dispose();
    _comm.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final min = parseMoney(_min.text);
    final disc = parseMoney(_disc.text);
    final comm = parseMoney(_comm.text);

    String? err;
    if (name.isEmpty) {
      err = 'Tên hạng không được để trống.';
    } else if (min == null || min < 0) {
      err = 'Ngưỡng chi tiêu phải là số lớn hơn hoặc bằng 0.';
    } else if (disc == null || disc < 0 || disc > 100) {
      err = 'Discount phải từ 0 đến 100.';
    } else if (comm == null || comm < 0 || comm > 100) {
      err = 'Hoa hồng phải từ 0 đến 100.';
    } else {
      final others =
          widget.all.where((r) => r.id != widget.editing?.id).toList();
      if (others.any((r) => r.minSpent == min)) {
        err = 'Ngưỡng bị trùng với hạng khác.'; // 3a
      } else if (!others.any((r) => r.minSpent == 0) && min != 0) {
        err = 'Phải có một hạng mặc định với ngưỡng bằng 0.';
      }
    }
    if (err != null) {
      setState(() => _err = err);
      return;
    }
    Navigator.pop(context, _RankInput(name, min!, disc!, comm!));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.editing == null ? 'Thêm hạng' : 'Sửa hạng'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên hạng *')),
            const SizedBox(height: 12),
            TextField(
              controller: _min,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Ngưỡng chi tiêu tối thiểu (đ) *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _disc,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Giảm giá (%) *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comm,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Hoa hồng (%) *'),
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_err!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _submit,
              child: const Text('Lưu')),
        ],
      );
}