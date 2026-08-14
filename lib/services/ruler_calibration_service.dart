import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ruler_calibration.dart';
import '../models/ruler_measurement.dart';

class RulerCalibrationService {
  static const _khoaHieuChuan = 'thuoc_do_hieu_chuan';
  static const _khoaLichSu = 'thuoc_do_lich_su_ket_qua';

  static Future<RulerCalibration> layHieuChuan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_khoaHieuChuan);
      if (raw == null) return RulerCalibration.macDinh();
      return RulerCalibration.fromJson(jsonDecode(raw));
    } catch (_) {
      return RulerCalibration.macDinh();
    }
  }

  static Future<void> luuHieuChuan(RulerCalibration hc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_khoaHieuChuan, jsonEncode(hc.toJson()));
  }

  static Future<void> xoaHieuChuan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_khoaHieuChuan);
  }

  static Future<List<KetQuaDaLuu>> layLichSu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_khoaLichSu) ?? [];
      final ds = raw.map((s) => KetQuaDaLuu.fromJson(jsonDecode(s))).toList();
      ds.sort((a, b) => b.thoiGian.compareTo(a.thoiGian));
      return ds;
    } catch (_) {
      return [];
    }
  }

  static Future<void> themVaoLichSu(double giaTri, String donVi) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_khoaLichSu) ?? [];
    final moi = KetQuaDaLuu(id: DateTime.now().millisecondsSinceEpoch, giaTri: giaTri, donVi: donVi, thoiGian: DateTime.now());
    raw.add(jsonEncode(moi.toJson()));
    // Chỉ giữ tối đa 20 kết quả gần nhất - tránh phình dữ liệu vô hạn.
    final ds = raw.map((s) => KetQuaDaLuu.fromJson(jsonDecode(s))).toList()..sort((a, b) => b.thoiGian.compareTo(a.thoiGian));
    final dsGiuLai = ds.take(20).map((k) => jsonEncode(k.toJson())).toList();
    await prefs.setStringList(_khoaLichSu, dsGiuLai);
  }

  static Future<void> xoaLichSu() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_khoaLichSu);
  }
}
