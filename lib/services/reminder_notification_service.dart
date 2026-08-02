import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Quản lý thông báo hẹn giờ CỤC BỘ (đặt lịch ngay trên máy, không cần
/// Internet tại đúng thời điểm hẹn) - dùng cho tính năng "Nhắc hẹn" trong
/// Chat. KHÁC với thông báo đẩy (push) thật - nhắc hẹn chỉ hoạt động trên
/// MÁY ĐÃ TỪNG THẤY tin nhắn nhắc hẹn đó (qua polling khi mở app).
///
/// Có 2 nút hành động bấm THẲNG trên thông báo (không cần mở app):
/// - "Đã xong": chỉ tắt thông báo, không cần làm gì thêm
/// - "Nhắc lại sau 15 phút": tự đặt lại lịch, báo lại sau đúng 15 phút
class ReminderNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _daKhoiTao = false;

  static const _actionXong = 'xong';
  static const _actionNhacLai = 'nhac_lai';

  /// Gọi 1 lần khi mở app (main.dart) - chuẩn bị múi giờ + xin quyền thông báo.
  /// TỰ BẮT LỖI ngay tại đây (không để lộ ra ngoài) - đây là lớp bảo vệ GỐC,
  /// đảm bảo MỌI nơi gọi tới tính năng thông báo (Sổ ghi chú, Chat...) đều an
  /// toàn dù thư viện bên dưới có trục trặc gì, không riêng gì 1 màn hình cụ thể.
  static Future<void> khoiTao() async {
    if (_daKhoiTao) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _xuLyPhanHoi,
        onDidReceiveBackgroundNotificationResponse: _xuLyPhanHoiNen,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();

      _daKhoiTao = true;
    } catch (e) {
      // Lỗi khởi tạo hệ thống thông báo (hiếm gặp) - KHÔNG ném ra ngoài, các
      // tính năng khác của app vẫn phải chạy bình thường, chỉ là chưa có
      // được thông báo/nhắc hẹn cho tới khi mở lại app.
    }
  }

  /// Xử lý khi bấm nút hành động trên thông báo LÚC APP ĐANG MỞ (foreground)
  static void _xuLyPhanHoi(NotificationResponse response) => _xuLyHanhDong(response);

  /// Xử lý khi bấm nút hành động LÚC APP ĐÃ TẮT HẲN - BẮT BUỘC phải là hàm
  /// static/top-level có @pragma này, plugin chạy nó trên 1 isolate riêng
  /// KHÔNG chia sẻ state với app chính, nên không được đụng tới bất kỳ biến
  /// toàn cục nào khác ngoài chính plugin thông báo.
  @pragma('vm:entry-point')
  static void _xuLyPhanHoiNen(NotificationResponse response) => _xuLyHanhDong(response);

  static void _xuLyHanhDong(NotificationResponse response) {
    if (response.actionId == _actionNhacLai) {
      try {
        final data = jsonDecode(response.payload ?? '{}');
        datLich(
          messageId: response.id ?? 0,
          tieuDe: data['tieu_de'] ?? '',
          moTa: data['mo_ta'],
          thoiGianNhac: DateTime.now().add(const Duration(minutes: 15)),
        );
      } catch (e) {
        // Payload lỗi/thiếu - không đặt lại lịch được thì thôi, không crash isolate nền
      }
    }
    // Nút "Đã xong" hoặc bấm thẳng vào thông báo: không cần làm gì thêm,
    // hệ thống tự tắt thông báo đó.
  }

  /// Đặt lịch nhắc hẹn cho 1 tin nhắn cụ thể - dùng CHÍNH messageId làm ID
  /// thông báo, nên gọi lại nhiều lần với cùng messageId là AN TOÀN (tự động
  /// ghi đè lịch cũ, không bị nhân đôi thông báo). TỰ BẮT LỖI - không bao giờ
  /// ném lỗi ra ngoài, vì đây chỉ là tính năng PHỤ (nhắc giờ), không được để
  /// nó làm hỏng tính năng CHÍNH (lưu ghi chú/gửi tin nhắn) ở nơi gọi tới.
  static Future<void> datLich({required int messageId, required String tieuDe, String? moTa, required DateTime thoiGianNhac}) async {
    try {
      await khoiTao();
      // Đã qua giờ hẹn rồi thì thôi, không đặt lịch nữa (tránh báo ngay lập tức
      // cho nhắc hẹn cũ đã hết hạn khi tải lại lịch sử chat)
      if (thoiGianNhac.isBefore(DateTime.now())) return;

      final androidDetails = AndroidNotificationDetails(
        'nhac_hen_channel', 'Nhắc hẹn',
        channelDescription: 'Thông báo nhắc hẹn từ Chat nội bộ',
        importance: Importance.high, priority: Priority.high,
        actions: const [
          AndroidNotificationAction(_actionXong, 'Đã xong', showsUserInterface: false),
          AndroidNotificationAction(_actionNhacLai, 'Nhắc lại sau 15 phút', showsUserInterface: false),
        ],
      );
      final details = NotificationDetails(android: androidDetails);

      // Lưu tiêu đề/mô tả vào payload để khi bấm "Nhắc lại", isolate nền (không
      // còn state gì khác) vẫn biết nội dung gốc để đặt lại lịch cho đúng.
      final payload = jsonEncode({'tieu_de': tieuDe, 'mo_ta': moTa});

      await _plugin.zonedSchedule(
        messageId, // dùng messageId làm ID thông báo - gọi lại không bị nhân đôi
        '🔔 Nhắc hẹn: $tieuDe',
        moTa ?? '',
        tz.TZDateTime.from(thoiGianNhac, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      // Lỗi đặt lịch (thư viện lỗi, quyền bị từ chối...) - bỏ qua, không ném
      // ra ngoài. Nơi gọi tới (VD lưu ghi chú) đã hoàn tất việc CHÍNH rồi.
    }
  }

  /// Hủy lịch nhắc hẹn (nếu tin nhắn bị thu hồi/xóa) - TỰ BẮT LỖI, lý do
  /// tương tự datLich() ở trên.
  static Future<void> huyLich(int messageId) async {
    try {
      await _plugin.cancel(messageId);
    } catch (e) {
      // Bỏ qua - hủy thông báo thất bại không quan trọng bằng việc CHÍNH đã xong
    }
  }
}
