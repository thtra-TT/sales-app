import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../data/seller_providers.dart';
import '../widgets/common.dart';
import '../widgets/proof_image.dart';
import '../widgets/status_chip.dart';
import '../widgets/withdraw_dialog.dart';

class WalletTab extends ConsumerWidget {
  const WalletTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(profileProvider);
    ref.invalidate(myWithdrawalsProvider);
    ref.invalidate(myWalletTxProvider);
    try {
      await ref.read(profileProvider.future);
    } catch (_) {}
  }

  Future<void> _openWithdraw(
    BuildContext context,
    double available,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => WithdrawDialog(available: available),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu rút tiền, chờ quản lý duyệt')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(profileProvider).value;
    final ranks = ref.watch(ranksProvider).value ?? const <MemberRank>[];
    final withdrawals = ref.watch(myWithdrawalsProvider);
    final txs = ref.watch(myWalletTxProvider);

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pending = (withdrawals.value ?? const <WithdrawalRequest>[])
        .where((w) => w.isPending)
        .fold<double>(0, (s, w) => s + w.amount);
    final available = profile.walletBalance - pending;

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- Số dư ví ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Số dư ví (hoa hồng)'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(profile.walletBalance),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đang chờ duyệt rút: ${formatMoney(pending)} · '
                    'Khả dụng: ${formatMoney(available)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: available > 0
                          ? () => _openWithdraw(context, available)
                          : null,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Yêu cầu rút tiền'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ví chỉ được cộng khi đơn chuyển sang "Đã thanh toán".',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // ---------- Hạng thành viên ----------
          const SectionTitle('Hạng thành viên'),
          _RankCard(profile: profile, ranks: ranks),

          // ---------- Yêu cầu rút tiền ----------
          const SectionTitle('Yêu cầu rút tiền'),
          withdrawals.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: errorText(e),
              onRetry: () => ref.invalidate(myWithdrawalsProvider),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Chưa có yêu cầu nào'),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final w in list.take(20))
                          ListTile(
                            title: Text(formatMoney(w.amount)),
                            subtitle: Text(
                              formatDateTime(w.createdAt) +
                                  (w.note == null || w.note!.isEmpty
                                      ? ''
                                      : '\n${w.note}'),
                            ),
                            isThreeLine: w.note != null && w.note!.isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                withdrawChip(w.status),
                                if (w.status == WithdrawStatus.approved &&
                                    w.proofUrl != null)
                                  IconButton(
                                    tooltip: 'Xem minh chứng chuyển khoản',
                                    icon: const Icon(Icons.receipt_long),
                                    onPressed: () => showProofDialog(
                                      context,
                                      bucket: 'withdraw-proofs',
                                      path: w.proofUrl!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),

          // ---------- Lịch sử ví ----------
          const SectionTitle('Lịch sử ví'),
          txs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(
              message: errorText(e),
              onRetry: () => ref.invalidate(myWalletTxProvider),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Chưa có giao dịch nào'),
                  )
                : Card(
                    child: Column(
                      children: [
                        for (final t in list)
                          ListTile(
                            leading: Icon(
                              t.amount >= 0
                                  ? Icons.arrow_circle_down
                                  : Icons.arrow_circle_up,
                              color: t.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                            title: Text(t.type.label),
                            subtitle: Text(formatDateTime(t.createdAt)),
                            trailing: Text(
                              '${t.amount >= 0 ? '+' : ''}${formatMoney(t.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: t.amount >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.profile, required this.ranks});
  final UserProfile profile;
  final List<MemberRank> ranks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...ranks]..sort((a, b) => a.minSpent.compareTo(b.minSpent));
    final next =
        sorted.where((r) => r.minSpent > profile.totalSpent).firstOrNull;
    final cur = sorted.where((r) => r.name == profile.rankName).firstOrNull;
    final curMin = cur?.minSpent ?? 0;

    double progress = 1;
    if (next != null && next.minSpent > curMin) {
      progress = ((profile.totalSpent - curMin) / (next.minSpent - curMin))
          .clamp(0.0, 1.0)
          .toDouble();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Hạng ${profile.rankName ?? '-'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Giảm giá ${formatPercent(profile.discountPercent)}% cho khách · '
              'Hoa hồng ${formatPercent(profile.commissionPercent)}%',
            ),
            const SizedBox(height: 4),
            Text(
              'Tổng chi tiêu (đơn đã thanh toán): ${formatMoney(profile.totalSpent)}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Text(
              next == null
                  ? 'Bạn đang ở hạng cao nhất.'
                  : 'Còn ${formatMoney(next.minSpent - profile.totalSpent)} để lên hạng '
                      '${next.name} (giảm ${formatPercent(next.discountPercent)}%, '
                      'hoa hồng ${formatPercent(next.commissionPercent)}%).',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}