import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
