import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../theme.dart';
import 'home_screen.dart';

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

  Future<void> _dangNhap() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _loi = 'Vui lòng nhập đầy đủ email và mật khẩu.');
      return;
    }
    setState(() {
      _dangDangNhap = true;
      _loi = null;
    });
    final loi = await AuthService.login(email, pass);
    if (!mounted) return;
    setState(() => _dangDangNhap = false);
    if (loi == null) {
      FcmService.khoiTaoSauDangNhap();
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } else {
      setState(() => _loi = loi);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            // Giới hạn chiều rộng trên tablet để form không bị kéo dãn quá to
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 96,
                    height: 96,
                    child: Image(image: AssetImage('assets/images/logo-vinhhung.png')),
                  ),
                  const SizedBox(height: 20),
                  const Text('Viettel Khu Vực Vĩnh Hưng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text('Đăng nhập bằng tài khoản đã cấp trên website', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _anMatKhau,
                    onSubmitted: (_) => _dangNhap(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_anMatKhau ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _anMatKhau = !_anMatKhau),
                      ),
                    ),
                  ),
                  if (_loi != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(_loi!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _dangDangNhap ? null : _dangNhap,
                      child: _dangDangNhap
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                          : const Text('Đăng nhập'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
