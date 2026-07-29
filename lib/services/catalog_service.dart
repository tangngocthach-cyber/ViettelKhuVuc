import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import 'auth_service.dart';

/// Đồng bộ danh mục (Sản phẩm/Tin tức/Chính sách) từ website thật về máy, có
/// cache offline (lưu file JSON trong bộ nhớ app) - KHÔNG tạo dữ liệu giả,
/// chỉ đọc và lưu lại đúng dữ liệu server trả về.
class CatalogService {
  /// Đồng bộ 1 loại danh mục ('products' | 'news' | 'policies'). Trả về danh
  /// sách MỚI NHẤT (đã gộp với cache cũ) - dùng cho pull-to-refresh và mở app.
  static Future<List<dynamic>> sync(String loai) async {
    final url = _apiUrlTheoLoai(loai);
    final cacheFile = await _fileCache(loai);
    final metaFile = await _fileMeta(loai);

    List<dynamic> danhSachCu = [];
    String sinceThoiDiem = '';
    if (await cacheFile.exists()) {
      try {
        danhSachCu = jsonDecode(await cacheFile.readAsString());
      } catch (_) {
        danhSachCu = [];
      }
    }
    if (await metaFile.exists()) {
      try {
        sinceThoiDiem = jsonDecode(await metaFile.readAsString())['server_time'] ?? '';
      } catch (_) {}
    }

    try {
      final token = await AuthService.getToken();
      if (token == null) return danhSachCu; // chưa đăng nhập - chỉ trả cache (nếu có)

      final uri = Uri.parse(sinceThoiDiem.isEmpty ? url : '$url?since=${Uri.encodeComponent(sinceThoiDiem)}');
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode != 200 || data['success'] != true) return danhSachCu;

      final List<dynamic> moi = data['data'];
      // Gộp: dữ liệu MỚI ghi đè lên dữ liệu CŨ theo 'id' (đồng bộ delta không mất dữ liệu cũ)
      final Map<dynamic, dynamic> gop = {for (var item in danhSachCu) item['id']: item};
      for (var item in moi) {
        gop[item['id']] = item;
      }
      final ketQua = gop.values.toList();

      await cacheFile.writeAsString(jsonEncode(ketQua));
      await metaFile.writeAsString(jsonEncode({'server_time': data['server_time']}));
      return ketQua;
    } catch (e) {
      // Mất mạng / lỗi server: trả về cache cũ, KHÔNG để app trắng màn hình
      return danhSachCu;
    }
  }

  /// Lấy dữ liệu cache NGAY (không gọi mạng) - dùng để hiển thị tức thì khi mở
  /// màn hình, trong lúc sync() chạy nền phía sau rồi cập nhật lại UI.
  static Future<List<dynamic>> getCached(String loai) async {
    final cacheFile = await _fileCache(loai);
    if (!await cacheFile.exists()) return [];
    try {
      return jsonDecode(await cacheFile.readAsString());
    } catch (_) {
      return [];
    }
  }

  static String _apiUrlTheoLoai(String loai) {
    switch (loai) {
      case 'news':
        return AppConfig.apiNews;
      case 'policies':
        return AppConfig.apiPolicies;
      default:
        return AppConfig.apiProducts;
    }
  }

  static Future<File> _fileCache(String loai) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cache_$loai.json');
  }

  static Future<File> _fileMeta(String loai) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cache_${loai}_meta.json');
  }
}
