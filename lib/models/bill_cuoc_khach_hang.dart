/// Dữ liệu 1 khách hàng trong 1 kỳ cước - khớp đúng các trường trả về từ
/// api/bill-cuoc/danh-sach-khach-hang.php.
class BillCuocKhachHang {
  final int id;
  final String tenKhachHang;
  final String soTb;
  final String diaChiTbc;
  final String soDtLienHe;
  final String soHopDong;
  final String tenTvv;
  final String maTvv;
  final String soDienThoaiTvv; // số của CNKD (dùng làm liên hệ trên hóa đơn)
  final String hinhThucQuanLy;
  final int tongCuoc;
  final int noTruoc;
  final int thue;
  final int phatSinh;
  final int dieuChinh;
  final String soTienBangChu;
  final String maHopCap;
  final String tuoiTho;
  final String dichVu;
  final String loaiThueBao;
  final int congCuocDv;
  final int stt;
  final bool daThu;
  final int soLanDaInBill;
  final int soLanDaInNhiet;
  final int? lyDoChuaThuId;
  final String moTaLyDo;

  BillCuocKhachHang({
    required this.id,
    required this.tenKhachHang,
    required this.soTb,
    required this.diaChiTbc,
    required this.soDtLienHe,
    required this.soHopDong,
    required this.tenTvv,
    required this.maTvv,
    required this.soDienThoaiTvv,
    required this.hinhThucQuanLy,
    required this.tongCuoc,
    required this.noTruoc,
    required this.thue,
    required this.phatSinh,
    required this.dieuChinh,
    required this.soTienBangChu,
    required this.maHopCap,
    required this.tuoiTho,
    required this.dichVu,
    required this.loaiThueBao,
    required this.congCuocDv,
    required this.stt,
    required this.daThu,
    required this.soLanDaInBill,
    required this.soLanDaInNhiet,
    this.lyDoChuaThuId,
    this.moTaLyDo = '',
  });

  factory BillCuocKhachHang.fromJson(Map<String, dynamic> j) {
    int soNguyen(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);
    String chuoi(dynamic v) => v == null ? '' : '$v';
    return BillCuocKhachHang(
      id: soNguyen(j['id']),
      tenKhachHang: chuoi(j['ten_khach_hang']),
      soTb: chuoi(j['so_tb']),
      diaChiTbc: chuoi(j['dia_chi_tbc']),
      soDtLienHe: chuoi(j['so_dt_lien_he']),
      soHopDong: chuoi(j['so_hop_dong']),
      tenTvv: chuoi(j['ten_tvv']),
      maTvv: chuoi(j['ma_tvv']),
      soDienThoaiTvv: chuoi(j['so_dien_thoai']),
      hinhThucQuanLy: chuoi(j['hinh_thuc_quan_ly']),
      tongCuoc: soNguyen(j['tong_cuoc']),
      noTruoc: soNguyen(j['no_truoc']),
      thue: soNguyen(j['thue']),
      phatSinh: soNguyen(j['phat_sinh']),
      dieuChinh: soNguyen(j['dieu_chinh']),
      soTienBangChu: chuoi(j['so_tien_bang_chu']),
      maHopCap: chuoi(j['ma_hop_cap']),
      tuoiTho: chuoi(j['tuoi_tho']),
      dichVu: chuoi(j['dich_vu']),
      loaiThueBao: chuoi(j['loai_thue_bao']),
      congCuocDv: soNguyen(j['cong_cuoc_dv']),
      stt: soNguyen(j['stt']),
      daThu: soNguyen(j['da_thu']) == 1,
      soLanDaInBill: soNguyen(j['so_lan_da_in_bill']),
      soLanDaInNhiet: soNguyen(j['so_lan_da_in_nhiet']),
      lyDoChuaThuId: j['ly_do_chua_thu_id'] == null ? null : soNguyen(j['ly_do_chua_thu_id']),
      moTaLyDo: chuoi(j['mo_ta_ly_do']),
    );
  }
}

class BillCuocKy {
  final int id;
  final String tenKy;
  BillCuocKy({required this.id, required this.tenKy});
  factory BillCuocKy.fromJson(Map<String, dynamic> j) =>
      BillCuocKy(id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0, tenKy: '${j['ten_ky']}');
}

class BillCuocTvv {
  final String maTvv;
  final String tenTvv;
  BillCuocTvv({required this.maTvv, required this.tenTvv});
  factory BillCuocTvv.fromJson(Map<String, dynamic> j) =>
      BillCuocTvv(maTvv: '${j['ma_tvv']}', tenTvv: '${j['ten_tvv']}');
}
