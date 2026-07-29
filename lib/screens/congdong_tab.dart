import 'package:flutter/material.dart';
import '../config.dart';
import '../widgets/icon_grid_view.dart';

class CongDongTab extends StatelessWidget {
  const CongDongTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const GridModuleItem(icon: Icons.forum, label: 'Diễn đàn thảo luận', url: AppConfig.urlDienDan),
      const GridModuleItem(icon: Icons.search, label: 'Tìm kiếm', url: AppConfig.urlTimKiem),
      const GridModuleItem(icon: Icons.casino, label: 'Quay số trúng thưởng', url: AppConfig.urlQuaySo),
      const GridModuleItem(icon: Icons.card_giftcard, label: 'Bốc thăm trúng thưởng', url: AppConfig.urlBocTham),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cộng đồng')),
      body: IconGridView(items: items),
    );
  }
}
