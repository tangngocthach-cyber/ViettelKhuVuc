import 'package:flutter/material.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../widgets/icon_grid_view.dart';
import 'calculator_screen.dart';
import 'ghi_chu_screen.dart';
import 'so_ghi_chu_screen.dart';
import 'lich_screen.dart';
import 'qr_scan_screen.dart';
import 'cham_tu_danh_sach_screen.dart';
import 'bill_cuoc_native_screen.dart';
import 'toa_do_khach_hang_screen.dart';
import 'dong_ho_bam_gio_screen.dart';
import 'den_pin_screen.dart';
import 'la_ban_screen.dart';
import 'thuoc_do_screen.dart';
import 'speedtest_screen.dart';

/// Tab Cộng đồng - ĐẦY ĐỦ công cụ nội bộ như menu thật trên website (không chỉ
/// 4 mục Diễn đàn/Tìm kiếm/Quay số/Bốc thăm như bản đầu). Quyền xem từng trang
/// do chính PHP kiểm tra như trên web (dùng chung phiên đăng nhập thật qua
/// app-session-login.php) - ai chưa được cấp quyền module nào thì trang đó sẽ
/// tự báo như trên web, không cần app tự giới hạn thêm.
///
/// RIÊNG danh mục "Hạ tầng mạng" (Bản đồ Hộp cáp GPON, Chấm tủ đề xuất) là
/// NGOẠI LỆ - đây là dữ liệu vị trí hạ tầng, cần ẨN HẲN icon (không chỉ chặn
/// sau khi bấm vào) cho tới khi được Admin cấp quyền riêng
/// (hop_cap_gpon_access / cham_tu_access) - nên cần StatefulWidget để tự
/// kiểm tra quyền qua AuthService trước khi vẽ icon.
///
/// "Bản đồ số khách hàng" và "Thu thập tọa độ" KHÔNG cần app tự kiểm tra
/// quyền riêng - trang web/API phía sau (require_ban_do_khach_hang_access())
/// đã tự chặn đúng người chưa được cấp quyền rồi, giống cách các mục khác
/// trong app (Dashboard KPI, Bill cước...) đều để web/API tự lo, KHÔNG kiểm
/// tra quyền phía app - luôn hiện icon, bấm vào mới biết có được vào hay
/// không (đúng khuôn mẫu đa số các mục khác trong toàn app, chỉ 2 mục Hộp
/// cáp GPON/Chấm tủ là NGOẠI LỆ ẩn hẳn theo yêu cầu riêng).
class CongDongTab extends StatefulWidget {
  const CongDongTab({super.key});

  @override
  State<CongDongTab> createState() => _CongDongTabState();
}

class _CongDongTabState extends State<CongDongTab> {
  bool _coQuyenHopCap = false; // Mặc định ẨN - an toàn hơn là lỡ hiện nhầm
  bool _coQuyenChamTu = false; // Mặc định ẨN - phải được Admin cấp riêng mới chấm tủ được

  @override
  void initState() {
    super.initState();
    _kiemTraQuyen();
  }

  Future<void> _kiemTraQuyen() async {
    final coHopCap = await AuthService.hasHopCapAccess();
    // Có quyền dùng CƠ BẢN hoặc là Admin của module đều được thấy mục này -
    // Admin không cần được cấp thêm quyền dùng riêng (đã có quyền cao hơn).
    final coChamTu = await AuthService.hasChamTuAccess() || await AuthService.isChamTuAdmin();
    if (mounted) {
      setState(() {
        _coQuyenHopCap = coHopCap;
        _coQuyenChamTu = coChamTu;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final congViec = [
      const GridModuleItem(icon: Icons.dashboard, label: 'Dashboard KPI', url: AppConfig.urlDashboardKPI),
      const GridModuleItem(icon: Icons.assignment_turned_in, label: 'Nhập kết quả giao việc', url: AppConfig.urlNhapKetQua),
      const GridModuleItem(icon: Icons.fact_check, label: 'Giao việc - Xem tổng hợp', url: AppConfig.urlGiaoViecTongHop),
      const GridModuleItem(icon: Icons.receipt_long, label: 'Kết quả Thu cước', url: AppConfig.urlThuCuocDashboard),
      GridModuleItem(
        icon: Icons.receipt,
        label: 'Bill cước & Thông báo nợ',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillCuocNativeScreen())),
      ),
      const GridModuleItem(icon: Icons.link, label: 'Tiện ích nội bộ', url: AppConfig.urlTienIchNoiBo),
      const GridModuleItem(icon: Icons.table_chart, label: 'Kho Dữ liệu bán hàng', url: AppConfig.urlKhoDuLieuExcel),
      const GridModuleItem(icon: Icons.smart_toy, label: 'Trợ lý KPI (AI)', url: AppConfig.urlTroLyKPI),
      // Trước đây gọi là "Sổ ghi chú" (nằm ở mục Tiện ích) - đổi tên và
      // chuyển sang đây theo yêu cầu, TÍNH NĂNG GIỮ NGUYÊN (vẫn đúng
      // GhiChuScreen cũ - có nhắc hẹn/loại/mức ưu tiên, phù hợp làm việc
      // hơn là 1 sổ ghi chú đơn thuần).
      GridModuleItem(
        icon: Icons.people_alt,
        label: 'Quản lý dữ liệu khách hàng',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GhiChuScreen())),
      ),
    ];

