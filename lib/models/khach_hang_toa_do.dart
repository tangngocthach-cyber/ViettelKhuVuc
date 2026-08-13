/// Dữ liệu 1 khách hàng kèm tọa độ (nếu có) + hộp cáp GPON gần nhất (nếu
/// có) - khớp đúng các trường trả về từ api/toa-do/danh-sach.php.
class KhachHangToaDo {
  final int id;
  final String tenKhachHang;
  final String soTb;
  final String diaChiTbc;
  final String tenTvv;
  final String maTvv;
  final String soDienThoai;
  final String maHopCap;
  final double? lat;
  final double? lng;
  final String? toaDoNguon;
  final String? thoiGianCapNhat;
  final double? hopCapLat;
  final double? hopCapLng;

  bool get coToaDo => lat != null && lng != null;

  KhachHangToaDo({
    required this.id,
    required this.tenKhachHang,
    required this.soTb,
    required this.diaChiTbc,
    required this.tenTvv,
    required this.maTvv,
    required this.soDienThoai,
    required this.maHopCap,
    this.lat,
    this.lng,
    this.toaDoNguon,
    this.thoiGianCapNhat,
    this.hopCapLat,
    this.hopCapLng,
  });

  static double? _soHoacRong(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory KhachHangToaDo.fromJson(Map<String, dynamic> j) => KhachHangToaDo(
        id: (j['id'] as num?)?.toInt() ?? 0,
        tenKhachHang: (j['ten_khach_hang'] ?? '').toString(),
        soTb: (j['so_tb'] ?? '').toString(),
        diaChiTbc: (j['dia_chi_tbc'] ?? '').toString(),
        tenTvv: (j['ten_tvv'] ?? '').toString(),
        maTvv: (j['ma_tvv'] ?? '').toString(),
        soDienThoai: (j['so_dien_thoai'] ?? '').toString(),
        maHopCap: (j['ma_hop_cap'] ?? '').toString(),
        lat: _soHoacRong(j['lat']),
        lng: _soHoacRong(j['lng']),
        toaDoNguon: j['toa_do_nguon']?.toString(),
        thoiGianCapNhat: j['thoi_gian_cap_nhat']?.toString(),
        hopCapLat: _soHoacRong(j['hop_cap_lat']),
        hopCapLng: _soHoacRong(j['hop_cap_lng']),
      );
}
