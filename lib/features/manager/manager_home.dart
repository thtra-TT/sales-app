import 'package:flutter/material.dart';

import '../shared/role_home_page.dart';

class ManagerHome extends StatelessWidget {
  const ManagerHome({super.key});

  @override
  Widget build(BuildContext context) => const RoleHomePage(
        title: 'Quản lý',
        icon: Icons.admin_panel_settings_outlined,
        upcoming: [
          'Tạo sản phẩm (nhiều item)',
          'Xem đơn hàng + cập nhật giao hàng',
          'Sổ bán hàng',
          'Duyệt yêu cầu rút tiền',
        ],
      );
}