import 'dart:convert';

/// Model cho module Khảo sát lý do khách hàng - đồng bộ đúng cấu trúc với
/// API PHP (api/khao-sat/*.php) và bảng CSDL (khao_sat_*).

class KhaoSatDot {
  final int id;
  final String tenKhaoSat;
  final String moTa;
  final int soKhach;
  final int soDaKhaoSat;

  KhaoSatDot({required this.id, required this.tenKhaoSat, required this.moTa, required this.soKhach, required this.soDaKhaoSat});

  factory KhaoSatDot.fromJson(Map<String, dynamic> j) {
    int soNguyen(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);
    return KhaoSatDot(
      id: soNguyen(j['id']),
      tenKhaoSat: j['ten_khao_sat']?.toString() ?? '',
      moTa: j['mo_ta']?.toString() ?? '',
      soKhach: soNguyen(j['so_khach']),
      soDaKhaoSat: soNguyen(j['so_da_khao_sat']),
    );
  }
}

class KhaoSatTruongTin {
  final int id;
  final String tenTruong;
  final String loaiTruong; // text | textarea | number | date | select
  final List<String> tuyChon;
  final bool batBuoc;

  KhaoSatTruongTin({required this.id, required this.tenTruong, required this.loaiTruong, required this.tuyChon, required this.batBuoc});

  factory KhaoSatTruongTin.fromJson(Map<String, dynamic> j) {
    int soNguyen(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);
    return KhaoSatTruongTin(
      id: soNguyen(j['id']),
      tenTruong: j['ten_truong']?.toString() ?? '',
      loaiTruong: j['loai_truong']?.toString() ?? 'text',
      tuyChon: (j['tuy_chon'] as List? ?? []).map((e) => e.toString()).toList(),
      batBuoc: soNguyen(j['bat_buoc']) == 1,
    );
  }
}

class KhaoSatLyDo {
  final int id;
  final String lyDo;
  KhaoSatLyDo({required this.id, required this.lyDo});
  factory KhaoSatLyDo.fromJson(Map<String, dynamic> j) => KhaoSatLyDo(id: (j['id'] as num).toInt(), lyDo: j['ly_do']?.toString() ?? '');
}

class KhaoSatKhachHang {
  final int id;
  final String tenKhachHang;
  final String soTb;
  final String sdt;
  final String maTvv;
  final bool daKhaoSat;
  final int? lyDoId;
  final String moTaChiTiet;
  final Map<String, String> duLieuTuyChinh; // key: id trường (dạng chuỗi), value: câu trả lời

  KhaoSatKhachHang({
    required this.id,
    required this.tenKhachHang,
    required this.soTb,
    required this.sdt,
    required this.maTvv,
    required this.daKhaoSat,
    this.lyDoId,
    required this.moTaChiTiet,
    required this.duLieuTuyChinh,
  });

  /// Cột `du_lieu_truong_tuy_chinh` từ CSDL là kiểu TEXT chứa 1 chuỗi JSON
  /// (không phải object JSON lồng sẵn) - server trả nguyên chuỗi này qua
  /// API, nên phải TỰ jsonDecode lại ở đây mới đọc được từng câu trả lời.
  factory KhaoSatKhachHang.fromJson(Map<String, dynamic> j) {
    int soNguyen(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);
    String chuoi(dynamic v) => v == null ? '' : '$v';
    Map<String, String> duLieu = {};
    final rawDuLieu = j['du_lieu_truong_tuy_chinh'];
    if (rawDuLieu is String && rawDuLieu.isNotEmpty) {
      try {
        final parsed = jsonDecode(rawDuLieu);
        if (parsed is Map) { duLieu = parsed.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')); }
      } catch (_) {
        duLieu = {};
      }
    }
    return KhaoSatKhachHang(
      id: soNguyen(j['id']),
      tenKhachHang: chuoi(j['ten_khach_hang']),
      soTb: chuoi(j['so_tb']),
      sdt: chuoi(j['sdt']),
      maTvv: chuoi(j['ma_tvv']),
      daKhaoSat: soNguyen(j['da_khao_sat']) == 1,
      lyDoId: j['ly_do_id'] == null ? null : soNguyen(j['ly_do_id']),
      moTaChiTiet: chuoi(j['mo_ta_chi_tiet']),
      duLieuTuyChinh: duLieu,
    );
  }
}
