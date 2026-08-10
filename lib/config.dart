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
  static const String apiChamTuTao = '$baseUrl/api/cham-tu/tao.php';
  static const String apiChamTuDanhSach = '$baseUrl/api/cham-tu/danh-sach.php';
  static const String apiChamTuSua = '$baseUrl/api/cham-tu/sua.php';
  static const String apiChamTuXoa = '$baseUrl/api/cham-tu/xoa.php';
  static const String apiChamTuDuyet = '$baseUrl/api/cham-tu/duyet.php';
  static const String apiChamTuLichSu = '$baseUrl/api/cham-tu/lich-su.php';
  static const String apiChamTuBackup = '$baseUrl/api/cham-tu/backup.php';
  static const String apiChamTuRestore = '$baseUrl/api/cham-tu/restore.php';
  static const String apiChamTuNhapExcel = '$baseUrl/api/cham-tu/nhap-excel.php';
  static const String urlBanDoChamTu = '$baseUrl/ban-do-cham-tu.php';
  static const String urlChonViTriChamTu = '$baseUrl/chon-vi-tri-cham-tu.php';
  static const String urlChonViTriDonGian = '$baseUrl/chon-vi-tri-don-gian.php';
  static const String apiPolicies = '$baseUrl/api/catalog/policies.php';
  static const String apiVersionCheck = '$baseUrl/api/version/check.php';
  static const String apiChatConversations = '$baseUrl/api/chat/conversations.php';
  static const String apiChatMessages = '$baseUrl/api/chat/messages.php';
  static const String apiChatSend = '$baseUrl/api/chat/send.php';
  static const String apiChatMarkRead = '$baseUrl/api/chat/mark_read.php';
  static const String apiChatTyping = '$baseUrl/api/chat/typing.php';
  static const String apiChatLike = '$baseUrl/api/chat/like.php';
  static const String apiChatRecall = '$baseUrl/api/chat/recall.php';
  static const String apiChatPin = '$baseUrl/api/chat/pin.php';
  static const String apiChatPinnedList = '$baseUrl/api/chat/pinned_list.php';
  static const String apiChatSearch = '$baseUrl/api/chat/search.php';
  static const String apiChatPollCreate = '$baseUrl/api/chat/poll_create.php';
  static const String apiChatPollVote = '$baseUrl/api/chat/poll_vote.php';
  static const String apiChatForward = '$baseUrl/api/chat/forward.php';
  static const String apiChatReminderCreate = '$baseUrl/api/chat/reminder_create.php';
  static const String apiChatTaoNhom = '$baseUrl/api/chat/tao_nhom.php';
  static const String apiChatThemThanhVien = '$baseUrl/api/chat/them_thanh_vien.php';
  static const String apiChatXoaThanhVien = '$baseUrl/api/chat/xoa_thanh_vien.php';
  static const String apiChatRoiNhom = '$baseUrl/api/chat/roi_nhom.php';
  static const String apiChatDoiVaiTro = '$baseUrl/api/chat/doi_vai_tro.php';
  static const String apiChatDoiThongTinNhom = '$baseUrl/api/chat/doi_thong_tin_nhom.php';
  static const String apiChatGiaiTanNhom = '$baseUrl/api/chat/giai_tan_nhom.php';
  static const String apiChatThanhVien = '$baseUrl/api/chat/thanh_vien.php';
  static const String apiChatDanhSachLienHe = '$baseUrl/api/chat/danh_sach_lien_he.php';
  static const String apiChatAiDaXem = '$baseUrl/api/chat/ai_da_xem.php';
  static const String apiChatAiDaThich = '$baseUrl/api/chat/ai_da_thich.php';
  static const String apiChatMediaFiles = '$baseUrl/api/chat/media_files.php';
  static const String apiChatPing = '$baseUrl/api/chat/ping.php';
  static const String apiFcmRegisterToken = '$baseUrl/api/fcm/register_token.php';
  static const String apiFcmUnregisterToken = '$baseUrl/api/fcm/unregister_token.php';
  static const String apiWebTicket = '$baseUrl/api/auth/web_ticket.php';
  static const String urlSessionLogin = '$baseUrl/app-session-login.php';

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

  /// Công cụ nội bộ dành cho nhân viên (đã xác nhận đúng tên file thật trên
  /// site, không đoán) - quyền truy cập từng trang do chính PHP phía sau kiểm
  /// tra như trên web (dùng chung phiên đăng nhập qua app-session-login.php).
  static const String urlDashboardKPI = '$baseUrl/dashboard-kpi.php';
  static const String urlNhapKetQua = '$baseUrl/nhap-ket-qua.php';
  static const String urlGiaoViecTongHop = '$baseUrl/giao-viec-tong-hop.php';
  static const String urlThuCuocDashboard = '$baseUrl/thu-cuoc-dashboard.php';
  static const String urlTienIchNoiBo = '$baseUrl/tien-ich-noi-bo.php';
  static const String urlKhoaHoc = '$baseUrl/khoa-hoc.php';
  static const String urlLichSuHocTap = '$baseUrl/lich-su-hoc-tap.php';
  static const String urlChungChiCuaToi = '$baseUrl/chung-chi-cua-toi.php';
  static const String urlKhoDuLieuExcel = '$baseUrl/kho-du-lieu-excel.php';
  /// Bill cước & Thông báo nợ - in Bill cước A5/Thông báo nợ A4 theo từng
  /// khách hàng (module riêng, tách biệt với "Kết quả Thu cước" ở trên).
  static const String urlBillCuoc = '$baseUrl/bill-cuoc.php';
  /// Bản đồ vị trí + hiệu suất các hộp chia cáp quang GPON (Leaflet.js, dữ
  /// liệu nhập từ file KML, cập nhật qua admin/ban-do-hop-cap.php).
  static const String urlBanDoHopCap = '$baseUrl/ban-do-hop-cap.php';
  static const String urlThuVienTaiLieu = '$baseUrl/e-tai-lieu.php';
  static const String urlTroLyKPI = '$baseUrl/tro-ly-ai.php';
  /// Trang chủ - nơi có sẵn khung "Hỏi đáp tự động Viettel Vĩnh Hưng" (chatbox
  /// công khai trả lời khách về SIM/Internet/Truyền hình/Camera/Thanh toán...),
  /// nhúng bằng WebView để dùng lại đúng chatbox có sẵn, không xây lại từ đầu.
  /// LƯU Ý: PHẢI ghi rõ '/index.php', không được để trống - nếu để trống,
  /// bước đăng nhập tự động qua vé phiên sẽ hiểu nhầm redirect rỗng và đá
  /// thẳng về trang Hồ sơ cá nhân thay vì trang chủ (bug thật đã gặp).
  static const String urlHoiDap = '$baseUrl/index.php?hoi_dap=1';

  /// Khoảng thời gian (giây) app tự kiểm tra tin nhắn mới trong 1 cuộc Chat
  /// (poll đơn giản, không cần server WebSocket riêng - đủ dùng cho quy mô nhỏ)
  static const int chatPollSeconds = 3;

  /// Khoảng thời gian (giờ) tự kiểm tra phiên bản mới + đồng bộ danh mục nền
  static const int backgroundSyncHours = 6;
}
