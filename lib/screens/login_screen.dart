import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'webview_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _dangDangNhap = false;
  bool _anMatKhau = true;
  String? _loi;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _dangNhap() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _loi = 'Vui lòng nhập đầy đủ email và mật khẩu.');
      return;
    }
    FocusScope.of(context).unfocus(); // ẩn bàn phím để thấy rõ kết quả
    setState(() {
      _dangDangNhap = true;
      _loi = null;
    });
    final loi = await AuthService.login(email, pass);
    if (!mounted) return;
    setState(() => _dangDangNhap = false);
    if (loi == null) {
      TextInput.finishAutofillContext(); // cho phép trình quản lý mật khẩu của máy lưu lại
      FcmService.khoiTaoSauDangNhap();
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } else {
      setState(() => _loi = loi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toi = context.laCheDoToi;
    // SỬA LỖI HIỂN THỊ: trước đây nền cứng màu TRẮNG - máy để chế độ Tối thì
    // chữ tiêu đề cũng chuyển trắng -> trắng trên trắng, không thấy gì.
    // Nay: nền đỏ thương hiệu phía trên + thẻ đăng nhập theo màu chế độ.
    return Scaffold(
      backgroundColor: toi ? AppTheme.bgDark : AppTheme.bgLight,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Container(
              height: MediaQuery.sizeOf(context).height * .42,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.viettelRed, AppTheme.viettelRedDark],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  // Giới hạn chiều rộng trên tablet để form không bị kéo dãn quá to
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 6))],
                          ),
                          child: const Image(image: AssetImage('assets/images/logo-vinhhung.png')),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Viettel Khu Vực Vĩnh Hưng',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -.3),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ứng dụng nội bộ dành cho cán bộ, nhân viên',
                          style: TextStyle(color: Colors.white70, fontSize: 13.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 12),
                          decoration: BoxDecoration(
                            color: context.mauNenThe,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: toi ? .3 : .08), blurRadius: 24, offset: const Offset(0, 8))],
                          ),
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Đăng nhập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.mauChuChinh)),
                                const SizedBox(height: 4),
                                Text('Dùng tài khoản đã được cấp trên website', style: TextStyle(fontSize: 13, color: context.mauChuPhu)),
                                const SizedBox(height: 18),
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                                  enabled: !_dangDangNhap,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    fillColor: context.mauNenO,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _passCtrl,
                                  obscureText: _anMatKhau,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: const [AutofillHints.password],
                                  enabled: !_dangDangNhap,
                                  onSubmitted: (_) => _dangNhap(),
                                  decoration: InputDecoration(
                                    labelText: 'Mật khẩu',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    fillColor: context.mauNenO,
                                    suffixIcon: IconButton(
                                      tooltip: _anMatKhau ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                                      icon: Icon(_anMatKhau ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
                                    ),
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  child: _loi == null
                                      ? const SizedBox(width: double.infinity)
                                      : Container(
                                          margin: const EdgeInsets.only(top: 14),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: toi ? .18 : .08),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(children: [
                                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(_loi!, style: TextStyle(color: toi ? Colors.red.shade200 : Colors.red.shade700, fontSize: 13.5))),
                                          ]),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _dangDangNhap ? null : _dangNhap,
                                    child: _dangDangNhap
                                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                                        : const Text('Đăng nhập'),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: _dangDangNhap
                                      ? null
                                      : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const WebViewScreen(url: '${AppConfig.baseUrl}/tai-khoan-quen-mat-khau.php', title: 'Quên mật khẩu')),
                                          ),
                                  child: const Text('Quên mật khẩu?'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
