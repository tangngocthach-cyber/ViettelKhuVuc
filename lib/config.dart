/// Cấu hình chung của toàn bộ app - CHỈ CẦN SỬA Ở ĐÂY nếu domain thay đổi.
class AppConfig {
  /// Domain gốc của website - MỌI API và WebView đều dùng chung domain này,
  /// đảm bảo dữ liệu app luôn khớp với dữ liệu thật trên web (không tạo giả).
  static const String baseUrl = 'https://viettelkhuvuc.com';

  static const String apiLogin = '$baseUrl/api/auth/login.php';
  static const String apiLogout = '$baseUrl/api/auth/logout.php';
  static const String apiMe = '$baseUrl/api/auth/me.php';
  static const String apiProducts = '$baseUrl/api/catalog/products.php';
  static const String apiNews = '$baseUrl/api/catalog/news.php';
  static const String apiPolicies = '$baseUrl/api/catalog/policies.php';
  static const String apiVersionCheck = '$baseUrl/api/version/check.php';
  static const String apiChatConversations = '$baseUrl/api/chat/conversations.php';
  static const String apiChatMessages = '$baseUrl/api/chat/messages.php';
  static const String apiChatSend = '$baseUrl/api/chat/send.php';
  static const String apiChatMarkRead = '$baseUrl/api/chat/mark_read.php';
  static const String apiChatTyping = '$baseUrl/api/chat/typing.php';

  /// Các URL trang thật trên website - mở qua WebView, KHÔNG dựng lại giao diện
  /// riêng trong app (đúng yêu cầu: dữ liệu lấy trực tiếp từ website thật).
  static const String urlSanPham = '$baseUrl/san-pham.php';
  static const String urlTinTuc = '$baseUrl/tin-tuc.php';
  static const String urlChinhSach = '$baseUrl/chinh-sach.php';
  static const String urlSoDep = '$baseUrl/so-dep.php';
  static const String urlDienDan = '$baseUrl/dien-dan.php';
  static const String urlTimKiem = '$baseUrl/tim-kiem.php';
  static const String urlQuaySo = '$baseUrl/quay-so.php';
  static const String urlBocTham = '$baseUrl/boc-tham.php';
  static const String urlLienHe = '$baseUrl/lien-he.php';
  static const String urlGioiThieu = '$baseUrl/index.php';

  /// Khoảng thời gian (giây) app tự kiểm tra tin nhắn mới trong 1 cuộc Chat
  /// (poll đơn giản, không cần server WebSocket riêng - đủ dùng cho quy mô nhỏ)
  static const int chatPollSeconds = 3;

  /// Khoảng thời gian (giờ) tự kiểm tra phiên bản mới + đồng bộ danh mục nền
  static const int backgroundSyncHours = 6;
}
