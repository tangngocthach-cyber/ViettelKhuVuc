import 'ruler_calibration.dart';

/// 1 phép đo A→B đang thực hiện hoặc đã khóa kết quả.
class RulerMeasurement {
  final double diemA; // vị trí dp trên trục thước
  final double diemB;
  const RulerMeasurement({required this.diemA, required this.diemB});

  double get khoangCachDp => (diemB - diemA).abs();

  double doDaiTheoDonVi(RulerCalibration hieuChuan, String donVi) {
    final dpMoiDonVi = hieuChuan.dpToiDonVi(donVi);
    return dpMoiDonVi > 0 ? khoangCachDp / dpMoiDonVi : 0;
  }
}

/// 1 kết quả đã bấm "Lưu" - lưu lại để xem sau (lịch sử đo gần đây).
class KetQuaDaLuu {
  final int id;
  final double giaTri;
  final String donVi;
  final DateTime thoiGian;
  const KetQuaDaLuu({required this.id, required this.giaTri, required this.donVi, required this.thoiGian});

  Map<String, dynamic> toJson() => {'id': id, 'gia_tri': giaTri, 'don_vi': donVi, 'thoi_gian': thoiGian.toIso8601String()};

  factory KetQuaDaLuu.fromJson(Map<String, dynamic> j) => KetQuaDaLuu(
        id: j['id'],
        giaTri: (j['gia_tri'] as num).toDouble(),
        donVi: j['don_vi'],
        thoiGian: DateTime.tryParse(j['thoi_gian'] ?? '') ?? DateTime.now(),
      );
}
