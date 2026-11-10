import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../models/models.dart';
import '../data/seller_providers.dart';
import 'paged_search_list.dart';

/// Bottom sheet chọn khách hàng (tìm theo tên / SĐT, tải từng trang)
/// hoặc thêm khách mới. Trả về Customer.
class CustomerPickerSheet extends ConsumerWidget {
  const CustomerPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = MediaQuery.sizeOf(context).height;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(260.0, math.min(h * 0.75, h - inset - 120));

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Thêm khách hàng mới'),
                  onPressed: () async {
                    final c = await showDialog<Customer>(
                      context: context,
                      builder: (_) => const NewCustomerDialog(),
                    );
                    if (c != null && context.mounted) {
                      Navigator.of(context).pop(c);
                    }
                  },
                ),
              ),
            ),
            Expanded(
              child: PagedSearchList<Customer>(
                hint: 'Tìm theo tên hoặc số điện thoại',
                emptyText: 'Chưa có khách hàng nào',
                fetch: (q, off, lim) => ref
                    .read(sellerRepoProvider)
                    .searchCustomers(query: q, offset: off, limit: lim),
                itemBuilder: (context, c) {
                  final sub = [c.phone, c.contactChannel]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' · ');
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(c.name),
                    subtitle: sub.isEmpty ? null : Text(sub),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewCustomerDialog extends ConsumerStatefulWidget {
  const NewCustomerDialog({super.key});

  @override
  ConsumerState<NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends ConsumerState<NewCustomerDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  String _channel = contactChannels.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên khách hàng');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = await ref.read(sellerRepoProvider).createCustomer(
            name: _name.text.trim(),
            phone: nullIfEmpty(_phone.text),
            contactChannel: _channel,
            address: nullIfEmpty(_address.text),
          );
      if (mounted) Navigator.of(context).pop(c);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khách hàng mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Tên khách hàng *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
            const SizedBox(height: 12),
            const Text('Kênh liên lạc'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final ch in contactChannels)
                  ChoiceChip(
                    label: Text(ch),
                    selected: _channel == ch,
                    onSelected: (_) => setState(() => _channel = ch),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}