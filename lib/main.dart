import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'services/reminder_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ReminderNotificationService.khoiTao();
  runApp(const VinhHungApp());
}

class VinhHungApp extends StatelessWidget {
  const VinhHungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
