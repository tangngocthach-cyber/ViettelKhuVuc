import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/version_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'update_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _khoiDong());
  }

  Future<void> _khoiDong() async {
    final daDangNhap = await AuthService.validateSession();
    if (!mounted) return;

    // Kiểm tra phiên bản mới NGAY khi mở app (đúng yêu cầu "khi mở app hoặc
    // theo chu kỳ") - nếu bắt buộc cập nhật, chặn vào app cho tới khi cập nhật.
    final versionInfo = await VersionService.checkForUpdate();
    if (!mounted) return;
    if (versionInfo != null) {
      await showDialog(
        context: context,
        barrierDismissible: !versionInfo.forceUpdate,
        builder: (_) => UpdateDialog(info: versionInfo),
      );
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => daDangNhap ? const HomeScreen() : const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.viettelRed,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 96, height: 96, child: Image(image: AssetImage('assets/images/logo-vinhhung.png'))),
            SizedBox(height: 16),
            Text('Viettel Khu Vực Vĩnh Hưng', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
