import 'package:flutter/material.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../widgets/icon_grid_view.dart';

/// Tab Cộng đồng - ĐẦY ĐỦ công cụ nội bộ như menu thật trên website (không chỉ
/// 4 mục Diễn đàn/Tìm kiếm/Quay số/Bốc thăm như bản đầu). Quyền xem từng trang
/// do chính PHP kiểm tra như trên web (dùng chung phiên đăng nhập thật qua
/// app-session-login.php) - ai chưa được cấp quyền module nào thì trang đó sẽ
/// tự báo như trên web, không cần app tự giới hạn thêm.
///
/// RIÊNG danh mục "Hạ tầng mạng" (Bản đồ Hộp cáp GPON) là NGOẠI LỆ - đây là dữ
/// liệu vị trí hạ tầng, cần ẨN HẲN danh mục (không chỉ chặn sau khi bấm vào)
/// cho tới khi được Admin cấp quyền riêng (hop_cap_gpon_access) - nên cần
/// StatefulWidget để tự kiểm tra quyền qua AuthService trước khi vẽ danh mục.
class CongDongTab extends StatefulWidget {
  const CongDongTab({super.key});

  @override
  State<CongDongTab> createState() => _CongDongTabState();
}

class _CongDongTabState extends State<CongDongTab> {
  bool _coQuyenHopCap = false; // Mặc định ẨN - an toàn hơn là lỡ hiện nhầm

  @override
  void initState() {
    super.initState();
    _kiemTraQuyen();
  }

  Future<void> _kiemTraQuyen() async {
    final coQuyen = await AuthService.hasHopCapAccess();
    if (mounted) setState(() => _coQuyenHopCap = coQuyen);
  }

  @override
  Widget build(BuildContext context) {
    final congViec = [
      const GridModuleItem(icon: Icons.dashboard, label: 'Dashboard KPI', url: AppConfig.urlDashboardKPI),
      const GridModuleItem(icon: Icons.assignment_turned_in, label: 'Nhập kết quả giao việc', url: AppConfig.urlNhapKetQua),
      const GridModuleItem(icon: Icons.fact_check, label: 'Giao việc - Xem tổng hợp', url: AppConfig.urlGiaoViecTongHop),
      const GridModuleItem(icon: Icons.receipt_long, label: 'Kết quả Thu cước', url: AppConfig.urlThuCuocDashboard),
      const GridModuleItem(icon: Icons.link, label: 'Tiện ích nội bộ', url: AppConfig.urlTienIchNoiBo),
      const GridModuleItem(icon: Icons.table_chart, label: 'Kho Dữ liệu bán hàng', url: AppConfig.urlKhoDuLieuExcel),
      const GridModuleItem(icon: Icons.smart_toy, label: 'Trợ lý KPI (AI)', url: AppConfig.urlTroLyKPI),
    ];
    final haTangMang = [
      const GridModuleItem(icon: Icons.map, label: 'Bản đồ Hộp cáp GPON', url: AppConfig.urlBanDoHopCap),
    ];
    final hocTap = [
      const GridModuleItem(icon: Icons.school, label: 'E-Learning', url: AppConfig.urlKhoaHoc),
      const GridModuleItem(icon: Icons.history, label: 'Lịch sử học tập', url: AppConfig.urlLichSuHocTap),
      const GridModuleItem(icon: Icons.workspace_premium, label: 'Chứng chỉ của tôi', url: AppConfig.urlChungChiCuaToi),
      const GridModuleItem(icon: Icons.folder_shared, label: 'Thư viện tài liệu', url: AppConfig.urlThuVienTaiLieu),
    ];
    final congDong = [
      const GridModuleItem(icon: Icons.forum, label: 'Diễn đàn thảo luận', url: AppConfig.urlDienDan),
      const GridModuleItem(icon: Icons.search, label: 'Tìm kiếm', url: AppConfig.urlTimKiem),
      const GridModuleItem(icon: Icons.casino, label: 'Quay số trúng thưởng', url: AppConfig.urlQuaySo),
      const GridModuleItem(icon: Icons.card_giftcard, label: 'Bốc thăm trúng thưởng', url: AppConfig.urlBocTham),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cộng đồng')),
      body: ListView(
        children: [
          _tieuDeNhom('Công việc & KPI'),
          IconGridView(items: congViec, cuonRieng: false),
          // Danh mục CHỈ hiện khi được cấp quyền riêng - ẩn hẳn (không chỉ mờ
          // đi hay chặn sau khi bấm) nếu chưa được Admin cấp quyền.
          if (_coQuyenHopCap) ...[
            _tieuDeNhom('Hạ tầng mạng'),
            IconGridView(items: haTangMang, cuonRieng: false),
          ],
          _tieuDeNhom('Học tập & Tài liệu'),
          IconGridView(items: hocTap, cuonRieng: false),
          _tieuDeNhom('Cộng đồng & Ưu đãi'),
          IconGridView(items: congDong, cuonRieng: false),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tieuDeNhom(String ten) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Text(ten, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
    );
  }
}
