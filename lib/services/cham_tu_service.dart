import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../config.dart';
import '../models/cham_tu.dart';
import 'auth_service.dart';

class ChamTuService {
  /// Tạo 1 đề xuất Chấm tủ mới - upload ảnh + dữ liệu trong CÙNG 1 request
  /// (multipart/form-data). Trả về null nếu thành công, hoặc chuỗi lý do lỗi.
  static Future<String?> taoDeXuat({
    required String loaiTu,
    required double latitude,
    required double longitude,
    required File anh,
    String ghiChu = '',
    String thietBi = '',
    String? maTuGoc,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';

      final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiChamTuTao));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['loai_tu'] = loaiTu;
      request.fields['latitude'] = '$latitude';
      request.fields['longitude'] = '$longitude';
      request.fields['ghi_chu'] = ghiChu;
      request.fields['thiet_bi'] = thietBi;
      if (maTuGoc != null && maTuGoc.isNotEmpty) request.fields['ma_tu_goc'] = maTuGoc;
      request.files.add(await http.MultipartFile.fromPath('anh', anh.path));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null;
      return data['message'] ?? 'Lưu đề xuất thất bại, vui lòng thử lại.';
    } catch (e) {
      return 'Không thể kết nối máy chủ. Kiểm tra lại mạng Internet.';
    }
  }

  /// Lấy danh sách đề xuất - có thể lọc theo nhiều tiêu chí cùng lúc. Trả về
  /// kèm luôn "có phải Admin không" (server tự xác định, không tin app tự khai).
  static Future<({List<ChamTu> danhSach, bool laAdmin})> layDanhSach({
    String? tuKhoa,
    String? loaiTu,
    String? trangThai,
    DateTime? tuNgay,
    DateTime? denNgay,
    int? customerId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return (danhSach: <ChamTu>[], laAdmin: false);

      final thamSo = <String, String>{};
      if (tuKhoa != null && tuKhoa.isNotEmpty) thamSo['tu_khoa'] = tuKhoa;
      if (loaiTu != null) thamSo['loai_tu'] = loaiTu;
      if (trangThai != null) thamSo['trang_thai'] = trangThai;
      if (tuNgay != null) thamSo['tu_ngay'] = '${tuNgay.year}-${tuNgay.month.toString().padLeft(2, '0')}-${tuNgay.day.toString().padLeft(2, '0')}';
      if (denNgay != null) thamSo['den_ngay'] = '${denNgay.year}-${denNgay.month.toString().padLeft(2, '0')}-${denNgay.day.toString().padLeft(2, '0')}';
      if (customerId != null) thamSo['customer_id'] = '$customerId';

      final uri = Uri.parse(AppConfig.apiChamTuDanhSach).replace(queryParameters: thamSo);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return (danhSach: <ChamTu>[], laAdmin: false);
      final data = jsonDecode(res.body);
      if (data['success'] != true) return (danhSach: <ChamTu>[], laAdmin: false);
      final ds = (data['data'] as List).map((e) => ChamTu.fromJson(e)).toList();
      return (danhSach: ds, laAdmin: data['la_admin'] == true);
    } catch (e) {
      return (danhSach: <ChamTu>[], laAdmin: false);
    }
  }

  /// Sửa 1 đề xuất - ảnh mới KHÔNG bắt buộc (không truyền thì giữ ảnh cũ).
  static Future<String?> suaDeXuat({
    required int id,
    required String loaiTu,
    required double latitude,
    required double longitude,
    File? anhMoi,
    String ghiChu = '',
    String? maTuGoc,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';

      final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiChamTuSua));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['id'] = '$id';
      request.fields['loai_tu'] = loaiTu;
      request.fields['latitude'] = '$latitude';
      request.fields['longitude'] = '$longitude';
      request.fields['ghi_chu'] = ghiChu;
      request.fields['ma_tu_goc'] = maTuGoc ?? '';
      if (anhMoi != null) request.files.add(await http.MultipartFile.fromPath('anh', anhMoi.path));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null;
      return data['message'] ?? 'Sửa đề xuất thất bại, vui lòng thử lại.';
    } catch (e) {
      return 'Không thể kết nối máy chủ. Kiểm tra lại mạng Internet.';
    }
  }

  static Future<String?> xoaDeXuat(int id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return 'Phiên đăng nhập đã hết hạn.';
      final res = await http
          .post(Uri.parse(AppConfig.apiChamTuXoa), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'id': id}))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null;
      return data['message'] ?? 'Xóa thất bại.';
    } catch (e) {
      return 'Không thể kết nối máy chủ.';
    }
  }

  /// Duyệt hoặc từ chối - hanhDong: 'duyet' hoặc 'tu_choi'
  static Future<String?> duyetTuChoi(int id, String hanhDong, {String lyDo = ''}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return 'Phiên đăng nhập đã hết hạn.';
      final res = await http
          .post(
            Uri.parse(AppConfig.apiChamTuDuyet),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'id': id, 'hanh_dong': hanhDong, 'ly_do': lyDo}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null;
      return data['message'] ?? 'Thao tác thất bại.';
    } catch (e) {
      return 'Không thể kết nối máy chủ.';
    }
  }

  /// Lấy lịch sử thao tác (chỉ Admin) - deXuatId = null để xem TOÀN BỘ lịch sử
  static Future<List<Map<String, dynamic>>> layLichSu({int? deXuatId}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];
      final thamSo = deXuatId != null ? {'de_xuat_id': '$deXuatId'} : <String, String>{};
      final uri = Uri.parse(AppConfig.apiChamTuLichSu).replace(queryParameters: thamSo);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return List<Map<String, dynamic>>.from(data['data']);
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Tải file ZIP sao lưu về máy - trả về đường dẫn file đã lưu, hoặc null nếu lỗi.
  static Future<File?> taiBackupVe() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;
      final res = await http.get(Uri.parse(AppConfig.apiChamTuBackup), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sao-luu-cham-tu-${DateTime.now().millisecondsSinceEpoch}.zip');
      await file.writeAsBytes(res.bodyBytes);
      return file;
    } catch (e) {
      return null;
    }
  }

  /// Khôi phục từ file ZIP đã chọn - trả về null nếu thành công kèm số lượng,
  /// hoặc chuỗi lý do lỗi.
  static Future<({bool thanhCong, String thongBao})> khoiPhuc(File fileZip) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return (thanhCong: false, thongBao: 'Phiên đăng nhập đã hết hạn.');
      final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiChamTuRestore));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file_backup', fileZip.path));
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return (thanhCong: true, thongBao: 'Đã khôi phục ${data['so_luong_de_xuat']} đề xuất.');
      }
      return (thanhCong: false, thongBao: (data['message'] ?? 'Khôi phục thất bại.').toString());
    } catch (e) {
      return (thanhCong: false, thongBao: 'File không đúng định dạng hoặc lỗi kết nối.');
    }
  }

  /// Nhập hàng loạt từ dữ liệu Excel đã đọc sẵn (danh sách Map) - trả về
  /// thông báo kết quả.
  static Future<({bool thanhCong, String thongBao})> nhapExcel(List<Map<String, dynamic>> danhSach) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return (thanhCong: false, thongBao: 'Phiên đăng nhập đã hết hạn.');
      final res = await http
          .post(
            Uri.parse(AppConfig.apiChamTuNhapExcel),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'danh_sach': danhSach}),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return (thanhCong: true, thongBao: 'Đã nhập ${data['thanh_cong']} dòng, bỏ qua ${data['bo_qua']} dòng lỗi.');
      }
      return (thanhCong: false, thongBao: (data['message'] ?? 'Nhập dữ liệu thất bại.').toString());
    } catch (e) {
      return (thanhCong: false, thongBao: 'File không đúng định dạng hoặc lỗi kết nối.');
    }
  }

  /// Xuất danh sách ra file Excel (.xlsx) THẬT - đủ cột theo đúng yêu cầu.
  static Future<File> xuatExcel(List<ChamTu> danhSach) async {
    final book = excel_lib.Excel.createExcel();
    const tenTrang = 'Chấm tủ';
    final trang = book[tenTrang];
    if (book.sheets.containsKey('Sheet1')) book.delete('Sheet1');

    trang.appendRow([
      excel_lib.TextCellValue('STT'),
      excel_lib.TextCellValue('ID'),
      excel_lib.TextCellValue('Loại tủ'),
      excel_lib.TextCellValue('Mã tủ gốc'),
      excel_lib.TextCellValue('Latitude'),
      excel_lib.TextCellValue('Longitude'),
      excel_lib.TextCellValue('Link Google Maps'),
      excel_lib.TextCellValue('Địa chỉ'),
      excel_lib.TextCellValue('Người tạo'),
      excel_lib.TextCellValue('Ngày giờ đề xuất'),
      excel_lib.TextCellValue('Đường dẫn ảnh'),
      excel_lib.TextCellValue('Ghi chú'),
      excel_lib.TextCellValue('Trạng thái'),
    ]);

    var stt = 1;
    for (final ct in danhSach) {
      trang.appendRow([
        excel_lib.IntCellValue(stt++),
        excel_lib.IntCellValue(ct.id),
        excel_lib.TextCellValue(LoaiTu.ten(ct.loaiTu)),
        excel_lib.TextCellValue(ct.maTuGoc ?? ''),
        excel_lib.DoubleCellValue(ct.latitude),
        excel_lib.DoubleCellValue(ct.longitude),
        excel_lib.TextCellValue(ct.linkGoogleMaps),
        excel_lib.TextCellValue(ct.diaChi),
        excel_lib.TextCellValue(ct.tenNguoiTao),
        excel_lib.TextCellValue('${ct.ngayTao.day.toString().padLeft(2, '0')}/${ct.ngayTao.month.toString().padLeft(2, '0')}/${ct.ngayTao.year} ${ct.ngayTao.hour.toString().padLeft(2, '0')}:${ct.ngayTao.minute.toString().padLeft(2, '0')}'),
        excel_lib.TextCellValue(ct.anhUrl),
        excel_lib.TextCellValue(ct.ghiChu),
        excel_lib.TextCellValue(TrangThaiChamTu.ten(ct.trangThai)),
      ]);
    }
    trang.setColumnWidth(7, 35);
    trang.setColumnWidth(10, 40);

    final duLieu = book.encode();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cham-tu-${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(duLieu!);
    return file;
  }

  /// Đọc dữ liệu từ file Excel đã chọn - trả về danh sách Map sẵn sàng gửi
  /// lên API nhập hàng loạt. Đọc theo ĐÚNG thứ tự cột đã xuất ở trên.
  static List<Map<String, dynamic>> docFileExcel(List<int> bytes) {
    final ketQua = <Map<String, dynamic>>[];
    try {
      final book = excel_lib.Excel.decodeBytes(bytes);
      final tenTrangDau = book.tables.keys.first;
      final trang = book.tables[tenTrangDau]!;
      // Dòng đầu là tiêu đề cột - bỏ qua, bắt đầu đọc từ dòng thứ 2.
      for (var i = 1; i < trang.maxRows; i++) {
        final dong = trang.row(i);
        if (dong.length < 13) continue;
        String layChuoi(int cot) => dong[cot]?.value?.toString() ?? '';
        ketQua.add({
          'loai_tu': layChuoi(2) == 'Tủ cứng' ? LoaiTu.tuCung : LoaiTu.tu8,
          'ma_tu_goc': layChuoi(3),
          'latitude': double.tryParse(layChuoi(4)),
          'longitude': double.tryParse(layChuoi(5)),
          'dia_chi': layChuoi(7),
          'anh_url': layChuoi(10),
          'ghi_chu': layChuoi(11),
          'trang_thai': layChuoi(12) == 'Đã duyệt' ? 'da_duyet' : (layChuoi(12) == 'Từ chối' ? 'tu_choi' : 'cho_duyet'),
        });
      }
    } catch (e) {
      // Đọc lỗi thì trả về danh sách rỗng - màn hình sẽ tự báo "không đọc được file"
    }
    return ketQua;
  }
}
