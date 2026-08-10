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

  /// Trả về (danh sách khách hàng, danh sách CNKD trong kỳ đó).
  static Future<({List<BillCuocKhachHang> khachHang, List<BillCuocTvv> tvv})> timKhachHang({
    required int kyId,
    String? tvv,
    String? tuKhoa,
    bool? daThu,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[]);
    try {
      final thamSo = <String, String>{'ky_id': '$kyId'};
      if (tvv != null && tvv.isNotEmpty) thamSo['tvv'] = tvv;
      if (tuKhoa != null && tuKhoa.isNotEmpty) thamSo['q'] = tuKhoa;
      if (daThu != null) thamSo['da_thu'] = daThu ? '1' : '0';

      final uri = Uri.parse(AppConfig.apiBillCuocDanhSachKhachHang).replace(queryParameters: thamSo);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final khachHang = (data['data'] as List).map((e) => BillCuocKhachHang.fromJson(e)).toList();
        final dsTvv = (data['ds_tvv'] as List).map((e) => BillCuocTvv.fromJson(e)).toList();
        return (khachHang: khachHang, tvv: dsTvv);
      }
    } catch (_) {}
    return (khachHang: <BillCuocKhachHang>[], tvv: <BillCuocTvv>[]);
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
  }) async {
    final ticket = await AuthService.getWebTicket();
    if (ticket == null) return null;
    final duongDanDich = '/bill-cuoc.php?action=$hanhDong&ky_id=$kyId&kh_ids=${khIds.join(",")}';
    return '${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(duongDanDich)}';
  }
}
