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
      const GridModuleItem(icon: Icons.wifi, label: 'Internet Cáp Quang FTTH', url: '${AppConfig.baseUrl}/san-pham.php?cat=1'),
      const GridModuleItem(icon: Icons.router, label: 'Combo Internet-TH-Camera', url: '${AppConfig.baseUrl}/san-pham.php?cat=2'),
      const GridModuleItem(icon: Icons.sim_card, label: 'Di động trả trước', url: '${AppConfig.baseUrl}/san-pham.php?cat=3'),
      const GridModuleItem(icon: Icons.smartphone, label: 'Di động trả sau', url: '${AppConfig.baseUrl}/san-pham.php?cat=4'),
      const GridModuleItem(icon: Icons.signal_cellular_alt, label: 'Dịch vụ 5G', url: '${AppConfig.baseUrl}/san-pham.php?cat=5'),
      const GridModuleItem(icon: Icons.confirmation_number, label: 'Số thuê bao đẹp', url: AppConfig.urlSoDep),
    ];
    final thietBiGiaiPhap = [
      const GridModuleItem(icon: Icons.videocam, label: 'Camera an ninh', url: '${AppConfig.baseUrl}/san-pham.php?cat=6'),
      const GridModuleItem(icon: Icons.devices_other, label: 'Thiết bị đầu cuối', url: '${AppConfig.baseUrl}/san-pham.php?cat=7'),
      const GridModuleItem(icon: Icons.business_center, label: 'Giải pháp Doanh nghiệp', url: '${AppConfig.baseUrl}/san-pham.php?cat=8'),
    ];
    final thongTinChung = [
      const GridModuleItem(icon: Icons.newspaper, label: 'Tin tức', url: AppConfig.urlTinTuc),
      const GridModuleItem(icon: Icons.policy, label: 'Chính sách', url: AppConfig.urlChinhSach),
      const GridModuleItem(icon: Icons.call, label: 'Liên hệ', url: AppConfig.urlLienHe),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 168,
            backgroundColor: AppTheme.viettelRed,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
              title: const Text('Viettel Khu Vực Vĩnh Hưng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.viettelRedDark, AppTheme.viettelRed],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -30, top: -20, child: _vongTronMo(120)),
                    Positioned(right: 60, bottom: -40, child: _vongTronMo(90)),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 56, 16, 0),
                      child: Text(
                        'Xin chào 👋\nGiải pháp viễn thông cho gia đình & doanh nghiệp',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _tieuDeNhom('Dịch vụ viễn thông'),
              IconGridView(items: dichVuVienThong, cuonRieng: false),
              _tieuDeNhom('Thiết bị & Giải pháp'),
              IconGridView(items: thietBiGiaiPhap, cuonRieng: false),
              _tieuDeNhom('Thông tin chung'),
              IconGridView(items: thongTinChung, cuonRieng: false),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _vongTronMo(double duongKinh) {
    return Container(
      width: duongKinh,
      height: duongKinh,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .07)),
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
