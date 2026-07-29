import 'package:flutter/material.dart';
import '../config.dart';
import '../widgets/icon_grid_view.dart';

/// QUAN TRỌNG: category id dưới đây lấy ĐÚNG từ bảng `categories` thật trên
/// website (database.sql) - KHÔNG đoán slug, để mở đúng trang lọc sản phẩm.
class TrangChuTab extends StatelessWidget {
  const TrangChuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const GridModuleItem(icon: Icons.wifi, label: 'Internet Cáp Quang FTTH', url: '${AppConfig.baseUrl}/san-pham.php?cat=1'),
      const GridModuleItem(icon: Icons.router, label: 'Combo Internet-TH-Camera', url: '${AppConfig.baseUrl}/san-pham.php?cat=2'),
      const GridModuleItem(icon: Icons.sim_card, label: 'Di động trả trước', url: '${AppConfig.baseUrl}/san-pham.php?cat=3'),
      const GridModuleItem(icon: Icons.smartphone, label: 'Di động trả sau', url: '${AppConfig.baseUrl}/san-pham.php?cat=4'),
      const GridModuleItem(icon: Icons.signal_cellular_alt, label: 'Dịch vụ 5G', url: '${AppConfig.baseUrl}/san-pham.php?cat=5'),
      const GridModuleItem(icon: Icons.videocam, label: 'Camera an ninh', url: '${AppConfig.baseUrl}/san-pham.php?cat=6'),
      const GridModuleItem(icon: Icons.devices_other, label: 'Thiết bị đầu cuối', url: '${AppConfig.baseUrl}/san-pham.php?cat=7'),
      const GridModuleItem(icon: Icons.business_center, label: 'Giải pháp Doanh nghiệp', url: '${AppConfig.baseUrl}/san-pham.php?cat=8'),
      const GridModuleItem(icon: Icons.confirmation_number, label: 'Số thuê bao đẹp', url: AppConfig.urlSoDep),
      const GridModuleItem(icon: Icons.newspaper, label: 'Tin tức', url: AppConfig.urlTinTuc),
      const GridModuleItem(icon: Icons.policy, label: 'Chính sách', url: AppConfig.urlChinhSach),
      const GridModuleItem(icon: Icons.call, label: 'Liên hệ', url: AppConfig.urlLienHe),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Viettel Khu Vực Vĩnh Hưng')),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: IconGridView(items: items),
      ),
    );
  }
}
