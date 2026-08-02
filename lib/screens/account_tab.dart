import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/fcm_service.dart';
import '../services/version_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'biometric_lock_screen.dart';
import 'update_dialog.dart';

class TaiKhoanTab extends StatefulWidget {
  const TaiKhoanTab({super.key});

  @override
  State<TaiKhoanTab> createState() => _TaiKhoanTabState();
}

class _TaiKhoanTabState extends State<TaiKhoanTab> {
  Map<String, String> _user = {};
  String _versionName = '';
  bool _coCamBienVanTay = false;
  bool _vanTayDangBat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.getCurrentUser();
    final info = await PackageInfo.fromPlatform();
    final coCamBien = await BiometricService.coSanSang();
    final vanTayBat = await AuthService.isBiometricEnabled();
    if (!mounted) return;
    setState(() {
      _user = user;
      _versionName = info.version;
      _coCamBienVanTay = coCamBien;
      _vanTayDangBat = vanTayBat;
    });
  }

  Future<void> _doiVanTay(bool batLen) async {
    if (batLen) {
      // Bắt xác thực NGAY LÚC BẬT để chắc chắn máy đọc được vân tay/khuôn mặt
      // của đúng người đang cầm điện thoại - tránh trường hợp bật hộ nhầm.
      final ketQua = await BiometricService.xacThuc(lyDo: 'Xác thực để bật đăng nhập vân tay');
      if (!ketQua.thanhCong) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ketQua.lyDoLoi ?? 'Xác thực không thành công, chưa bật được.'), duration: const Duration(seconds: 6)),
          );
        }
        return;
      }
    }
    await AuthService.setBiometricEnabled(batLen);
    if (!mounted) return;
    setState(() => _vanTayDangBat = batLen);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(batLen ? 'Đã bật đăng nhập vân tay.' : 'Đã tắt đăng nhập vân tay.')));
  }

  Future<void> _chonGiaoDien() async {
    final chon = await showDialog<ThemeMode>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chọn giao diện'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(value: ThemeMode.light, groupValue: themeController.themeMode, title: const Text('Sáng'), onChanged: (v) => Navigator.pop(context, v)),
            RadioListTile(value: ThemeMode.dark, groupValue: themeController.themeMode, title: const Text('Tối'), onChanged: (v) => Navigator.pop(context, v)),
            RadioListTile(value: ThemeMode.system, groupValue: themeController.themeMode, title: const Text('Theo hệ thống'), onChanged: (v) => Navigator.pop(context, v)),
          ],
        ),
      ),
    );
    if (chon != null) await themeController.doiCheDo(chon);
  }

  Future<void> _dangXuat() async {
    final coVanTay = await AuthService.isBiometricEnabled();

    if (coVanTay) {
      // Đã bật vân tay -> cho chọn "Khóa" (giữ nguyên phiên đăng nhập, lần
      // sau mở app chỉ cần vân tay, KHÔNG cần gõ lại mật khẩu) hoặc
      // "Đăng xuất hẳn" (xóa phiên thật - dùng khi đổi máy/cho mượn máy).
      final luaChon = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Thoát ứng dụng'),
          content: const Text(
            'Bạn đã bật đăng nhập vân tay. Chọn "Khóa" để lần sau mở app chỉ '
            'cần vân tay, không cần gõ lại mật khẩu - hoặc "Đăng xuất hẳn" nếu '
            'muốn xóa phiên đăng nhập thật sự (VD: đổi máy, cho mượn máy).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'huy'), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, 'khoa'), child: const Text('Khóa')),
            TextButton(onPressed: () => Navigator.pop(context, 'dang_xuat'), child: const Text('Đăng xuất hẳn', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (luaChon == 'khoa') {
        // KHÔNG xóa gì cả - giữ nguyên token/phiên đăng nhập, chỉ điều hướng
        // về màn khóa vân tay. Lần mở lại chỉ cần xác thực vân tay là vào
        // thẳng app, không cần đăng nhập lại từ đầu.
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const BiometricLockScreen()), (route) => false);
      } else if (luaChon == 'dang_xuat') {
        await FcmService.huyDangKy();
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
      return;
    }

    // Chưa bật vân tay -> hành vi cũ, đăng xuất thật, lần sau phải gõ mật khẩu
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi app?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    await FcmService.huyDangKy(); // PHẢI gọi trước khi xóa token, cần token còn hợp lệ
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  Future<void> _kiemTraCapNhat() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang kiểm tra phiên bản mới...')));
    final info = await VersionService.checkForUpdate();
    if (!mounted) return;
    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn đang dùng phiên bản mới nhất.')));
    } else {
      showDialog(context: context, barrierDismissible: !info.forceUpdate, builder: (_) => UpdateDialog(info: info));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(radius: 32, backgroundColor: AppTheme.viettelRed, child: Icon(Icons.person, color: Colors.white, size: 32)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_user['name'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_user['email'] ?? '', style: const TextStyle(color: Colors.grey)),
                        if ((_user['phone'] ?? '').isNotEmpty) Text(_user['phone']!, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: themeController,
                  builder: (context, _) => ListTile(
                    leading: const Icon(Icons.dark_mode, color: AppTheme.viettelRed),
                    title: const Text('Giao diện'),
                    subtitle: Text(switch (themeController.themeMode) {
                      ThemeMode.light => 'Sáng',
                      ThemeMode.dark => 'Tối',
                      ThemeMode.system => 'Theo hệ thống',
                    }),
                    onTap: _chonGiaoDien,
                  ),
                ),
                if (_coCamBienVanTay) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: AppTheme.viettelRed),
                    title: const Text('Đăng nhập bằng vân tay'),
                    subtitle: const Text('Mở app nhanh không cần gõ mật khẩu'),
                    value: _vanTayDangBat,
                    onChanged: _doiVanTay,
                    activeThumbColor: AppTheme.viettelRed,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update, color: AppTheme.viettelRed),
                  title: const Text('Kiểm tra cập nhật'),
                  subtitle: Text('Phiên bản hiện tại: $_versionName'),
                  onTap: _kiemTraCapNhat,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share, color: AppTheme.viettelRed),
                  title: const Text('Chia sẻ link cài app'),
                  subtitle: const Text('Gửi cho đồng nghiệp qua Zalo, tin nhắn...'),
                  onTap: () => Share.share('Cài đặt app Viettel Khu Vực Vĩnh Hưng tại đây: ${AppConfig.baseUrl}/tai-app.php'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.call, color: AppTheme.viettelRed),
                  title: const Text('Hỗ trợ: 0968888005'),
                  subtitle: const Text('Admin: Tăng Ngọc Thạch'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _dangXuat,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}
