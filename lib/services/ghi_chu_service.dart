import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/ghi_chu.dart';
import 'reminder_notification_service.dart';

/// Quản lý Sổ ghi chú - lưu HOÀN TOÀN OFFLINE trên máy (file JSON), không
/// cần server/mạng. Tự động đặt/hủy lịch nhắc hẹn khi thêm/sửa/xóa ghi chú
/// có hẹn giờ, dùng chung ReminderNotificationService đã có sẵn cho Chat.
class GhiChuService {
  // Cộng thêm 900 triệu vào ID thông báo để KHÔNG trùng với ID nhắc hẹn của
  // Chat (vốn dùng messageId thật từ CSDL, chắc chắn nhỏ hơn nhiều con số này).
  static const _bùTruId = 900000000;

  static Future<File> _fileDuLieu() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/so_ghi_chu.json');
  }

  static Future<List<GhiChu>> layDanhSach() async {
    try {
      final file = await _fileDuLieu();
      if (!await file.exists()) return [];
      final danhSachTho = jsonDecode(await file.readAsString()) as List;
      final ds = danhSachTho.map((e) => GhiChu.fromJson(e)).toList();
      // Sắp xếp: ghi chú có hẹn giờ CHƯA XONG lên đầu (theo thời gian gần
      // nhất), rồi tới ghi chú thường, ghi chú đã xong xuống cuối cùng.
      ds.sort((a, b) {
        if (a.daXong != b.daXong) return a.daXong ? 1 : -1;
        if (a.thoiGianNhac != null && b.thoiGianNhac != null) return a.thoiGianNhac!.compareTo(b.thoiGianNhac!);
        if (a.thoiGianNhac != null) return -1;
        if (b.thoiGianNhac != null) return 1;
        return b.ngayTao.compareTo(a.ngayTao);
      });
      return ds;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _luuTatCa(List<GhiChu> ds) async {
    final file = await _fileDuLieu();
    await file.writeAsString(jsonEncode(ds.map((e) => e.toJson()).toList()));
  }

  static Future<void> luu(GhiChu ghiChu) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((e) => e.id == ghiChu.id);
    if (viTri >= 0) {
      ds[viTri] = ghiChu;
    } else {
      ds.add(ghiChu);
    }
    await _luuTatCa(ds);

    // Đồng bộ lại lịch nhắc hẹn: hủy lịch cũ trước (phòng trường hợp sửa giờ
    // hẹn), rồi đặt lại lịch mới nếu có hẹn giờ và chưa đánh dấu xong.
    await ReminderNotificationService.huyLich(_bùTruId + ghiChu.id);
    if (ghiChu.thoiGianNhac != null && !ghiChu.daXong) {
      await ReminderNotificationService.datLich(
        messageId: _bùTruId + ghiChu.id,
        tieuDe: ghiChu.tieuDe,
        moTa: ghiChu.noiDung.isNotEmpty ? ghiChu.noiDung : null,
        thoiGianNhac: ghiChu.thoiGianNhac!,
      );
    }
  }

  static Future<void> xoa(int id) async {
    final ds = await layDanhSach();
    ds.removeWhere((e) => e.id == id);
    await _luuTatCa(ds);
    await ReminderNotificationService.huyLich(_bùTruId + id);
  }

  static Future<void> danhDauXong(int id, bool xong) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((e) => e.id == id);
    if (viTri < 0) return;
    ds[viTri].daXong = xong;
    await _luuTatCa(ds);
    // Đánh dấu xong -> hủy luôn thông báo nhắc hẹn (không cần nhắc việc đã xong)
    if (xong) await ReminderNotificationService.huyLich(_bùTruId + id);
  }
}
