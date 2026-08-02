/// 1 ghi chú / nhắc hẹn cá nhân - lưu HOÀN TOÀN TRÊN MÁY (không đồng bộ lên
/// server), phù hợp việc riêng tư như ghi chú công việc cá nhân của từng CNKD.
class GhiChu {
  final int id; // dùng timestamp lúc tạo làm ID duy nhất, cũng dùng làm ID thông báo hẹn giờ
  String tieuDe;
  String noiDung;
  String loai; // 'khach_hang' | 'thu_cuoc' | 'cham_soc' | 'khac'
  DateTime? thoiGianNhac; // null = ghi chú thường, không hẹn giờ
  bool daXong;
  final DateTime ngayTao;

  GhiChu({
    required this.id,
    required this.tieuDe,
    this.noiDung = '',
    this.loai = 'khac',
    this.thoiGianNhac,
    this.daXong = false,
    required this.ngayTao,
  });

  factory GhiChu.fromJson(Map<String, dynamic> j) => GhiChu(
        id: j['id'],
        tieuDe: j['tieu_de'] ?? '',
        noiDung: j['noi_dung'] ?? '',
        loai: j['loai'] ?? 'khac',
        thoiGianNhac: j['thoi_gian_nhac'] != null ? DateTime.tryParse(j['thoi_gian_nhac']) : null,
        daXong: j['da_xong'] ?? false,
        ngayTao: DateTime.tryParse(j['ngay_tao'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tieu_de': tieuDe,
        'noi_dung': noiDung,
        'loai': loai,
        'thoi_gian_nhac': thoiGianNhac?.toIso8601String(),
        'da_xong': daXong,
        'ngay_tao': ngayTao.toIso8601String(),
      };
}

/// Thông tin hiển thị (tên, icon, màu) cho từng loại ghi chú.
class LoaiGhiChu {
  final String ma;
  final String ten;
  final int mauHex;
  const LoaiGhiChu(this.ma, this.ten, this.mauHex);

  static const List<LoaiGhiChu> tatCa = [
    LoaiGhiChu('khach_hang', 'Khách hàng', 0xFF2979FF),
    LoaiGhiChu('thu_cuoc', 'Thu cước', 0xFFFF9800),
    LoaiGhiChu('cham_soc', 'Chăm sóc', 0xFF43A047),
    LoaiGhiChu('khac', 'Khác', 0xFF757575),
  ];

  static LoaiGhiChu tuMa(String ma) => tatCa.firstWhere((l) => l.ma == ma, orElse: () => tatCa.last);
}
