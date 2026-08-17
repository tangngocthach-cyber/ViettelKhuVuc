import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/khao_sat.dart';
import 'auth_service.dart';

class KhaoSatService {
  /// Danh sách đợt khảo sát đang mở - trả kèm thông báo lỗi rõ ràng thay vì
  /// âm thầm trả về danh sách rỗng khi có sự cố (bài học thật từ module Bill
  /// cước - lỗi bị "nuốt" gây hiểu nhầm).
  static Future<({List<KhaoSatDot> ds, String? loi})> layDanhSachDot() async {
    final token = await AuthService.getToken();
    if (token == null) return (ds: <KhaoSatDot>[], loi: 'Chưa đăng nhập.');
    try {
      final res = await http
          .get(Uri.parse(AppConfig.apiKhaoSatDanhSachDot), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return (ds: (data['data'] as List).map((e) => KhaoSatDot.fromJson(e)).toList(), loi: null);
      }
      return (ds: <KhaoSatDot>[], loi: data['message']?.toString() ?? 'Lỗi tải danh sách (mã ${res.statusCode}).');
    } catch (e) {
      return (ds: <KhaoSatDot>[], loi: 'Lỗi kết nối: $e');
    }
  }

  /// Chi tiết 1 đợt khảo sát: danh sách khách hàng + trường tùy chỉnh + lý do mẫu.
  static Future<({KhaoSatDot? dot, List<KhaoSatKhachHang> khachHang, List<KhaoSatTruongTin> truongTin, List<KhaoSatLyDo> lyDo, String? loi})> layChiTietDot(int dotId) async {
    final token = await AuthService.getToken();
    if (token == null) {
      return (dot: null, khachHang: <KhaoSatKhachHang>[], truongTin: <KhaoSatTruongTin>[], lyDo: <KhaoSatLyDo>[], loi: 'Chưa đăng nhập.');
    }
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.apiKhaoSatChiTietDot}?dot_id=$dotId'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return (
          dot: KhaoSatDot.fromJson({...data['dot'], 'so_khach': 0, 'so_da_khao_sat': 0}),
          khachHang: (data['khach_hang'] as List).map((e) => KhaoSatKhachHang.fromJson(e)).toList(),
          truongTin: (data['truong_tin'] as List).map((e) => KhaoSatTruongTin.fromJson(e)).toList(),
          lyDo: (data['ly_do'] as List).map((e) => KhaoSatLyDo.fromJson(e)).toList(),
          loi: null,
        );
      }
      return (dot: null, khachHang: <KhaoSatKhachHang>[], truongTin: <KhaoSatTruongTin>[], lyDo: <KhaoSatLyDo>[], loi: data['message']?.toString() ?? 'Lỗi tải dữ liệu (mã ${res.statusCode}).');
    } catch (e) {
      return (dot: null, khachHang: <KhaoSatKhachHang>[], truongTin: <KhaoSatTruongTin>[], lyDo: <KhaoSatLyDo>[], loi: 'Lỗi kết nối: $e');
    }
  }

  /// Lưu/cập nhật kết quả khảo sát 1 khách hàng - `duLieuTuyChinh` (nếu có)
  /// được TỰ ĐÓNG GÓI JSON ngay trong hàm này trước khi gửi lên (server lưu
  /// nguyên chuỗi vào cột TEXT, không tự parse từng field riêng lẻ từ form-data).
  static Future<String?> luuKetQua({
    required int dotId,
    required int khachHangId,
    int? lyDoId,
    required String moTaChiTiet,
    required Map<String, String> duLieuTuyChinh,
  }) async {
    final token = await AuthService.getToken();
    if (token == null) return 'Chưa đăng nhập.';
    try {
      final body = <String, String>{
        'dot_id': '$dotId',
        'khach_hang_id': '$khachHangId',
        'mo_ta_chi_tiet': moTaChiTiet,
        'du_lieu_truong_tuy_chinh': jsonEncode(duLieuTuyChinh),
      };
      if (lyDoId != null) body['ly_do_id'] = '$lyDoId';
      final res = await http
          .post(Uri.parse(AppConfig.apiKhaoSatLuuKetQua), headers: {'Authorization': 'Bearer $token'}, body: body)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return null;
      return data['message']?.toString() ?? 'Lưu thất bại (mã ${res.statusCode}).';
    } catch (e) {
      return 'Lỗi kết nối: $e';
    }
  }
}
