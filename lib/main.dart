import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'services/reminder_notification_service.dart';
import 'services/fcm_service.dart';

/// Khóa điều hướng TOÀN CỤC - cho phép mở màn hình từ NGOÀI cây widget (VD
/// khi người dùng bấm vào thông báo đẩy lúc app đang ở nền/đã tắt).
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));

    // Ghi nhận lỗi tự động (Crashlytics) - mọi lỗi Flutter không bắt được sẽ
    // tự động gửi về Firebase Console, không cần nhân viên tự báo lỗi nữa.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Xử lý thông báo khi app đang ở NỀN/ĐÃ TẮT - phải đăng ký SỚM, trước runApp
    FirebaseMessaging.onBackgroundMessage(fcmXuLyNenNgam);
  } catch (e) {
    // Firebase lỗi khởi tạo (VD thiếu cấu hình) KHÔNG được làm app không mở
    // được - bỏ qua, app vẫn chạy bình thường, chỉ là chưa có thông báo
    // đẩy/ghi nhận lỗi tự động.
  }

  try {
    ReminderNotificationService.khoiTao();
    FcmService.thietLapXuLyBamThongBao();
  } catch (e) {
    // Nếu Firebase init thất bại ở trên, các bước liên quan tới FCM có thể
    // ném lỗi ở đây - KHÔNG được để lỗi này chặn mất runApp() (nguyên nhân
    // gây màn hình trắng vĩnh viễn, không crash log, đã xảy ra thực tế).
  }
  runApp(const VinhHungApp());
}

class VinhHungApp extends StatelessWidget {
  const VinhHungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Viettel Khu Vực Vĩnh Hưng',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Giới hạn hệ số phóng chữ tối đa để không vỡ layout trên máy có cài đặt
      // "cỡ chữ lớn" hệ thống, đặc biệt quan trọng khi hiển thị trên tablet
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: .9, maxScaleFactor: 1.2)),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
