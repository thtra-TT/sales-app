import 'package:flutter/material.dart';

import '../shared/role_home_page.dart';

class ProductionHome extends StatelessWidget {
  const ProductionHome({super.key});

  @override
  Widget build(BuildContext context) => const RoleHomePage(
        title: 'Sản xuất kỹ thuật',
        icon: Icons.precision_manufacturing_outlined,
        upcoming: [
          'Danh sách sản phẩm cần làm (từ đơn đã thanh toán)',
          'Cập nhật + lọc trạng thái sản xuất',
        ],
      );
}