    // ĐẶT TÊN RIÊNG TỪNG ITEM (không gom vào 1 mảng rồi lấy theo index nữa)
    // - ĐÂY LÀ CHỖ ĐÃ GÂY LỖI TRƯỚC ĐÓ: code cũ lấy theo haTangMang[0]/[1]
    // cố định vị trí, nên khi thêm mục mới vào GIỮA mảng, mọi thứ bị lệch
    // hết vị trí. Đặt tên riêng từng cái để không bao giờ lặp lại lỗi này
    // nữa dù có thêm/bớt mục sau này.
    final banDoHopCap = const GridModuleItem(icon: Icons.map, label: 'Bản đồ Hộp cáp GPON', url: AppConfig.urlBanDoHopCap);
    final banDoKhachHang = const GridModuleItem(icon: Icons.location_on, label: 'Bản đồ số khách hàng', url: AppConfig.urlBanDoKhachHang);
    final thuThapToaDo = GridModuleItem(
      icon: Icons.gps_fixed,
      label: 'Thu thập tọa độ',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ToaDoKhachHangScreen())),
    );
    final chamTuDeXuat = GridModuleItem(
      icon: Icons.add_location_alt,
      label: 'Chấm tủ đề xuất',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChamTuDanhSachScreen())),
    );

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
    final tienIch = [
      GridModuleItem(
        icon: Icons.qr_code_scanner,
        label: 'Quét mã QR',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScanScreen())),
      ),
      GridModuleItem(
        icon: Icons.calculate,
        label: 'Máy tính',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorScreen())),
      ),
      GridModuleItem(
        icon: Icons.note_alt,
        label: 'Sổ ghi chú',
        // Đổi sang màn Sổ ghi chú KIỂU MỚI (như iOS Notes - chữ + viết tay +
        // ghi âm), thay cho GhiChuScreen cũ (đã chuyển sang mục "Công việc &
        // KPI" với tên "Quản lý dữ liệu khách hàng"). Dữ liệu 2 bên tách
        // biệt hoàn toàn, không lẫn vào nhau.
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoGhiChuScreen())),
      ),
      GridModuleItem(
        icon: Icons.calendar_month,
        label: 'Lịch Âm - Dương',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LichScreen())),
      ),
      GridModuleItem(
        icon: Icons.timer,
        label: 'Bấm giờ',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DongHoBamGioScreen())),
      ),
      GridModuleItem(
        icon: Icons.flashlight_on,
        label: 'Đèn pin',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DenPinScreen())),
      ),
      GridModuleItem(
        icon: Icons.explore,
        label: 'La bàn',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LaBanScreen())),
      ),
      GridModuleItem(
        icon: Icons.straighten,
        label: 'Thước đo',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThuocDoScreen())),
      ),
      GridModuleItem(
        icon: Icons.speed,
        label: 'Speedtest',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpeedtestScreen())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cộng đồng')),
      body: ListView(
        children: [
          _tieuDeNhom('Công việc & KPI'),
          IconGridView(items: congViec, cuonRieng: false),
          // "Hạ tầng mạng" giờ LUÔN hiện (không còn bọc if ẩn cả danh mục nữa)
          // vì "Bản đồ số khách hàng" và "Thu thập tọa độ" không cần quyền
          // riêng phía app - chỉ 2 icon Hộp cáp GPON/Chấm tủ mới ẩn/hiện theo
          // đúng quyền được cấp.
          _tieuDeNhom('Hạ tầng mạng'),
          IconGridView(
            items: [
              if (_coQuyenHopCap) banDoHopCap,
              banDoKhachHang,
              thuThapToaDo,
              if (_coQuyenChamTu) chamTuDeXuat,
            ],
            cuonRieng: false,
          ),
          _tieuDeNhom('Học tập & Tài liệu'),
          IconGridView(items: hocTap, cuonRieng: false),
          _tieuDeNhom('Cộng đồng & Ưu đãi'),
          IconGridView(items: congDong, cuonRieng: false),
          _tieuDeNhom('Tiện ích'),
          IconGridView(items: tienIch, cuonRieng: false),
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
