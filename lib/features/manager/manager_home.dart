import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'dashboard_page.dart';
import 'orders_page.dart';
import 'products_page.dart';
import 'settings_page.dart';
import 'withdrawals_page.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  // 0 Tổng quan · 1 Đơn hàng · 2 Sản phẩm · 3 Rút tiền · 4 Cài đặt
  int _index = 0;
  int _dashTick = 0; // đổi để Tổng quan tải lại mỗi lần quay về tab
  int _ordersTick = 0; // đổi để Đơn hàng áp bộ lọc mới từ Tổng quan
  PaymentStatus? _ordersPayment;
  DeliveryStatus? _ordersDelivery;

  void _select(int i) {
    setState(() {
      if (i == 0 && _index != 0) _dashTick++;
      _index = i;
    });
  }

  void _openOrders({PaymentStatus? payment, DeliveryStatus? delivery}) {
    setState(() {
      _ordersPayment = payment;
      _ordersDelivery = delivery;
      _ordersTick++;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: [
          DashboardPage(
            key: ValueKey('dash$_dashTick'),
            onOpenOrders: _openOrders,
            onOpenWithdrawals: () => _select(3),
          ),
          OrdersPage(
            key: ValueKey('orders$_ordersTick'),
            initialPayment: _ordersPayment,
            initialDelivery: _ordersDelivery,
          ),
          const ProductsPage(),
          const WithdrawalsPage(),
          const SettingsPage(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Tổng quan'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), label: 'Đơn hàng'),
            NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined), label: 'Sản phẩm'),
            NavigationDestination(
                icon: Icon(Icons.payments_outlined), label: 'Rút tiền'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Cài đặt'),
          ],
        ),
      );
}