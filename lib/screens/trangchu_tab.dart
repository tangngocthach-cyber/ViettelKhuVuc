import 'package:flutter/material.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets/icon_grid_view.dart';

/// QUAN TRỌNG: category id dưới đây lấy ĐÚNG từ bảng `categories` thật trên
/// website (database.sql) - KHÔNG đoán slug, để mở đúng trang lọc sản phẩm.
class TrangChuTab extends StatelessWidget {
  const TrangChuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dichVuVienThong = [
      const GridModuleItem(icon: Icons.wifi_outlined, label: 'Internet Cáp Quang FTTH', url: '${AppConfig.baseUrl}/san-pham.php?cat=1'),
      const GridModuleItem(icon: Icons.router_outlined, label: 'Combo Internet-TH-Camera', url: '${AppConfig.baseUrl}/san-pham.php?cat=2'),
      const GridModuleItem(icon: Icons.sim_card_outlined, label: 'Di động trả trước', url: '${AppConfig.baseUrl}/san-pham.php?cat=3'),
      const GridModuleItem(icon: Icons.smartphone_outlined, label: 'Di động trả sau', url: '${AppConfig.baseUrl}/san-pham.php?cat=4'),
      const GridModuleItem(icon: Icons.network_cell_outlined, label: 'Dịch vụ 5G', url: '${AppConfig.baseUrl}/san-pham.php?cat=5'),
      const GridModuleItem(icon: Icons.confirmation_number_outlined, label: 'Số thuê bao đẹp', url: AppConfig.urlSoDep),
    ];
    final thietBiGiaiPhap = [
      const GridModuleItem(icon: Icons.videocam_outlined, label: 'Camera an ninh', url: '${AppConfig.baseUrl}/san-pham.php?cat=6'),
      const GridModuleItem(icon: Icons.devices_outlined, label: 'Thiết bị đầu cuối', url: '${AppConfig.baseUrl}/san-pham.php?cat=7'),
      const GridModuleItem(icon: Icons.business_center_outlined, label: 'Giải pháp Doanh nghiệp', url: '${AppConfig.baseUrl}/san-pham.php?cat=8'),
    ];
    final thongTinChung = [
      const GridModuleItem(icon: Icons.article_outlined, label: 'Tin tức', url: AppConfig.urlTinTuc),
      const GridModuleItem(icon: Icons.policy_outlined, label: 'Chính sách', url: AppConfig.urlChinhSach),
      const GridModuleItem(icon: Icons.phone_outlined, label: 'Liên hệ', url: AppConfig.urlLienHe),
    ];
    final congDong = [
      const GridModuleItem(icon: Icons.forum_outlined, label: 'Diễn đàn thảo luận', url: AppConfig.urlDienDan),
      const GridModuleItem(icon: Icons.search, label: 'Tìm kiếm', url: AppConfig.urlTimKiem),
      const GridModuleItem(icon: Icons.casino_outlined, label: 'Quay số trúng thưởng', url: AppConfig.urlQuaySo),
      const GridModuleItem(icon: Icons.card_giftcard_outlined, label: 'Bốc thăm trúng thưởng', url: AppConfig.urlBocTham),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Viettel Khu Vực Vĩnh Hưng')),
      body: ListView(
        children: [
          _tieuDeNhom('Dịch vụ viễn thông'),
          IconGridView(items: dichVuVienThong, cuonRieng: false),
          _tieuDeNhom('Thiết bị & Giải pháp'),
          IconGridView(items: thietBiGiaiPhap, cuonRieng: false),
          _tieuDeNhom('Cộng đồng & Ưu đãi'),
          IconGridView(items: congDong, cuonRieng: false),
          _tieuDeNhom('Thông tin chung'),
          IconGridView(items: thongTinChung, cuonRieng: false),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tieuDeNhom(String ten) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppTheme.viettelRed, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(ten, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.black87, letterSpacing: -.2)),
      ]),
    );
  }
}
