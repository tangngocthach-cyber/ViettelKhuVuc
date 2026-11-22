import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'webview_screen.dart';
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
      const GridModuleItem(icon: Icons.sports_esports_outlined, label: 'Game nhận quà', url: AppConfig.urlGame),
    ];

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _DauTrangChu(),
            const TieuDeNhom('Dịch vụ viễn thông'),
            IconGridView(items: dichVuVienThong, cuonRieng: false),
            const TieuDeNhom('Thiết bị & Giải pháp'),
            IconGridView(items: thietBiGiaiPhap, cuonRieng: false),
            const TieuDeNhom('Cộng đồng & Ưu đãi'),
            IconGridView(items: congDong, cuonRieng: false),
            const TieuDeNhom('Thông tin chung'),
            IconGridView(items: thongTinChung, cuonRieng: false),
            const SizedBox(height: 88), // chừa chỗ cho nút nổi "Hỏi đáp", không che ô cuối
          ],
        ),
      ),
    );
  }
}

/// Đầu trang chủ: nền đỏ thương hiệu, logo, lời chào theo buổi + tên người
/// dùng, ô tìm kiếm nhanh - thay cho thanh tiêu đề trơn trước đây.
class _DauTrangChu extends StatefulWidget {
  const _DauTrangChu();

  @override
  State<_DauTrangChu> createState() => _DauTrangChuState();
}

class _DauTrangChuState extends State<_DauTrangChu> {
  String _ten = '';

  @override
  void initState() {
    super.initState();
    _taiTen();
  }

  Future<void> _taiTen() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) setState(() => _ten = (user['name'] ?? '').trim());
    } catch (e) {
      // Không đọc được tên - chỉ hiện lời chào chung
    }
  }

  String _loiChao() {
    final gio = DateTime.now().hour;
    if (gio < 11) return 'Chào buổi sáng';
    if (gio < 14) return 'Chào buổi trưa';
    if (gio < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final dinh = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(18, dinh + 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.viettelRed, AppTheme.viettelRedDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Image(image: AssetImage('assets/images/logo-vinhhung.png')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ten.isEmpty ? _loiChao() : '${_loiChao()},',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  Text(
                    _ten.isEmpty ? 'Viettel Khu Vực Vĩnh Hưng' : _ten,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.2),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebViewScreen(url: AppConfig.urlTimKiem, title: 'Tìm kiếm')),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Icon(Icons.search, color: AppTheme.viettelRed, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Tìm gói cước, sản phẩm, tin tức...', style: TextStyle(color: Colors.black54, fontSize: 14)),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
