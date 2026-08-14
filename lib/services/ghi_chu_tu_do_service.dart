import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ghi_chu_tu_do.dart';

/// Lưu trữ Sổ ghi chú kiểu iOS Notes - dùng file JSON RIÊNG BIỆT
/// (so_ghi_chu_tu_do.json), KHÔNG chung với file "so_ghi_chu.json" của màn
/// "Quản lý dữ liệu khách hàng" (trước đây gọi là Sổ ghi chú, nay đổi tên -
/// dữ liệu 2 bên hoàn toàn tách biệt, không được lẫn vào nhau).
class GhiChuTuDoService {
  static Future<File> _fileDuLieu() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/so_ghi_chu_tu_do.json');
  }

  static Future<Directory> _thuMucTepDinhKem() async {
    final dir = await getApplicationDocumentsDirectory();
    final thuMuc = Directory('${dir.path}/ghi_chu_tu_do_dinh_kem');
    if (!await thuMuc.exists()) await thuMuc.create(recursive: true);
    return thuMuc;
  }

  static Future<List<GhiChuTuDo>> layDanhSach() async {
    try {
      final file = await _fileDuLieu();
      if (!await file.exists()) return [];
      final danhSachTho = jsonDecode(await file.readAsString()) as List;
      final ds = danhSachTho.map((e) => GhiChuTuDo.fromJson(e)).toList();
      ds.sort((a, b) => b.ngayCapNhat.compareTo(a.ngayCapNhat)); // mới sửa gần đây lên đầu
      return ds;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _luuTatCa(List<GhiChuTuDo> ds) async {
    final file = await _fileDuLieu();
    await file.writeAsString(jsonEncode(ds.map((g) => g.toJson()).toList()));
  }

  static Future<void> luu(GhiChuTuDo ghiChu) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((g) => g.id == ghiChu.id);
    if (viTri >= 0) {
      ds[viTri] = ghiChu;
    } else {
      ds.add(ghiChu);
    }
    await _luuTatCa(ds);
  }

  static Future<void> xoa(int id) async {
    final ds = await layDanhSach();
    final ghiChu = ds.where((g) => g.id == id).firstOrNull;
    ds.removeWhere((g) => g.id == id);
    await _luuTatCa(ds);
    // Dọn luôn file đính kèm (ảnh vẽ tay/ghi âm) - tránh rác chiếm bộ nhớ máy.
    if (ghiChu != null) {
      for (final duongDan in [ghiChu.duongDanVeTay, ghiChu.duongDanGhiAm]) {
        if (duongDan == null) continue;
        final f = File(duongDan);
        if (await f.exists()) await f.delete();
      }
    }
  }

  /// Đường dẫn file MỚI (chưa tồn tại) để lưu 1 tệp đính kèm (ảnh vẽ tay hoặc
  /// ghi âm) - đặt trong thư mục riêng, tên theo timestamp để không trùng.
  static Future<String> duongDanTepMoi(String duoiFile) async {
    final thuMuc = await _thuMucTepDinhKem();
    return '${thuMuc.path}/${DateTime.now().millisecondsSinceEpoch}.$duoiFile';
  }

  // ============================================================================
  // SAO LƯU / KHÔI PHỤC - dữ liệu Sổ ghi chú CHỈ nằm trên máy (không đồng bộ
  // server) - XÓA APP CÀI LẠI SẼ MẤT TRẮNG nếu không sao lưu trước. File sao
  // lưu NHÚNG LUÔN cả ảnh vẽ tay + ghi âm dạng base64 vào trong 1 file JSON
  // duy nhất (không cần thư viện nén .zip riêng) - khôi phục lại đầy đủ
  // 100%, không thiếu file đính kèm nào.
  // ============================================================================

  /// Xuất TOÀN BỘ ghi chú (kèm ảnh vẽ tay + ghi âm) ra 1 file JSON duy nhất.
  static Future<File> xuatBackup() async {
    final ds = await layDanhSach();
    final dir = await getTemporaryDirectory();
    await _donDepFileTamSaoLuu(dir);

    final dsXuat = <Map<String, dynamic>>[];
    for (final gc in ds) {
      final j = gc.toJson();
      if (gc.duongDanVeTay != null) {
        final f = File(gc.duongDanVeTay!);
        if (await f.exists()) {
          j['ve_tay_base64'] = base64Encode(await f.readAsBytes());
          j['ve_tay_duoi_file'] = gc.duongDanVeTay!.split('.').last;
        }
      }
      if (gc.duongDanGhiAm != null) {
        final f = File(gc.duongDanGhiAm!);
        if (await f.exists()) {
          j['ghi_am_base64'] = base64Encode(await f.readAsBytes());
          j['ghi_am_duoi_file'] = gc.duongDanGhiAm!.split('.').last;
        }
      }
      dsXuat.add(j);
    }

    final tenFile = 'sao-luu-so-ghi-chu-${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$tenFile');
    await file.writeAsString(jsonEncode(dsXuat));
    await _luuThoiGianSaoLuuCuoi();
    return file;
  }

  static const _khoaLanSaoLuuCuoi = 'so_ghi_chu_tu_do_lan_sao_luu_cuoi';

  static Future<void> _luuThoiGianSaoLuuCuoi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_khoaLanSaoLuuCuoi, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Lấy thời điểm sao lưu gần nhất - dùng để nhắc người dùng nếu đã lâu
  /// chưa sao lưu (dữ liệu chỉ nằm trên máy, xóa app cài lại là mất trắng).
  static Future<DateTime?> layLanSaoLuuCuoi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final luu = prefs.getString(_khoaLanSaoLuuCuoi);
      return luu != null ? DateTime.tryParse(luu) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _donDepFileTamSaoLuu(Directory dir) async {
    try {
      for (final f in dir.listSync()) {
        if (f is File && f.path.split('/').last.startsWith('sao-luu-so-ghi-chu-')) {
          try { await f.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Đọc file sao lưu JSON, giải mã lại ảnh vẽ tay/ghi âm thành file THẬT
  /// trên máy, rồi THÊM MỚI/CẬP NHẬT vào Sổ ghi chú theo ID - KHÔNG xóa ghi
  /// chú hiện có nào không nằm trong file sao lưu (an toàn, không mất dữ
  /// liệu ngoài ý muốn). Trả về số lượng đã khôi phục thành công.
  static Future<int> khoiPhucTuFile(File file) async {
    final noiDung = await file.readAsString();
    final danhSachTho = jsonDecode(noiDung) as List;
    final dsHienCo = await layDanhSach();

    var soLuongKhoiPhuc = 0;
    for (final tho in danhSachTho) {
      try {
        String? duongDanVeTayMoi;
        if (tho['ve_tay_base64'] != null) {
          duongDanVeTayMoi = await duongDanTepMoi(tho['ve_tay_duoi_file'] ?? 'png');
          await File(duongDanVeTayMoi).writeAsBytes(base64Decode(tho['ve_tay_base64']));
        }
        String? duongDanGhiAmMoi;
        if (tho['ghi_am_base64'] != null) {
          duongDanGhiAmMoi = await duongDanTepMoi(tho['ghi_am_duoi_file'] ?? 'm4a');
          await File(duongDanGhiAmMoi).writeAsBytes(base64Decode(tho['ghi_am_base64']));
        }

        final gc = GhiChuTuDo(
          id: tho['id'],
          tieuDe: tho['tieu_de'] ?? '',
          noiDung: tho['noi_dung'] ?? '',
          duongDanVeTay: duongDanVeTayMoi,
          duongDanGhiAm: duongDanGhiAmMoi,
          giayGhiAm: tho['giay_ghi_am'],
          ngayTao: DateTime.tryParse(tho['ngay_tao'] ?? '') ?? DateTime.now(),
          ngayCapNhat: DateTime.tryParse(tho['ngay_cap_nhat'] ?? '') ?? DateTime.now(),
        );
        final viTri = dsHienCo.indexWhere((e) => e.id == gc.id);
        if (viTri >= 0) {
          dsHienCo[viTri] = gc;
        } else {
          dsHienCo.add(gc);
        }
        soLuongKhoiPhuc++;
      } catch (_) {
        // 1 dòng lỗi định dạng thì bỏ qua, không làm hỏng cả quá trình khôi phục
      }
    }
    await _luuTatCa(dsHienCo);
    return soLuongKhoiPhuc;
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
