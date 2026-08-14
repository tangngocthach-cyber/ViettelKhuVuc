/// Hiệu chuẩn thước đo - LƯU Ý QUAN TRỌNG: KHÔNG có công thức toán nào tính
/// đúng "bao nhiêu điểm ảnh logic (dp) = 1cm thật" cho MỌI điện thoại. Lý
/// thuyết "160dp = 1 inch" (chuẩn mdpi Android) chỉ ĐÚNG TƯƠNG ĐỐI - nhiều
/// máy thật báo sai `devicePixelRatio` so với mật độ điểm ảnh vật lý thật,
/// khiến thước đo theo lý thuyết bị lệch (ĐÚNG LỖI THẬT đã thấy: thước hiện
/// tại nén 9cm vào khoảng ngắn hơn 9cm thật trên ảnh chụp máy thật). CÁCH
/// DUY NHẤT đo đúng là bắt người dùng tự hiệu chuẩn 1 lần bằng vật chuẩn có
/// kích thước THẬT đã biết (thẻ ATM/CCCD chuẩn ISO 85.6mm, hoặc tự nhập kích
/// thước vật khác) - lưu lại hệ số riêng cho từng máy.
class RulerCalibration {
  /// Số điểm ảnh logic (dp) tương ứng với ĐÚNG 1cm thật trên máy NÀY - giá
  /// trị mặc định (chưa hiệu chuẩn) dùng ước lượng lý thuyết 160dp/inch,
  /// LUÔN hiển thị rõ cho người dùng biết đây là "chưa hiệu chuẩn, có thể
  /// sai" cho tới khi họ tự hiệu chuẩn ít nhất 1 lần.
  final double dpMoiCm;
  final bool daHieuChuan;
  final DateTime? thoiGianHieuChuan;

  const RulerCalibration({required this.dpMoiCm, required this.daHieuChuan, this.thoiGianHieuChuan});

  /// Giá trị mặc định lúc chưa hiệu chuẩn - ước lượng lý thuyết, có thể sai.
  factory RulerCalibration.macDinh() {
    const dpMoiInchLyThuyet = 160.0; // chuẩn mdpi Android - KHÔNG đảm bảo đúng thật trên mọi máy
    return const RulerCalibration(dpMoiCm: dpMoiInchLyThuyet / 2.54, daHieuChuan: false);
  }

  /// Tính hệ số hiệu chuẩn MỚI từ: khoảng cách đo được trên màn hình (tính
  /// bằng dp, do người dùng tự kéo khớp với vật chuẩn) và kích thước THẬT
  /// (cm) của vật chuẩn đó.
  factory RulerCalibration.tuDoDacThuc({required double khoangCachDp, required double kichThuocThatCm}) {
    return RulerCalibration(
      dpMoiCm: khoangCachDp / kichThuocThatCm,
      daHieuChuan: true,
      thoiGianHieuChuan: DateTime.now(),
    );
  }

  double dpToiDonVi(String donVi) {
    switch (donVi) {
      case 'mm':
        return dpMoiCm / 10;
      case 'inch':
        return dpMoiCm * 2.54;
      default:
        return dpMoiCm;
    }
  }

  Map<String, dynamic> toJson() => {
        'dp_moi_cm': dpMoiCm,
        'da_hieu_chuan': daHieuChuan,
        'thoi_gian': thoiGianHieuChuan?.toIso8601String(),
      };

  factory RulerCalibration.fromJson(Map<String, dynamic> j) => RulerCalibration(
        dpMoiCm: (j['dp_moi_cm'] as num).toDouble(),
        daHieuChuan: j['da_hieu_chuan'] ?? false,
        thoiGianHieuChuan: j['thoi_gian'] != null ? DateTime.tryParse(j['thoi_gian']) : null,
      );
}

/// Vật chuẩn có kích thước THẬT đã biết trước - dùng để hiệu chuẩn nhanh mà
/// người dùng không cần tự đo/nhập số liệu.
class VatChuanHieuChuan {
  final String ten;
  final double kichThuocCm;
  const VatChuanHieuChuan(this.ten, this.kichThuocCm);

  static const cacVatChuanCoSan = [
    VatChuanHieuChuan('Thẻ ATM / CCCD (chuẩn ISO, chiều dài)', 8.56),
    VatChuanHieuChuan('Thẻ ATM / CCCD (chuẩn ISO, chiều rộng)', 5.398),
    VatChuanHieuChuan('Vật chuẩn 10 cm (tự đo bằng thước thật)', 10.0),
  ];
}
