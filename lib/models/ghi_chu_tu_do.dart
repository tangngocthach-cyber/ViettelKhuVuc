/// 1 ghi chú kiểu "Ghi chú" của iOS - hỗ trợ CHỮ, NÉT VẼ TAY (ảnh PNG lưu
/// trên máy), và GHI ÂM (file audio lưu trên máy). Lưu HOÀN TOÀN OFFLINE,
/// không đồng bộ server - phù hợp ghi chú cá nhân nhanh, riêng tư.
class GhiChuTuDo {
  final int id; // dùng timestamp lúc tạo làm ID duy nhất
  String tieuDe;
  String noiDung;
  String? duongDanVeTay; // đường dẫn file PNG nét vẽ tay (null = chưa có)
  String? duongDanGhiAm; // đường dẫn file ghi âm .m4a (null = chưa có)
  int? giayGhiAm; // thời lượng ghi âm (giây) - hiện cho người dùng biết trước khi bấm nghe
  final DateTime ngayTao;
  DateTime ngayCapNhat;

  GhiChuTuDo({
    required this.id,
    this.tieuDe = '',
    this.noiDung = '',
    this.duongDanVeTay,
    this.duongDanGhiAm,
    this.giayGhiAm,
    required this.ngayTao,
    required this.ngayCapNhat,
  });

  bool get coVeTay => duongDanVeTay != null;
  bool get coGhiAm => duongDanGhiAm != null;

  /// Tiêu đề hiển thị trong danh sách - nếu chưa đặt tiêu đề riêng, lấy dòng
  /// đầu tiên của nội dung (giống cách iOS Notes tự đặt tên).
  String get tieuDeHienThi {
    if (tieuDe.trim().isNotEmpty) return tieuDe.trim();
    final dongDau = noiDung.trim().split('\n').firstWhere((d) => d.trim().isNotEmpty, orElse: () => '');
    return dongDau.isNotEmpty ? dongDau : '(Ghi chú trống)';
  }

  factory GhiChuTuDo.fromJson(Map<String, dynamic> j) => GhiChuTuDo(
        id: j['id'],
        tieuDe: j['tieu_de'] ?? '',
        noiDung: j['noi_dung'] ?? '',
        duongDanVeTay: j['duong_dan_ve_tay'],
        duongDanGhiAm: j['duong_dan_ghi_am'],
        giayGhiAm: j['giay_ghi_am'],
        ngayTao: DateTime.tryParse(j['ngay_tao'] ?? '') ?? DateTime.now(),
        ngayCapNhat: DateTime.tryParse(j['ngay_cap_nhat'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tieu_de': tieuDe,
        'noi_dung': noiDung,
        'duong_dan_ve_tay': duongDanVeTay,
        'duong_dan_ghi_am': duongDanGhiAm,
        'giay_ghi_am': giayGhiAm,
        'ngay_tao': ngayTao.toIso8601String(),
        'ngay_cap_nhat': ngayCapNhat.toIso8601String(),
      };
}
