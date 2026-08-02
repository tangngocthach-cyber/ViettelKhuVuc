import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

/// Quản lý phiên đăng nhập: lưu/đọc/xóa token, thông tin user hiện tại.
/// Dùng flutter_secure_storage (MÃ HÓA bằng Keystore của máy - Android
/// Keystore/iOS Keychain) - AN TOÀN HƠN SharedPreferences thường (không mã
/// hóa), đặc biệt quan trọng cho token đăng nhập.
class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUserName = 'user_name';
  static const _keyUserEmail = 'user_email';
  static const _keyUserPhone = 'user_phone';
  static const _keyChatAdmin = 'is_chat_admin';
  static const _keyHopCapAccess = 'hop_cap_gpon_access';
  static const _keyChamTuAccess = 'cham_tu_access';
  static const _keyChamTuAdmin = 'cham_tu_admin';
  static const _keyBiometricEnabled = 'sinh_trac_hoc_bat';

  /// Có đang BẬT đăng nhập vân tay/Face ID không - lưu CHUNG storage với token
  /// nên khi đăng xuất (deleteAll ở logout()) sẽ TỰ ĐỘNG tắt luôn, không cần
  /// xử lý riêng - đúng ý nghĩa bảo mật (đăng xuất thì vân tay cũng vô hiệu).
  static Future<bool> isBiometricEnabled() async {
    return (await _storage.read(key: _keyBiometricEnabled)) == 'true';
  }

  static Future<void> setBiometricEnabled(bool bat) async {
    await _storage.write(key: _keyBiometricEnabled, value: '$bat');
  }

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
        await _storage.write(key: _keyToken, value: data['token']);
        await _storage.write(key: _keyUserId, value: '${data['user']['id']}');
        await _storage.write(key: _keyUserName, value: data['user']['name'] ?? '');
        await _storage.write(key: _keyUserEmail, value: data['user']['email'] ?? '');
        await _storage.write(key: _keyUserPhone, value: data['user']['phone'] ?? '');
        // KHÔNG lấy is_chat_admin/hop_cap_gpon_access từ API đăng nhập - API đó
        // có thể chưa trả đủ các trường quyền mới thêm sau này (lỗi thật đã
        // gặp: cấp quyền Bản đồ Hộp cáp trên web xong, đăng nhập lại app vẫn
        // không thấy vì bị API đăng nhập ghi đè về false). Luôn đồng bộ lại
        // NGAY từ api/auth/me.php - nguồn DUY NHẤT đáng tin cậy cho các quyền.
        await _dongBoQuyenTuServer(data['token']);
        return null;
      }
      return data['message'] ?? 'Đăng nhập thất bại, vui lòng thử lại.';
    } catch (e) {
      return 'Không thể kết nối máy chủ. Kiểm tra lại mạng Internet.';
    }
  }

  /// Đồng bộ lại các cờ quyền (Quản trị Chat, Bản đồ Hộp cáp GPON...) từ
  /// api/auth/me.php - dùng chung cho cả login() và validateSession() để chỉ
  /// có DUY NHẤT 1 nguồn sự thật, tránh lệch dữ liệu giữa 2 API khác nhau.
  static Future<void> _dongBoQuyenTuServer(String token) async {
    try {
      final res = await http.get(Uri.parse(AppConfig.apiMe), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          await _storage.write(key: _keyChatAdmin, value: '${data['user']['is_chat_admin'] ?? false}');
          await _storage.write(key: _keyHopCapAccess, value: '${data['user']['hop_cap_gpon_access'] ?? false}');
          await _storage.write(key: _keyChamTuAccess, value: '${data['user']['cham_tu_access'] ?? false}');
          await _storage.write(key: _keyChamTuAdmin, value: '${data['user']['cham_tu_admin'] ?? false}');
        }
      }
    } catch (e) {
      // Lỗi mạng lúc đồng bộ quyền - không quan trọng bằng việc đăng nhập
      // thành công, giữ nguyên giá trị quyền cũ (nếu có) và bỏ qua.
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
    await _storage.deleteAll();
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  static Future<Map<String, String>> getCurrentUser() async {
    return {
      'id': await _storage.read(key: _keyUserId) ?? '0',
      'name': await _storage.read(key: _keyUserName) ?? '',
      'email': await _storage.read(key: _keyUserEmail) ?? '',
      'phone': await _storage.read(key: _keyUserPhone) ?? '',
    };
  }

  static Future<bool> isChatAdmin() async {
    return (await _storage.read(key: _keyChatAdmin)) == 'true';
  }

  /// Có quyền xem "Bản đồ Hộp cáp GPON" không - do Admin cấp riêng cho từng
  /// người, mặc định KHÔNG có quyền cho tới khi được cấp (an toàn hơn).
  static Future<bool> hasHopCapAccess() async {
    return (await _storage.read(key: _keyHopCapAccess)) == 'true';
  }

  /// Có quyền SỬ DỤNG tính năng "Chấm tủ đề xuất" không - do Admin cấp riêng,
  /// mặc định KHÔNG có quyền cho tới khi được cấp (an toàn hơn).
  static Future<bool> hasChamTuAccess() async {
    return (await _storage.read(key: _keyChamTuAccess)) == 'true';
  }

  /// Có phải Admin của module Chấm tủ không (duyệt/từ chối/sửa/xóa của
  /// người khác) - KHÁC hasChamTuAccess() (đó chỉ là quyền dùng cơ bản).
  static Future<bool> isChamTuAdmin() async {
    return (await _storage.read(key: _keyChamTuAdmin)) == 'true';
  }

  /// Kiểm tra token còn hiệu lực trên server hay không (gọi khi mở app) -
  /// nếu server báo hết hạn, TỰ ĐỘNG xóa token cục bộ để chuyển về màn Đăng nhập.
  /// Đồng thời ĐỒNG BỘ LẠI cờ Quản trị Chat mới nhất (phòng khi Admin vừa cấp/gỡ quyền).
  static Future<bool> validateSession() async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final res = await http.get(Uri.parse(AppConfig.apiMe), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 401) {
        await logout();
        return false;
      }
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          await _storage.write(key: _keyChatAdmin, value: '${data['user']['is_chat_admin'] ?? false}');
          await _storage.write(key: _keyHopCapAccess, value: '${data['user']['hop_cap_gpon_access'] ?? false}');
          await _storage.write(key: _keyChamTuAccess, value: '${data['user']['cham_tu_access'] ?? false}');
          await _storage.write(key: _keyChamTuAdmin, value: '${data['user']['cham_tu_admin'] ?? false}');
        }
      }
      return res.statusCode == 200;
    } catch (e) {
      // Lỗi mạng: KHÔNG đăng xuất (tránh mất phiên chỉ vì mất mạng tạm thời) -
      // coi như vẫn còn đăng nhập, app dùng dữ liệu cache offline.
      return true;
    }
  }

  /// Xin 1 "vé" đăng nhập tạm (dùng 1 lần, sống 60 giây) để WebView tự động
  /// có phiên đăng nhập web thật - KHÔNG cần lưu mật khẩu trong app.
  static Future<String?> getWebTicket() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final res = await http.post(Uri.parse(AppConfig.apiWebTicket), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) return data['ticket'];
      return null;
    } catch (e) {
      return null;
    }
  }
}
