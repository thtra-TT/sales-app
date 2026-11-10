import 'package:flutter/material.dart';

import '../shared/role_home_page.dart';

class SellerHome extends StatelessWidget {
  const SellerHome({super.key});

  @override
  Widget build(BuildContext context) => const RoleHomePage(
        title: 'Người bán',
        icon: Icons.point_of_sale,
        showWallet: true,
        upcoming: [
          'Tạo đơn hàng',
          'Danh sách đơn của tôi + cập nhật thanh toán',
          'Ví và yêu cầu rút tiền',
        ],
      );
}