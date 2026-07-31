import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/version_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'update_dialog.dart';

class TaiKhoanTab extends StatefulWidget {
  const TaiKhoanTab({super.key});

  @override
  State<TaiKhoanTab> createState() => _TaiKhoanTabState();
}

class _TaiKhoanTabState extends State<TaiKhoanTab> {
  Map<String, String> _user = {};
  String _versionName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.getCurrentUser();
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _user = user;
      _versionName = info.version;
    });
  }

  Future<void> _dangXuat() async {
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
