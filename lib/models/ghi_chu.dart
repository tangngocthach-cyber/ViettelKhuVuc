/// 1 ghi chú / nhắc hẹn cá nhân - lưu HOÀN TOÀN TRÊN MÁY (không đồng bộ lên
/// server), phù hợp việc riêng tư như ghi chú công việc cá nhân của từng CNKD.
class GhiChu {
  final int id; // dùng timestamp lúc tạo làm ID duy nhất, cũng dùng làm ID thông báo hẹn giờ
  String tieuDe;
  String noiDung;
  String loai; // 'khach_hang' | 'thu_cuoc' | 'cham_soc' | 'khac'
  String? soDienThoai; // không bắt buộc - có thì hiện nút gọi nhanh
  int mucDoUuTien; // 0 = thấp, 1 = trung bình (mặc định), 2 = cao
  DateTime? thoiGianNhac; // null = ghi chú thường, không hẹn giờ
  int? chuKyLapLaiThang; // null = không lặp lại; VD 6 = mỗi 6 tháng, 12 = mỗi năm
  int soLanDaGiaHan; // đếm đã gia hạn/thu bao nhiêu kỳ - hiện cho người dùng thấy lịch sử
  bool daXong;
  final DateTime ngayTao;

  GhiChu({
    required this.id,
    required this.tieuDe,
    this.noiDung = '',
    this.loai = 'khac',
    this.soDienThoai,
    this.mucDoUuTien = 1,
    this.thoiGianNhac,
    this.chuKyLapLaiThang,
    this.soLanDaGiaHan = 0,
    this.daXong = false,
    required this.ngayTao,
  });

  bool get coLapLai => chuKyLapLaiThang != null && chuKyLapLaiThang! > 0;

