import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Tính ID thông báo AN TOÀN từ ID ghi chú (mili-giây, 13 chữ số) - BẮT
  /// BUỘC phải rút gọn bằng phép chia dư (%) trước khi cộng, nếu không sẽ
  /// TRÀN SỐ nguyên 32-bit mà Android dùng cho ID thông báo (tối đa khoảng
  /// 2,1 tỷ), làm hỏng/lỗi lịch nhắc hẹn một cách âm thầm, khó phát hiện.
  static int _idThongBao(int ghiChuId) => _buTruId + (ghiChuId % 1000000000);

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
      // nhất). Ghi chú KHÔNG có hẹn giờ thì ưu tiên theo MỨC ĐỘ QUAN TRỌNG
      // (Cao > Trung bình > Thấp) thay vì chỉ theo ngày tạo - việc quan
      // trọng không nên bị chìm xuống dưới chỉ vì tạo trước đó lâu rồi. Ghi
      // chú đã xong luôn xuống cuối cùng.
      ds.sort((a, b) {
        if (a.daXong != b.daXong) return a.daXong ? 1 : -1;
        if (a.thoiGianNhac != null && b.thoiGianNhac != null) return a.thoiGianNhac!.compareTo(b.thoiGianNhac!);
        if (a.thoiGianNhac != null) return -1;
        if (b.thoiGianNhac != null) return 1;
        if (a.mucDoUuTien != b.mucDoUuTien) return b.mucDoUuTien.compareTo(a.mucDoUuTien);
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
    // ĐÃ LƯU XONG dữ liệu ghi chú tới đây - từ đây trở đi CHỈ còn bước phụ là
    // đặt lịch nhắc hẹn. TUYỆT ĐỐI không được để lỗi ở bước phụ này làm người
    // dùng tưởng "lưu thất bại" (lỗi thật đã gặp: lỗi đặt lịch nhắc hẹn khiến
    // hiện "Lưu thất bại" dù ghi chú đã lưu xong, khiến người dùng bấm Lưu lại
    // nhiều lần, tạo ra các bản ghi trùng lặp).
    try {
      // Đồng bộ lại lịch nhắc hẹn: hủy lịch cũ trước (phòng trường hợp sửa giờ
      // hẹn), rồi đặt lại lịch mới nếu có hẹn giờ và chưa đánh dấu xong.
      await ReminderNotificationService.huyLich(_idThongBao(ghiChu.id));
      if (ghiChu.thoiGianNhac != null && !ghiChu.daXong) {
        await ReminderNotificationService.datLich(
          messageId: _idThongBao(ghiChu.id),
          tieuDe: ghiChu.tieuDe,
          moTa: ghiChu.noiDung.isNotEmpty ? ghiChu.noiDung : null,
          thoiGianNhac: ghiChu.thoiGianNhac!,
        );
      }
    } catch (e) {
      // Lỗi đặt lịch nhắc hẹn - ghi chú VẪN ĐÃ LƯU THÀNH CÔNG, chỉ là có thể
      // không nhận được thông báo đúng giờ. Không ném lỗi ra ngoài.
    }
  }

  static Future<void> xoa(int id) async {
    final ds = await layDanhSach();
    ds.removeWhere((e) => e.id == id);
    await _luuTatCa(ds);
    try {
      await ReminderNotificationService.huyLich(_idThongBao(id));
    } catch (e) {
      // Lỗi hủy thông báo không được chặn việc xóa ghi chú (đã xóa xong ở trên rồi)
    }
  }

  /// GIA HẠN - dời lịch nhắc hẹn sang thời điểm MỚI (khách hẹn lại, chưa đóng
  /// tiền, cần dời lịch...) - vẫn giữ nguyên "chưa xong", chỉ đổi giờ nhắc.
  static Future<void> giaHan(int id, DateTime thoiGianMoi) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((e) => e.id == id);
    if (viTri < 0) return;
    ds[viTri].thoiGianNhac = thoiGianMoi;
    ds[viTri].daXong = false;
    await _luuTatCa(ds);
    try {
      await ReminderNotificationService.huyLich(_idThongBao(id));
      await ReminderNotificationService.datLich(
        messageId: _idThongBao(id),
        tieuDe: ds[viTri].tieuDe,
        moTa: ds[viTri].noiDung.isNotEmpty ? ds[viTri].noiDung : null,
        thoiGianNhac: thoiGianMoi,
      );
    } catch (e) {
      // Lỗi đặt lại lịch - ngày giờ mới VẪN ĐÃ LƯU, chỉ là có thể không có thông báo đúng giờ
    }
  }

  /// THU XONG KỲ NÀY, HẸN LẠI KỲ SAU - dành riêng cho ghi chú có bật "Lặp lại"
  /// (VD khách đóng cước trước 6 tháng/1 năm). Tự động tính ngày hẹn KỲ TIẾP
  /// THEO (= ngày hẹn hiện tại + chu kỳ) dựa trên NGÀY HẸN GỐC (không phải
  /// ngày bấm nút) - để chu kỳ luôn đúng đặn, không bị trôi ngày dần nếu có
  /// lúc thu trễ vài hôm so với hẹn.
  static Future<void> giaHanTheoChuKy(int id) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((e) => e.id == id);
    if (viTri < 0) return;
    final gc = ds[viTri];
    if (!gc.coLapLai || gc.thoiGianNhac == null) return;

    final ngayKyToi = GhiChu.congThang(gc.thoiGianNhac!, gc.chuKyLapLaiThang!);
    ds[viTri].thoiGianNhac = ngayKyToi;
    ds[viTri].soLanDaGiaHan = gc.soLanDaGiaHan + 1;
    ds[viTri].daXong = false;
    await _luuTatCa(ds);
    try {
      await ReminderNotificationService.huyLich(_idThongBao(id));
      await ReminderNotificationService.datLich(
        messageId: _idThongBao(id),
        tieuDe: ds[viTri].tieuDe,
        moTa: ds[viTri].noiDung.isNotEmpty ? ds[viTri].noiDung : null,
        thoiGianNhac: ngayKyToi,
      );
    } catch (e) {
      // Lỗi đặt lại lịch - kỳ hạn mới VẪN ĐÃ LƯU, chỉ là có thể không có thông báo đúng giờ
    }
  }

  static Future<void> danhDauXong(int id, bool xong) async {
    final ds = await layDanhSach();
    final viTri = ds.indexWhere((e) => e.id == id);
    if (viTri < 0) return;
    ds[viTri].daXong = xong;
    await _luuTatCa(ds);
    // Đánh dấu xong -> hủy luôn thông báo nhắc hẹn (không cần nhắc việc đã xong)
    if (xong) {
      try {
        await ReminderNotificationService.huyLich(_idThongBao(id));
      } catch (e) {
        // Lỗi hủy thông báo không được chặn việc đánh dấu xong (đã lưu xong ở trên rồi)
      }
    }
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
    await _donDepFileTam(dir, 'sao-luu-ghi-chu-'); // dọn các bản sao lưu cũ trong bộ nhớ tạm trước khi tạo bản mới
    final tenFile = 'sao-luu-ghi-chu-${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$tenFile');
    await file.writeAsString(jsonEncode(ds.map((e) => e.toJson()).toList()));
    await _luuThoiGianSaoLuuCuoi();
    return file;
  }

  static const _khoaLanSaoLuuCuoi = 'ghi_chu_lan_sao_luu_cuoi';

  static Future<void> _luuThoiGianSaoLuuCuoi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_khoaLanSaoLuuCuoi, DateTime.now().toIso8601String());
    } catch (e) {
      // Lưu thất bại thì thôi, không quan trọng bằng việc sao lưu đã xong
    }
  }

  /// Lấy thời điểm sao lưu gần nhất - dùng để nhắc người dùng nếu đã lâu
  /// chưa sao lưu (dữ liệu chỉ nằm trên máy, mất máy là mất trắng).
  static Future<DateTime?> layLanSaoLuuCuoi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final luu = prefs.getString(_khoaLanSaoLuuCuoi);
      return luu != null ? DateTime.tryParse(luu) : null;
    } catch (e) {
      return null;
    }
  }

  /// Xóa các file tạm CŨ (sao lưu/xuất Excel của những lần trước) trong bộ
  /// nhớ đệm - nếu không dọn, file tích tụ dần theo thời gian sử dụng, chiếm
  /// dung lượng máy vô ích (lỗi vặt phát hiện khi rà soát lại code).
  static Future<void> _donDepFileTam(Directory dir, String tienTo) async {
    try {
      final ds = dir.listSync();
      for (final f in ds) {
        if (f is File && f.path.split('/').last.startsWith(tienTo)) {
          try {
            await f.delete();
          } catch (e) {
            // 1 file xóa lỗi (đang được hệ thống dùng dở) thì bỏ qua, không quan trọng
          }
        }
      }
    } catch (e) {
      // Lỗi liệt kê thư mục - bỏ qua, không ảnh hưởng tới việc tạo file mới
    }
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

    // Đặt lại lịch nhắc hẹn cho các ghi chú vừa khôi phục có hẹn giờ - bọc
    // try/catch RIÊNG TỪNG GHI CHÚ, 1 lỗi đặt lịch không được làm dừng cả
    // vòng lặp (dữ liệu đã lưu xong ở trên, đây chỉ là bước phụ).
    for (final gc in dsHienCo) {
      if (gc.thoiGianNhac != null && !gc.daXong) {
        try {
          await ReminderNotificationService.datLich(
            messageId: _idThongBao(gc.id),
            tieuDe: gc.tieuDe,
            moTa: gc.noiDung.isNotEmpty ? gc.noiDung : null,
            thoiGianNhac: gc.thoiGianNhac!,
          );
        } catch (e) {
          // Lỗi đặt lịch cho riêng ghi chú này - bỏ qua, tiếp tục với các ghi chú còn lại
        }
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
      excel_lib.TextCellValue('Mức độ ưu tiên'),
      excel_lib.TextCellValue('Số điện thoại'),
      excel_lib.TextCellValue('Thời gian nhắc'),
      excel_lib.TextCellValue('Trạng thái'),
      excel_lib.TextCellValue('Ngày tạo'),
    ]);

    for (final gc in ds) {
      trang.appendRow([
        excel_lib.TextCellValue(gc.tieuDe),
        excel_lib.TextCellValue(gc.noiDung),
        excel_lib.TextCellValue(LoaiGhiChu.tuMa(gc.loai).ten),
        excel_lib.TextCellValue(MucDoUuTien.tuMa(gc.mucDoUuTien).ten),
        excel_lib.TextCellValue(gc.soDienThoai ?? ''),
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
    await _donDepFileTam(dir, 'ghi-chu-'); // dọn các bản Excel cũ trong bộ nhớ tạm trước khi tạo bản mới
    final file = File('${dir.path}/ghi-chu-${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(duLieu!);
    return file;
  }
}
