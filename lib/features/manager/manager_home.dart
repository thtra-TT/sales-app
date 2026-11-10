import 'package:flutter/material.dart';

import 'ledger_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'ranks_page.dart';
import 'withdrawals_page.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  int _index = 0;

  static const _pages = <Widget>[
    ProductsPage(),
    OrdersPage(),
    LedgerPage(),
    WithdrawalsPage(),
    RanksPage(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined), label: 'Sản phẩm'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), label: 'Đơn hàng'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined), label: 'Sổ bán'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined), label: 'Rút tiền'),
            NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined), label: 'Hạng'),
          ],
        ),
      );
}