  factory GhiChu.fromJson(Map<String, dynamic> j) => GhiChu(
        id: j['id'],
        tieuDe: j['tieu_de'] ?? '',
        noiDung: j['noi_dung'] ?? '',
        loai: j['loai'] ?? 'khac',
        // Dữ liệu cũ (tạo trước khi có các tính năng này) không có những
        // trường dưới đây - PHẢI có giá trị mặc định an toàn, không được để
        // lỗi khi đọc lại dữ liệu cũ.
        soDienThoai: j['so_dien_thoai'],
        mucDoUuTien: j['muc_do_uu_tien'] ?? 1,
        thoiGianNhac: j['thoi_gian_nhac'] != null ? DateTime.tryParse(j['thoi_gian_nhac']) : null,
        chuKyLapLaiThang: j['chu_ky_lap_lai_thang'],
        soLanDaGiaHan: j['so_lan_da_gia_han'] ?? 0,
        daXong: j['da_xong'] ?? false,
        ngayTao: DateTime.tryParse(j['ngay_tao'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tieu_de': tieuDe,
        'noi_dung': noiDung,
        'loai': loai,
        'so_dien_thoai': soDienThoai,
        'muc_do_uu_tien': mucDoUuTien,
        'thoi_gian_nhac': thoiGianNhac?.toIso8601String(),
        'chu_ky_lap_lai_thang': chuKyLapLaiThang,
        'so_lan_da_gia_han': soLanDaGiaHan,
        'da_xong': daXong,
        'ngay_tao': ngayTao.toIso8601String(),
      };

  /// Cộng thêm N THÁNG vào 1 ngày giờ - dùng cho cả "Gia hạn nhanh" lẫn tính
  /// kỳ hạn tiếp theo của ghi chú lặp lại. Xử lý ĐÚNG trường hợp cuối tháng
  /// không khớp (VD 31/1 + 1 tháng KHÔNG được ra 31/2 - vì tháng 2 không có
  /// ngày đó - phải tự lùi về ngày cuối cùng của tháng đích, tức 28 hoặc 29/2).
  static DateTime congThang(DateTime goc, int soThang) {
    final tongThang = goc.month - 1 + soThang;
    final namMoi = goc.year + tongThang ~/ 12;
    final thangMoi = tongThang % 12 + 1;
    final ngayCuoiThangMoi = DateTime(namMoi, thangMoi + 1, 0).day;
    final ngay = goc.day > ngayCuoiThangMoi ? ngayCuoiThangMoi : goc.day;
    return DateTime(namMoi, thangMoi, ngay, goc.hour, goc.minute);
  }
}

/// Các mốc chu kỳ lặp lại dựng sẵn thường dùng nhất trong nghiệp vụ viễn
/// thông (đóng cước trước theo gói 6 tháng / 1 năm...).
class ChuKyLapLai {
  final int? soThang; // null = "Không lặp lại"
  final String ten;
  const ChuKyLapLai(this.soThang, this.ten);

  static const List<ChuKyLapLai> tatCa = [
    ChuKyLapLai(null, 'Không lặp lại'),
    ChuKyLapLai(1, 'Mỗi tháng'),
    ChuKyLapLai(3, 'Mỗi 3 tháng'),
    ChuKyLapLai(6, 'Mỗi 6 tháng'),
    ChuKyLapLai(12, 'Mỗi năm'),
  ];
}

/// Thông tin hiển thị cho từng mức ưu tiên.
class MucDoUuTien {
  final int ma;
  final String ten;
  final int mauHex;
  const MucDoUuTien(this.ma, this.ten, this.mauHex);

  static const List<MucDoUuTien> tatCa = [
    MucDoUuTien(2, 'Cao', 0xFFE53935),
    MucDoUuTien(1, 'Trung bình', 0xFFFB8C00),
    MucDoUuTien(0, 'Thấp', 0xFF43A047),
  ];

  static MucDoUuTien tuMa(int ma) => tatCa.firstWhere((m) => m.ma == ma, orElse: () => tatCa[1]);
}

/// Thông tin hiển thị (tên, icon, màu) cho từng loại ghi chú.
class LoaiGhiChu {
  final String ma;
  final String ten;
  final int mauHex;
  const LoaiGhiChu(this.ma, this.ten, this.mauHex);

  /// Tiền tố đánh dấu đây là loại DO NGƯỜI DÙNG TỰ ĐẶT (không nằm trong danh
  /// sách dựng sẵn) - lưu kèm luôn tên hiển thị vào trong mã, VD
  /// "TUYCHON::Sửa hẹn khách VIP" - không cần thêm bảng/CSDL riêng.
  static const _tienToTuyChon = 'TUYCHON::';

  static const List<LoaiGhiChu> tatCa = [
    LoaiGhiChu('khach_hang', 'Khách hàng', 0xFF2979FF),
    LoaiGhiChu('thu_cuoc', 'Thu cước', 0xFFFF9800),
    LoaiGhiChu('cuoc_dong_truoc', 'Cước đóng trước', 0xFF00897B),
    LoaiGhiChu('lap_ftth', 'Lắp FTTH', 0xFF5E35B1),
    LoaiGhiChu('lap_truyen_hinh', 'Lắp Truyền hình', 0xFFD81B60),
    LoaiGhiChu('cham_soc', 'Chăm sóc', 0xFF43A047),
    LoaiGhiChu('khac', 'Khác', 0xFF757575),
  ];

  static bool laLoaiTuyChon(String ma) => ma.startsWith(_tienToTuyChon);

  static String taoMaTuyChon(String tenTuNhap) => '$_tienToTuyChon$tenTuNhap';

  static LoaiGhiChu tuMa(String ma) {
    if (laLoaiTuyChon(ma)) {
      // Màu tím riêng cho loại tự đặt, dễ phân biệt với các loại dựng sẵn
      return LoaiGhiChu(ma, ma.substring(_tienToTuyChon.length), 0xFF8E24AA);
    }
    return tatCa.firstWhere((l) => l.ma == ma, orElse: () => tatCa.last);
  }
}
