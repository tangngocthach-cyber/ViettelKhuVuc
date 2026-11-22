/// Các hàm kiểm tra AN TOÀN dùng chung toàn app (WebView, tải file, cập nhật
/// app, Chat) - gom 1 chỗ để mọi nơi áp dụng CÙNG 1 quy tắc, tránh mỗi màn
/// hình tự viết 1 kiểu rồi sót lỗ hổng.
class AnToan {
  /// Domain gốc của hệ thống - CHỈ trang thuộc domain này mới được chạy
  /// JavaScript có quyền gọi về app (lấy vị trí, lưu file...).
  static const String domainGoc = 'viettelkhuvuc.com';

  /// Đúng domain của hệ thống (hoặc subdomain có dấu chấm phía trước).
  /// KHÔNG dùng endsWith('viettelkhuvuc.com') trần vì domain giả như
  /// "xviettelkhuvuc.com" cũng khớp.
  static bool laHostCuaSite(String host) {
    final h = host.toLowerCase();
    return h == domainGoc || h.endsWith('.$domainGoc');
  }

  /// URL https thuộc đúng domain hệ thống.
  static bool laUrlHttpsCuaSite(Uri? uri) {
    if (uri == null) return false;
    return uri.scheme == 'https' && laHostCuaSite(uri.host);
  }

  /// Làm sạch tên file trước khi ghép vào đường dẫn lưu trên máy: bỏ phần
  /// thư mục ("../../"), bỏ ký tự cấm, chặn tên rỗng hoặc chỉ toàn dấu chấm.
  /// Lý do: tên file lấy từ server/tin nhắn Chat (người khác gửi) - nếu
  /// chứa "../" có thể ghi đè file dữ liệu riêng của app.
  static String tenFile(String? ten, {String macDinh = 'tep-tin'}) {
    var s = (ten ?? '').trim();
    // Chỉ giữ phần sau dấu / hoặc \ cuối cùng
    final viTri = s.lastIndexOf(RegExp(r'[\\/]'));
    if (viTri >= 0) s = s.substring(viTri + 1);
    s = s.replaceAll(RegExp(r'[:*?"<>|\x00-\x1f]'), '-').trim();
    // Không cho tên bắt đầu bằng dấu chấm (file ẩn / "..")
    s = s.replaceFirst(RegExp(r'^\.+'), '');
    if (s.isEmpty) s = macDinh;
    if (s.length > 120) {
      final cham = s.lastIndexOf('.');
      final duoi = (cham > 0 && s.length - cham <= 8) ? s.substring(cham) : '';
      s = s.substring(0, 120 - duoi.length) + duoi;
    }
    return s;
  }
}
