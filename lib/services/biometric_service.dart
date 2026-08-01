import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Kết quả xác thực - kèm LÝ DO LỖI CỤ THỂ (nếu thất bại) thay vì chỉ
/// true/false chung chung, để người dùng biết chính xác cần làm gì tiếp theo
/// (VD: "chưa cài vân tay trong Cài đặt máy" khác hẳn "bấm hủy").
class KetQuaXacThuc {
  final bool thanhCong;
  final String? lyDoLoi;
  const KetQuaXacThuc({required this.thanhCong, this.lyDoLoi});
}

/// Bọc thư viện local_auth - xử lý đăng nhập vân tay/Face ID. TẤT CẢ lỗi đều
/// được bắt và trả về kết quả có lý do rõ ràng thay vì ném ra ngoài, vì đây
/// chỉ là một "lớp mở khóa nhanh" phủ lên trên phiên đăng nhập thật (token)
/// đã lưu sẵn - không bao giờ được để lỗi ở đây làm treo hay crash app.
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

  /// Yêu cầu xác thực vân tay/khuôn mặt - trả về kết quả kèm lý do cụ thể
  /// nếu thất bại (thay vì chỉ true/false như bản trước).
  static Future<KetQuaXacThuc> xacThuc({String lyDo = 'Xác thực để mở khóa ứng dụng'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: lyDo,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      return KetQuaXacThuc(thanhCong: ok, lyDoLoi: ok ? null : 'Bạn đã hủy hoặc xác thực không khớp.');
    } on PlatformException catch (e) {
      // local_auth trả các mã lỗi cố định (NotAvailable/NotEnrolled/LockedOut...)
      // - dịch sang tiếng Việt dễ hiểu, còn lại thì hiện nguyên thông báo gốc
      // để không "nuốt" mất manh mối khi gặp lỗi lạ chưa liệt kê tới.
      final ma = e.code.toLowerCase();
      String lyDoLoi;
      if (ma.contains('notenrolled')) {
        lyDoLoi = 'Máy CHƯA cài vân tay/khuôn mặt nào. Vào Cài đặt máy > Bảo mật > Vân tay/Khuôn mặt để thêm trước, rồi quay lại bật ở đây.';
      } else if (ma.contains('notavailable')) {
        lyDoLoi = 'Máy này không có cảm biến vân tay/khuôn mặt.';
      } else if (ma.contains('passcodenotset')) {
        lyDoLoi = 'Máy chưa đặt mã khóa màn hình (PIN/mẫu hình). Cần đặt mã khóa máy trước khi dùng được vân tay.';
      } else if (ma.contains('lockedout')) {
        lyDoLoi = 'Vân tay bị khóa tạm do nhập sai quá nhiều lần. Mở khóa máy bằng mật khẩu rồi thử lại sau.';
      } else {
        lyDoLoi = 'Lỗi: ${e.message ?? e.code}';
      }
      return KetQuaXacThuc(thanhCong: false, lyDoLoi: lyDoLoi);
    } catch (e) {
      return KetQuaXacThuc(thanhCong: false, lyDoLoi: 'Lỗi không xác định: $e');
    }
  }
}
