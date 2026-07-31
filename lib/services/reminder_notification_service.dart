import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Quản lý thông báo hẹn giờ CỤC BỘ (đặt lịch ngay trên máy, không cần
/// Internet tại đúng thời điểm hẹn) - dùng cho tính năng "Nhắc hẹn" trong
/// Chat. KHÁC với thông báo đẩy (push) thật - nhắc hẹn chỉ hoạt động trên
/// MÁY ĐÃ TỪNG THẤY tin nhắn nhắc hẹn đó (qua polling khi mở app).
class ReminderNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _daKhoiTao = false;

  /// Gọi 1 lần khi mở app (main.dart) - chuẩn bị múi giờ + xin quyền thông báo
  static Future<void> khoiTao() async {
    if (_daKhoiTao) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _daKhoiTao = true;
  }

  /// Đặt lịch nhắc hẹn cho 1 tin nhắn cụ thể - dùng CHÍNH messageId làm ID
  /// thông báo, nên gọi lại nhiều lần với cùng messageId là AN TOÀN (tự động
  /// ghi đè lịch cũ, không bị nhân đôi thông báo).
  static Future<void> datLich({required int messageId, required String tieuDe, String? moTa, required DateTime thoiGianNhac}) async {
    await khoiTao();
    // Đã qua giờ hẹn rồi thì thôi, không đặt lịch nữa (tránh báo ngay lập tức
    // cho nhắc hẹn cũ đã hết hạn khi tải lại lịch sử chat)
    if (thoiGianNhac.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'nhac_hen_channel', 'Nhắc hẹn',
      channelDescription: 'Thông báo nhắc hẹn từ Chat nội bộ',
      importance: Importance.high, priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      messageId, // dùng messageId làm ID thông báo - gọi lại không bị nhân đôi
      '🔔 Nhắc hẹn: $tieuDe',
      moTa ?? '',
      tz.TZDateTime.from(thoiGianNhac, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Hủy lịch nhắc hẹn (nếu tin nhắn bị thu hồi/xóa)
  static Future<void> huyLich(int messageId) async {
    await _plugin.cancel(messageId);
  }
}
