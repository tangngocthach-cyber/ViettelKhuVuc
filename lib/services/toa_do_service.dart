import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/khach_hang_toa_do.dart';
import '../models/bill_cuoc_khach_hang.dart' show BillCuocTvv;
import 'auth_service.dart';

class ToaDoService {
  static Future<({List<KhachHangToaDo> khachHang, List<BillCuocTvv> tvv, String? loi})> layDanhSach({
    required int kyId,
    String? tvv,
    String? tuKhoa,
    bool chuaCoToaDo = false,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return (khachHang: <KhachHangToaDo>[], tvv: <BillCuocTvv>[], loi: 'Chưa đăng nhập.');
    try {
      final thamSo = <String, String>{'ky_id': '$kyId'};
      if (tvv != null && tvv.isNotEmpty) thamSo['tvv'] = tvv;
      if (tuKhoa != null && tuKhoa.isNotEmpty) thamSo['q'] = tuKhoa;
      if (chuaCoToaDo) thamSo['chua_co_toa_do'] = '1';

      final uri = Uri.parse(AppConfig.apiToaDoDanhSach).replace(queryParameters: thamSo);
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final ds = (data['data'] as List).map((e) => KhachHangToaDo.fromJson(e)).toList();
        final dsTvv = (data['ds_tvv'] as List? ?? []).map((e) => BillCuocTvv.fromJson(e)).toList();
        return (khachHang: ds, tvv: dsTvv, loi: null);
      }
      return (khachHang: <KhachHangToaDo>[], tvv: <BillCuocTvv>[], loi: data['message']?.toString() ?? 'Không tải được danh sách.');
    } catch (e) {
      return (khachHang: <KhachHangToaDo>[], tvv: <BillCuocTvv>[], loi: 'Lỗi kết nối: $e');
    }
  }

  /// Lưu tọa độ 1 khách hàng - `nguon` mặc định 'gps_thuc_te' vì hàm này chủ
  /// yếu dùng khi CNKD đứng tại nhà khách bấm "Lấy vị trí hiện tại".
  static Future<String?> luuToaDo({
    required String soTb,
    required double lat,
    required double lng,
    String nguon = 'gps_thuc_te',
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return 'Chưa đăng nhập.';
    try {
      final res = await http.post(
        Uri.parse(AppConfig.apiToaDoCapNhat),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'so_tb=${Uri.encodeComponent(soTb)}&lat=$lat&lng=$lng&nguon=$nguon',
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null; // null = không có lỗi
      return data['message']?.toString() ?? 'Lưu thất bại (mã ${res.statusCode}).';
    } catch (e) {
      return 'Lỗi kết nối: $e';
    }
  }
}
