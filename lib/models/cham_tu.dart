/// 1 đề xuất Chấm tủ - dữ liệu đồng bộ với server (khác Sổ ghi chú lưu local).
class ChamTu {
  final int id;
  final String loaiTu; // 'tu_cung' | 'tu_8'
  final double latitude;
  final double longitude;
  final String diaChi;
  final String anhUrl;
  final String ghiChu;
  final String trangThai; // 'cho_duyet' | 'da_duyet' | 'tu_choi'
  final String? lyDoTuChoi;
  final int customerId;
  final String tenNguoiTao;
  final String thietBi;
  final DateTime ngayTao;

  ChamTu({
    required this.id,
    required this.loaiTu,
    required this.latitude,
    required this.longitude,
    required this.diaChi,
    required this.anhUrl,
    required this.ghiChu,
    required this.trangThai,
    this.lyDoTuChoi,
    required this.customerId,
    required this.tenNguoiTao,
    required this.thietBi,
    required this.ngayTao,
  });

  factory ChamTu.fromJson(Map<String, dynamic> j) => ChamTu(
        id: int.parse('${j['id']}'),
        loaiTu: j['loai_tu'] ?? '',
        latitude: double.tryParse('${j['latitude']}') ?? 0,
        longitude: double.tryParse('${j['longitude']}') ?? 0,
        diaChi: j['dia_chi'] ?? '',
        anhUrl: j['anh_url'] ?? '',
        ghiChu: j['ghi_chu'] ?? '',
        trangThai: j['trang_thai'] ?? 'cho_duyet',
        lyDoTuChoi: j['ly_do_tu_choi'],
        customerId: int.parse('${j['customer_id']}'),
        tenNguoiTao: j['ten_nguoi_tao'] ?? '',
        thietBi: j['thiet_bi'] ?? '',
        ngayTao: DateTime.tryParse(j['ngay_tao'] ?? '') ?? DateTime.now(),
      );

  String get linkGoogleMaps => 'https://maps.google.com/?q=$latitude,$longitude';
}

class LoaiTu {
  static const tuCung = 'tu_cung';
  static const tu8 = 'tu_8';

  static String ten(String ma) => ma == tuCung ? 'Tủ cứng' : 'Tủ 8 (Tủ MR)';

  /// Màu riêng biệt cho từng loại - dùng cả trên danh sách lẫn marker bản đồ
  static int mauHex(String ma) => ma == tuCung ? 0xFF1976D2 : 0xFFEF6C00;
}

class TrangThaiChamTu {
  static const choDuyet = 'cho_duyet';
  static const daDuyet = 'da_duyet';
  static const tuChoi = 'tu_choi';

  static String ten(String ma) {
    switch (ma) {
      case daDuyet:
        return 'Đã duyệt';
      case tuChoi:
        return 'Từ chối';
      default:
        return 'Chờ duyệt';
    }
  }

  static int mauHex(String ma) {
    switch (ma) {
      case daDuyet:
        return 0xFF43A047;
      case tuChoi:
        return 0xFFE53935;
      default:
        return 0xFFFB8C00;
    }
  }
}
