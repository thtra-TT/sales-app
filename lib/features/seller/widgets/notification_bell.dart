import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seller_providers.dart';
import '../pages/notifications_page.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref
            .watch(myNotificationsProvider)
            .value
            ?.where((n) => !n.isRead)
            .length ??
        0;

    return IconButton(
      tooltip: 'Thông báo',
      icon: Badge(
        label: Text('$unread'),
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
        );
        ref.invalidate(myNotificationsProvider);
      },
    );
  }
}