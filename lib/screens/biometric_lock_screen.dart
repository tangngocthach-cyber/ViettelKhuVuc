import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Màn hình khóa bằng vân tay/Face ID - hiện SAU màn splash, TRƯỚC khi vào
/// app, nếu người dùng đã bật tính năng này ở Tài khoản > Cài đặt. Xác thực
/// thành công mới vào được Trang chủ; có thể "Đăng xuất" để dùng mật khẩu.
///
/// [moKhoaTaiCho] = true: dùng khi app TỰ KHÓA LẠI sau thời gian để ở nền
/// (màn này được đẩy CHỒNG lên trên màn đang dùng) - mở khóa xong chỉ cần
/// đóng màn khóa, quay lại đúng chỗ đang làm dở, KHÔNG mở lại Trang chủ mới.
class BiometricLockScreen extends StatefulWidget {
  final bool moKhoaTaiCho;
  const BiometricLockScreen({super.key, this.moKhoaTaiCho = false});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _dangXacThuc = false;
  bool _thatBaiLanDau = false;
  String? _lyDoLoi;
  String _ten = '';

  @override
  void initState() {
    super.initState();
    _taiTen();
    WidgetsBinding.instance.addPostFrameCallback((_) => _thuXacThuc());
  }

  Future<void> _taiTen() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) setState(() => _ten = (user['name'] ?? '').trim());
    } catch (e) {
      // Không đọc được tên - bỏ qua
    }
  }

  Future<void> _thuXacThuc() async {
    if (_dangXacThuc) return;
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
    if (!ketQua.thanhCong) return;
    if (widget.moKhoaTaiCho) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _dangXuat() async {
    await AuthService.logout();
    if (!mounted) return;
    // Xóa SẠCH mọi màn phía dưới (kể cả khi đang khóa chồng lên màn đang
    // dùng) - tránh bấm Quay lại vẫn vào được dữ liệu sau khi đã đăng xuất.
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // Khóa lại khi đang dùng dở: CHẶN nút Quay lại của Android (bấm Quay lại
    // không được lọt xuống màn bên dưới) - bắt buộc xác thực hoặc đăng xuất.
    // Khóa lúc mới mở app: Quay lại = thoát app như bình thường.
    return PopScope(
      canPop: !widget.moKhoaTaiCho,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.viettelRed, AppTheme.viettelRedDark],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                        child: const Image(image: AssetImage('assets/images/logo-vinhhung.png')),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _ten.isEmpty ? 'Viettel Khu Vực Vĩnh Hưng' : 'Xin chào, $_ten',
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Xác thực để mở ứng dụng',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      Semantics(
                        button: true,
                        label: 'Xác thực vân tay hoặc khuôn mặt',
                        child: InkWell(
                          onTap: _dangXacThuc ? null : _thuXacThuc,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: .14),
                              border: Border.all(color: Colors.white38, width: 1.5),
                            ),
                            child: _dangXacThuc
                                ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6))
                                : const Icon(Icons.fingerprint, color: Colors.white, size: 58),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_dangXacThuc && _thatBaiLanDau) ...[
                        Text(
                          _lyDoLoi ?? 'Xác thực không thành công hoặc đã bị hủy.',
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 220,
                          child: ElevatedButton.icon(
                            onPressed: _thuXacThuc,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.viettelRed),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _dangXuat,
                          child: const Text('Đăng xuất, dùng mật khẩu', style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white70)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
