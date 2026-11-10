import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../data/seller_providers.dart';
import '../widgets/common.dart';
import '../widgets/proof_image.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notis = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: notis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: errorText(e),
          onRetry: () => ref.invalidate(myNotificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Chưa có thông báo nào'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myNotificationsProvider);
              try {
                await ref.read(myNotificationsProvider.future);
              } catch (_) {}
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = list[i];
                return ListTile(
                  leading: Icon(
                    n.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${n.body ?? ''}\n${formatDateTime(n.createdAt)}',
                  ),
                  isThreeLine: true,
                  trailing: n.proofUrl != null
                      ? const Icon(Icons.image_outlined)
                      : null,
                  onTap: () async {
                    if (!n.isRead) {
                      try {
                        await ref
                            .read(sellerRepoProvider)
                            .markNotificationRead(n.id);
                        ref.invalidate(myNotificationsProvider);
                      } catch (_) {}
                    }
                    if (n.proofUrl != null && context.mounted) {
                      showProofDialog(
                        context,
                        bucket: 'withdraw-proofs',
                        path: n.proofUrl!,
                      );
                    }
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}