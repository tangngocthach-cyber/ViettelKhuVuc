import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Màn hình khóa bằng vân tay/Face ID - hiện SAU màn splash, TRƯỚC khi vào
/// app, nếu người dùng đã bật tính năng này ở Tài khoản > Cài đặt. Xác thực
/// thành công mới vào được Trang chủ; có thể "Đăng xuất" để dùng mật khẩu.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _dangXacThuc = false;
  bool _thatBaiLanDau = false;
  String? _lyDoLoi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _thuXacThuc());
  }

  Future<void> _thuXacThuc() async {
    setState(() => _dangXacThuc = true);
    final ketQua = await BiometricService.xacThuc(lyDo: 'Xác thực vân tay/khuôn mặt để mở ứng dụng');
    if (!mounted) return;
    setState(() {
      _dangXacThuc = false;
      if (!ketQua.thanhCong) {
        _thatBaiLanDau = true;
        _lyDoLoi = ketQua.lyDoLoi;
      }
    });
    if (ketQua.thanhCong) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _dangXuat() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.viettelRed,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, color: Colors.white, size: 88),
                const SizedBox(height: 20),
                const Text(
                  'Xác thực để mở ứng dụng',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_dangXacThuc) const CircularProgressIndicator(color: Colors.white),
                if (!_dangXacThuc && _thatBaiLanDau) ...[
                  Text(
                    _lyDoLoi ?? 'Xác thực không thành công hoặc đã bị hủy.',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _thuXacThuc,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.viettelRed),
                    child: const Text('Thử lại'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _dangXuat,
                    child: const Text('Đăng xuất, dùng mật khẩu', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
