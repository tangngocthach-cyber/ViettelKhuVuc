import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Quản lý phiên đăng nhập: lưu/đọc/xóa token, thông tin user hiện tại.
/// Dùng SharedPreferences (lưu cục bộ trên máy, không đồng bộ đám mây) -
/// đủ an toàn cho token vì app không root mới đọc được dữ liệu app khác.
class AuthService {
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserPhone = 'user_phone';

  /// Đăng nhập - gọi ĐÚNG API dùng chung tài khoản web, KHÔNG tự tạo tài khoản
  /// riêng cho app. Trả về null nếu thành công, hoặc chuỗi lỗi để hiển thị.
  static Future<String?> login(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse(AppConfig.apiLogin),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password, 'device_info': 'Flutter Android'}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, data['token']);
        await prefs.setInt(_keyUserId, data['user']['id']);
        await prefs.setString(_keyUserName, data['user']['name'] ?? '');
        await prefs.setString(_keyUserEmail, data['user']['email'] ?? '');
        await prefs.setString(_keyUserPhone, data['user']['phone'] ?? '');
        return null;
      }
      return data['message'] ?? 'Đăng nhập thất bại, vui lòng thử lại.';
    } catch (e) {
      return 'Không thể kết nối máy chủ. Kiểm tra lại mạng Internet.';
    }
  }

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http.post(Uri.parse(AppConfig.apiLogout), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 8));
      } catch (_) {
        // Lỗi mạng khi đăng xuất không quan trọng - vẫn xóa token cục bộ để đăng xuất trên máy
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  static Future<Map<String, String>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id': (prefs.getInt(_keyUserId) ?? 0).toString(),
      'name': prefs.getString(_keyUserName) ?? '',
      'email': prefs.getString(_keyUserEmail) ?? '',
      'phone': prefs.getString(_keyUserPhone) ?? '',
    };
  }

  /// Kiểm tra token còn hiệu lực trên server hay không (gọi khi mở app) -
  /// nếu server báo hết hạn, TỰ ĐỘNG xóa token cục bộ để chuyển về màn Đăng nhập.
  static Future<bool> validateSession() async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final res = await http.get(Uri.parse(AppConfig.apiMe), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 401) {
        await logout();
        return false;
      }
      return res.statusCode == 200;
    } catch (e) {
      // Lỗi mạng: KHÔNG đăng xuất (tránh mất phiên chỉ vì mất mạng tạm thời) -
      // coi như vẫn còn đăng nhập, app dùng dữ liệu cache offline.
      return true;
    }
  }
}
