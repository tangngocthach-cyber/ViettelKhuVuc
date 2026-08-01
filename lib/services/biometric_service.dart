import 'package:local_auth/local_auth.dart';

/// Bọc thư viện local_auth - xử lý đăng nhập vân tay/Face ID. TẤT CẢ lỗi đều
/// được bắt và trả về false thay vì ném ra ngoài, vì đây chỉ là một "lớp mở
/// khóa nhanh" phủ lên trên phiên đăng nhập thật (token) đã lưu sẵn - không
/// bao giờ được để lỗi ở đây làm treo hay crash app.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// Máy có hỗ trợ VÀ đã cài đặt sẵn vân tay/khuôn mặt trong Cài đặt hệ thống
  /// hay chưa - dùng để ẨN hẳn tùy chọn này nếu máy không hỗ trợ, tránh gây
  /// nhầm lẫn cho người dùng.
  static Future<bool> coSanSang() async {
    try {
      final hoTro = await _auth.isDeviceSupported();
      final coCamBien = await _auth.canCheckBiometrics;
      return hoTro && coCamBien;
    } catch (e) {
      return false;
    }
  }

  /// Yêu cầu xác thực vân tay/khuôn mặt - trả về true nếu xác thực thành công.
  static Future<bool> xacThuc({String lyDo = 'Xác thực để mở khóa ứng dụng'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: lyDo,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (e) {
      // Máy không có vân tay/khuôn mặt nào được cài đặt, hoặc người dùng bấm
      // hủy, hoặc lỗi phần cứng - đều coi là xác thực thất bại, không crash.
      return false;
    }
  }
}
