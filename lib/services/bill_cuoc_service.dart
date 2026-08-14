import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/bill_cuoc_khach_hang.dart';
import 'auth_service.dart';

class BillCuocService {
  static Future<List<BillCuocKy>> layDanhSachKy() async {
    final token = await AuthService.getToken();
    if (token == null) return [];
    try {
      final res = await http
          .get(Uri.parse(AppConfig.apiBillCuocDanhSachKy), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return (data['data'] as List).map((e) => BillCuocKy.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Trả về (danh sách khách hàng, danh sách CNKD, trang hiện tại, tổng số
  /// trang, thông báo lỗi nếu có). TRƯỚC ĐÂY lỗi API bị "nuốt" âm thầm,
  /// hiện ra như "không tìm thấy khách hàng" - GÂY HIỂU NHẦM (lỗi thật đã
  /// gặp) - giờ trả về đúng thông báo lỗi để hiện rõ cho người dùng.
  static Future<({List<BillCuocKhachHang> khachHang, List<BillCuocTvv> tvv, int trang, int tongSoTrang, String? loi})> timKhachHang({
    required int kyId,
    String? tvv,
    String? tuKhoa,
    bool? daThu,
    int trang = 1,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[], trang: 1, tongSoTrang: 1, loi: 'Chưa đăng nhập.');
    try {
      final thamSo = <String, String>{'ky_id': '$kyId', 'trang': '$trang'};
      if (tvv != null && tvv.isNotEmpty) thamSo['tvv'] = tvv;
      if (tuKhoa != null && tuKhoa.isNotEmpty) thamSo['q'] = tuKhoa;
      if (daThu != null) thamSo['da_thu'] = daThu ? '1' : '0';

      final uri = Uri.parse(AppConfig.apiBillCuocDanhSachKhachHang).replace(queryParameters: thamSo);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        // Server có thể trả JSON lỗi rõ ràng (VD "Bạn chưa được cấp quyền...")
        // - ưu tiên đọc đúng thông báo đó; nếu không phải JSON (VD lỗi PHP
        // 500 thật) thì mới hiện thông báo chung chung kèm mã lỗi.
        try {
          final data = jsonDecode(res.body);
          if (data['message'] != null) {
            return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[], trang: 1, tongSoTrang: 1, loi: data['message'].toString());
          }
        } catch (_) {}
        return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[], trang: 1, tongSoTrang: 1,
            loi: 'Máy chủ báo lỗi (mã ${res.statusCode}) - có thể module chưa cập nhật đủ trên server, báo lại cho người quản trị.');
      }
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        final khachHang = (data['data'] as List).map((e) => BillCuocKhachHang.fromJson(e)).toList();
        final dsTvv = (data['ds_tvv'] as List).map((e) => BillCuocTvv.fromJson(e)).toList();
        return (
          khachHang: khachHang, tvv: dsTvv,
          trang: (data['trang'] as num?)?.toInt() ?? 1,
          tongSoTrang: (data['tong_so_trang'] as num?)?.toInt() ?? 1,
          loi: null,
        );
      }
      return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[], trang: 1, tongSoTrang: 1, loi: data['message']?.toString());
    } catch (e) {
      return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[], trang: 1, tongSoTrang: 1, loi: 'Lỗi kết nối: $e');
    }
  }

  /// Ghi lại 1 lần in nhiệt thành công - để hiện "Đã in nhiệt x N" đồng bộ
  /// với bản web, tránh CNKD in trùng nhầm.
  static Future<void> ghiLogInNhiet(int khId) async {
    final token = await AuthService.getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse(AppConfig.apiBillCuocGhiLogInNhiet),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'kh_id=$khId',
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Sửa số điện thoại/địa chỉ khách hàng - CHỈ 2 trường này (xem giải
  /// thích lý do trong file PHP tương ứng) - server tự ghi lịch sử ai sửa
  /// gì, khi nào để sau này Admin xuất Excel đối chiếu.
  static Future<String?> suaThongTinKhachHang({
    required int khId,
    required String soDtLienHe,
    required String diaChiTbc,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return 'Chưa đăng nhập.';
    try {
      final res = await http.post(
        Uri.parse(AppConfig.apiBillCuocSuaThongTin),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'kh_id=$khId&so_dt_lien_he=${Uri.encodeComponent(soDtLienHe)}&dia_chi_tbc=${Uri.encodeComponent(diaChiTbc)}',
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null;
      return data['message']?.toString() ?? 'Lưu thất bại (mã ${res.statusCode}).';
    } catch (e) {
      return 'Lỗi kết nối: $e';
    }
  }

  /// Mở trang IN (Thông báo cước / Thông báo nợ) trên TRÌNH DUYỆT NGOÀI của
  /// máy (Chrome thật, KHÔNG phải WebView trong app) - trả về URL đầy đủ kèm
  /// vé đăng nhập 1 lần, để trình duyệt ngoài tự đăng nhập rồi mở đúng trang
  /// in với đúng danh sách khách hàng đã chọn. Dùng trình duyệt ngoài (không
  /// phải WebView) vì: (1) tránh đúng loại lỗi WebView hay gặp, (2) trình
  /// duyệt ngoài mới hỗ trợ Web Bluetooth cho tính năng in nhiệt sau này.
  static Future<String?> taoLinkInNgoai({
    required String hanhDong, // 'in_bill' hoặc 'in_thongbao'
    required int kyId,
    required List<int> khIds,
    String? xuat, // 'pdf' hoặc 'jpg' - TỰ ĐỘNG kích hoạt đúng chức năng đó
    // ngay khi trang mở ra, không bắt CNKD phải tự tìm nút trên trang web.
  }) async {
    final ticket = await AuthService.getWebTicket();
    if (ticket == null) return null;
    var duongDanDich = '/bill-cuoc.php?action=$hanhDong&ky_id=$kyId&kh_ids=${khIds.join(",")}';
    if (xuat != null) duongDanDich += '&xuat=$xuat';
    return '${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(duongDanDich)}';
  }
}
