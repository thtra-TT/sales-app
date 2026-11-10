// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../core/providers.dart';
// import 'pages/create_order_page.dart';
// import 'pages/orders_tab.dart';
// import 'pages/wallet_tab.dart';
// import 'widgets/notification_bell.dart';

// class SellerHome extends ConsumerStatefulWidget {
//   const SellerHome({super.key});

//   @override
//   ConsumerState<SellerHome> createState() => _SellerHomeState();
// }

// class _SellerHomeState extends ConsumerState<SellerHome> {
//   int _index = 0;
//   static const _titles = ['Đơn hàng của tôi', 'Ví & hạng thành viên'];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(_titles[_index]),
//         actions: [
//           const NotificationBell(),
//           IconButton(
//             tooltip: 'Đăng xuất',
//             icon: const Icon(Icons.logout),
//             onPressed: () => ref.read(supabaseProvider).auth.signOut(),
//           ),
//         ],
//       ),
//       body: _index == 0 ? const OrdersTab() : const WalletTab(),
//       floatingActionButton: _index == 0
//           ? FloatingActionButton.extended(
//               onPressed: () => Navigator.of(context).push(
//                 MaterialPageRoute<void>(
//                   builder: (_) => const CreateOrderPage(),
//                 ),
//               ),
//               icon: const Icon(Icons.add),
//               label: const Text('Tạo đơn'),
//             )
//           : null,
//       bottomNavigationBar: NavigationBar(
//         selectedIndex: _index,
//         onDestinationSelected: (i) => setState(() => _index = i),
//         destinations: const [
//           NavigationDestination(
//             icon: Icon(Icons.receipt_long_outlined),
//             selectedIcon: Icon(Icons.receipt_long),
//             label: 'Đơn hàng',
//           ),
//           NavigationDestination(
//             icon: Icon(Icons.account_balance_wallet_outlined),
//             selectedIcon: Icon(Icons.account_balance_wallet),
//             label: 'Ví & hạng',
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'pages/create_order_page.dart';
import 'pages/order_detail_page.dart';
import 'pages/orders_tab.dart';
import 'pages/wallet_tab.dart';
import 'widgets/notification_bell.dart';
import 'widgets/paged_search_list.dart';

class SellerHome extends ConsumerStatefulWidget {
  const SellerHome({super.key});

  @override
  ConsumerState<SellerHome> createState() => _SellerHomeState();
}

class _SellerHomeState extends ConsumerState<SellerHome> {
  int _index = 0;
  final _ordersCtrl = PagedListController();
  static const _titles = ['Đơn hàng của tôi', 'Ví & hạng thành viên'];

  Future<void> _createOrder() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CreateOrderPage()),
    );
    if (!mounted) return;
    _ordersCtrl.refresh();
    if (id != null) {
      // Tạo xong -> mở thẳng chi tiết đơn để cập nhật thanh toán khi cần
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: id)),
      );
      if (mounted) _ordersCtrl.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
      body: _index == 0
          ? OrdersTab(controller: _ordersCtrl)
          : const WalletTab(),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _createOrder,
              icon: const Icon(Icons.add),
              label: const Text('Tạo đơn'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Ví & hạng',
          ),
        ],
      ),
    );
  }
}