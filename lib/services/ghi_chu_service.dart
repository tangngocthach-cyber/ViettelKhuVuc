import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../models/ghi_chu.dart';
import 'reminder_notification_service.dart';

// LoaiGhiChu đã có sẵn trong ghi_chu.dart (cùng import ở trên), dùng để lấy
// tên hiển thị của từng loại ghi chú khi xuất CSV.

/// Quản lý Sổ ghi chú - lưu HOÀN TOÀN OFFLINE trên máy (file JSON), không
/// cần server/mạng. Tự động đặt/hủy lịch nhắc hẹn khi thêm/sửa/xóa ghi chú
/// có hẹn giờ, dùng chung ReminderNotificationService đã có sẵn cho Chat.
class GhiChuService {
  // Cộng thêm 900 triệu vào ID thông báo để KHÔNG trùng với ID nhắc hẹn của
  // Chat (vốn dùng messageId thật từ CSDL, chắc chắn nhỏ hơn nhiều con số này).
  static const _buTruId = 900000000;

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
    await ReminderNotificationService.huyLich(_buTruId + ghiChu.id);
    if (ghiChu.thoiGianNhac != null && !ghiChu.daXong) {
      await ReminderNotificationService.datLich(
        messageId: _buTruId + ghiChu.id,
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
    await ReminderNotificationService.huyLich(_buTruId + id);
  }

  static Future<void> danhDauXong(int id, bool xong) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((e) => e.id == id);
    if (viTri < 0) return;
    ds[viTri].daXong = xong;
    await _luuTatCa(ds);
    // Đánh dấu xong -> hủy luôn thông báo nhắc hẹn (không cần nhắc việc đã xong)
    if (xong) await ReminderNotificationService.huyLich(_buTruId + id);
  }

  // ============================================================================
  // SAO LƯU / KHÔI PHỤC - phòng trường hợp mất dữ liệu (đổi máy, gỡ cài app,
  // hỏng máy...). Ghi chú lưu HOÀN TOÀN TRÊN MÁY (không đồng bộ server), nên
  // rất cần tính năng này để không mất trắng khi có sự cố.
  // ============================================================================

  /// Xuất TOÀN BỘ ghi chú ra 1 file JSON (giữ nguyên dữ liệu gốc, khôi phục
  /// lại chính xác 100%) - trả về đường dẫn file để chia sẻ (Zalo/Email/Drive...).
  static Future<File> xuatBackup() async {
    final ds = await layDanhSach();
    final dir = await getTemporaryDirectory();
    final tenFile = 'sao-luu-ghi-chu-${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$tenFile');
    await file.writeAsString(jsonEncode(ds.map((e) => e.toJson()).toList()));
    return file;
  }

  /// Đọc 1 file JSON đã sao lưu trước đó và NHẬP LẠI vào Sổ ghi chú. Cách làm
  /// AN TOÀN: chỉ THÊM MỚI hoặc CẬP NHẬT theo ID (không tự xóa ghi chú hiện
  /// có nào không nằm trong file sao lưu) - tránh mất dữ liệu ngoài ý muốn.
  /// Trả về số lượng ghi chú đã khôi phục thành công.
  static Future<int> khoiPhucTuFile(File file) async {
    final noiDung = await file.readAsString();
    final danhSachTho = jsonDecode(noiDung) as List;
    final dsHienCo = await layDanhSach();

    var soLuongKhoiPhuc = 0;
    for (final tho in danhSachTho) {
      try {
        final gc = GhiChu.fromJson(tho);
        final viTri = dsHienCo.indexWhere((e) => e.id == gc.id);
        if (viTri >= 0) {
          dsHienCo[viTri] = gc;
        } else {
          dsHienCo.add(gc);
        }
        soLuongKhoiPhuc++;
      } catch (e) {
        // 1 dòng lỗi định dạng thì bỏ qua, không làm hỏng cả quá trình khôi phục
      }
    }
    await _luuTatCa(dsHienCo);

    // Đặt lại lịch nhắc hẹn cho các ghi chú vừa khôi phục có hẹn giờ
    for (final gc in dsHienCo) {
      if (gc.thoiGianNhac != null && !gc.daXong) {
        await ReminderNotificationService.datLich(
          messageId: _buTruId + gc.id,
          tieuDe: gc.tieuDe,
          moTa: gc.noiDung.isNotEmpty ? gc.noiDung : null,
          thoiGianNhac: gc.thoiGianNhac!,
        );
      }
    }
    return soLuongKhoiPhuc;
  }

  /// Xuất ghi chú ra file Excel THẬT (.xlsx) - Excel/Google Sheets/WPS Office
  /// đều mở trực tiếp được, đúng định dạng bảng tính chuẩn (không phải CSV).
  static Future<File> xuatXlsx() async {
    final ds = await layDanhSach();
    final dinhDangGio = (DateTime? dt) => dt == null ? '' : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final book = excel_lib.Excel.createExcel();
    const tenTrang = 'Ghi chú';
    final trang = book[tenTrang];
    // Excel.createExcel() tự tạo sẵn 1 "Sheet1" thừa - xóa đi, chỉ giữ đúng
    // 1 trang tên "Ghi chú" cho gọn gàng, dễ nhìn.
    if (book.sheets.containsKey('Sheet1')) book.delete('Sheet1');

    trang.appendRow([
      excel_lib.TextCellValue('Tiêu đề'),
      excel_lib.TextCellValue('Nội dung'),
      excel_lib.TextCellValue('Loại'),
      excel_lib.TextCellValue('Thời gian nhắc'),
      excel_lib.TextCellValue('Trạng thái'),
      excel_lib.TextCellValue('Ngày tạo'),
    ]);

    for (final gc in ds) {
      trang.appendRow([
        excel_lib.TextCellValue(gc.tieuDe),
        excel_lib.TextCellValue(gc.noiDung),
        excel_lib.TextCellValue(LoaiGhiChu.tuMa(gc.loai).ten),
        excel_lib.TextCellValue(dinhDangGio(gc.thoiGianNhac)),
        excel_lib.TextCellValue(gc.daXong ? 'Đã xong' : 'Chưa xong'),
        excel_lib.TextCellValue(dinhDangGio(gc.ngayTao)),
      ]);
    }

    // Nới rộng cột Tiêu đề/Nội dung cho dễ đọc thay vì để mặc định quá hẹp
    trang.setColumnWidth(0, 28);
    trang.setColumnWidth(1, 40);

    final duLieu = book.encode();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ghi-chu-${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(duLieu!);
    return file;
  }
}
