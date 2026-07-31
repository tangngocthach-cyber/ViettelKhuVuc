import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../main.dart';
import '../screens/chat/chat_detail_screen.dart';
import 'auth_service.dart';
import 'chat_service.dart';

/// Xử lý thông báo khi app đang ở NỀN (background) hoặc ĐÃ TẮT - BẮT BUỘC là
/// hàm cấp cao nhất (top-level), không được đặt trong class, theo đúng yêu
/// cầu của Firebase Messaging.
@pragma('vm:entry-point')
Future<void> fcmXuLyNenNgam(RemoteMessage message) async {
  // Không cần làm gì thêm ở đây - hệ điều hành Android TỰ hiện thông báo hệ
  // thống khi app ở nền (dựa vào phần "notification" trong payload FCM).
}

/// Quản lý Thông báo đẩy (Push Notification) qua Firebase Cloud Messaging.
class FcmService {
  static final _localNotif = FlutterLocalNotificationsPlugin();

  /// Gọi 1 lần sau khi đăng nhập thành công - xin quyền, lấy token, đăng ký
  /// với backend, và lắng nghe thông báo khi app đang MỞ (foreground).
  static Future<void> khoiTaoSauDangNhap() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _dangKyToken(token);

      // Token có thể tự đổi (VD app cài lại) - tự đăng ký lại token mới
      messaging.onTokenRefresh.listen(_dangKyToken);

      // App đang MỞ (foreground): FCM KHÔNG tự hiện thông báo hệ thống, phải
      // tự hiện bằng flutter_local_notifications (dùng lại kênh đã có cho
      // tính năng Nhắc hẹn để không phải khai báo kênh mới).
      FirebaseMessaging.onMessage.listen((message) {
        final tieuDe = message.notification?.title ?? 'Thông báo mới';
        final noiDung = message.notification?.body ?? '';
        _localNotif.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
          tieuDe, noiDung,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'nhac_hen_channel', 'Nhắc hẹn',
              channelDescription: 'Thông báo nhắc hẹn từ Chat nội bộ',
              importance: Importance.high, priority: Priority.high,
            ),
          ),
        );
      });
    } catch (e) {
      // Lỗi thiết lập thông báo đẩy KHÔNG được làm crash cả app - bỏ qua, app
      // vẫn dùng được bình thường, chỉ là chưa nhận được thông báo đẩy.
    }
  }

  static Future<void> _dangKyToken(String token) async {
    try {
      final authToken = await AuthService.getToken();
      if (authToken == null) return;
      await http.post(
        Uri.parse(AppConfig.apiFcmRegisterToken),
        headers: {'Authorization': 'Bearer $authToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      // Lỗi mạng tạm thời - bỏ qua, token sẽ tự đăng ký lại lần mở app kế tiếp
    }
  }

  /// Hủy đăng ký thiết bị - PHẢI gọi khi đăng xuất, nếu không thiết bị vẫn
  /// tiếp tục nhận thông báo Chat dù đã đăng xuất (rủi ro lộ thông tin nếu
  /// máy được giao cho người khác dùng).
  static Future<void> huyDangKy() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      final authToken = await AuthService.getToken();
      if (token == null || authToken == null) return;
      await http.post(
        Uri.parse(AppConfig.apiFcmUnregisterToken),
        headers: {'Authorization': 'Bearer $authToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': token}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      // Lỗi mạng - bỏ qua, không được chặn việc đăng xuất chỉ vì lỗi này
    }
  }

  /// Gọi 1 lần trong main() - xử lý khi người dùng BẤM vào thông báo (cả lúc
  /// app đang nền lẫn lúc app đã tắt hẳn rồi mở lên từ thông báo) để tự động
  /// mở ĐÚNG cuộc trò chuyện liên quan, không cần tự tìm lại thủ công.
  static void thietLapXuLyBamThongBao() {
    // App đang chạy NỀN, người dùng bấm thông báo để mở lại lên trên
    FirebaseMessaging.onMessageOpenedApp.listen(_moDungCuocTroChuyen);
    // App ĐÃ TẮT HẲN, mở lên CHÍNH TỪ việc bấm thông báo (kiểm tra ngay khi khởi động)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _moDungCuocTroChuyen(message);
    });
  }

  static Future<void> _moDungCuocTroChuyen(RemoteMessage message) async {
    final conversationIdStr = message.data['conversation_id'];
    if (conversationIdStr == null) return;
    final conversationId = int.tryParse('$conversationIdStr');
    if (conversationId == null) return;

    try {
      final dsHoiThoai = await ChatService.getConversations();
      final hoiThoai = dsHoiThoai.where((c) => c.id == conversationId).toList();
      if (hoiThoai.isEmpty) return;
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: hoiThoai.first)));
    } catch (e) {
      // Lỗi mạng khi đang cố mở cuộc trò chuyện từ thông báo - bỏ qua, người
      // dùng vẫn có thể tự vào tay qua tab Chat nội bộ như bình thường.
    }
  }
}
