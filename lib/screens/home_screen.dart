import 'dart:async';
import 'package:flutter/material.dart';
import 'trangchu_tab.dart';
import 'congdong_tab.dart';
import 'chat/chat_list_screen.dart';
import 'account_tab.dart';
import 'biometric_lock_screen.dart';
import 'webview_screen.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/fcm_service.dart';
import '../services/connectivity_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tabHienTai = 0;
  int _tongTinChuaDoc = 0;
  Timer? _timerChuaDoc;

  // TỰ KHÓA LẠI khi để app ở nền quá lâu (chỉ áp dụng nếu đã bật vân tay):
  // trước đây chỉ khóa lúc MỞ APP LẦN ĐẦU - để máy ở bàn, người khác mở lại
  // app từ đa nhiệm là vào thẳng dữ liệu nội bộ, Chat.
  static const _thoiGianTuKhoa = Duration(minutes: 3);
  DateTime? _vaoNenLuc;
  bool _dangKhoa = false;

  // Dùng IndexedStack để giữ trạng thái từng tab khi chuyển qua lại (VD Chat
  // không bị load lại danh sách hội thoại mỗi lần chuyển tab)
  final _tabs = const [
    TrangChuTab(),
    CongDongTab(),
    ChatListScreen(),
    TaiKhoanTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FcmService.datSanSangMoThongBao(true); // đã qua màn khóa - được mở Chat từ thông báo
    _capNhatSoTinChuaDoc();
    _batDemChuaDoc();
  }

  /// Kiểm tra số tin chưa đọc định kỳ - để hiện chấm đỏ trên icon "Chat nội
  /// bộ" kể cả khi đang KHÔNG ở tab Chat (VD đang xem Trang chủ/Cộng đồng).
  void _batDemChuaDoc() {
    _timerChuaDoc?.cancel();
    _timerChuaDoc = Timer.periodic(const Duration(seconds: 10), (_) => _capNhatSoTinChuaDoc());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // TIẾT KIỆM PIN & DỮ LIỆU: trước đây vẫn gọi máy chủ mỗi 10 giây kể cả
      // khi app đang ở nền/tắt màn hình. Nay dừng hẳn, mở lại mới chạy tiếp.
      _vaoNenLuc ??= DateTime.now();
      _timerChuaDoc?.cancel();
      _timerChuaDoc = null;
    } else if (state == AppLifecycleState.resumed) {
      final luc = _vaoNenLuc;
      _vaoNenLuc = null;
      _capNhatSoTinChuaDoc();
      _batDemChuaDoc();
      if (luc != null && DateTime.now().difference(luc) >= _thoiGianTuKhoa) {
        _khoaLaiNeuCan();
      }
    }
  }

  Future<void> _khoaLaiNeuCan() async {
    if (_dangKhoa || !mounted) return;
    if (!await AuthService.isBiometricEnabled()) return;
    if (!mounted || _dangKhoa) return;
    _dangKhoa = true;
    FcmService.datSanSangMoThongBao(false);
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const BiometricLockScreen(moKhoaTaiCho: true)),
    );
    _dangKhoa = false;
    if (mounted) FcmService.datSanSangMoThongBao(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FcmService.datSanSangMoThongBao(false);
    _timerChuaDoc?.cancel();
    super.dispose();
  }

  Future<void> _capNhatSoTinChuaDoc() async {
    try {
      final ds = await ChatService.getConversations();
      final tong = ds.fold<int>(0, (a, c) => a + c.soTinChuaDoc);
      if (mounted) setState(() => _tongTinChuaDoc = tong);
    } catch (e) {
      // Lỗi mạng tạm thời - bỏ qua, thử lại ở lần định kỳ kế tiếp
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Banner "Đang ngoại tuyến" - hiện NGAY LẬP TỨC khi mất mạng, tự ẩn khi
      // có mạng trở lại. SỬA LỖI HIỂN THỊ: banner cũ nằm ĐÈ dưới thanh trạng
      // thái (giờ, pin) nên bị che chữ; nay chừa đúng khoảng thanh trạng thái
      // và trừ phần đó ở nội dung bên dưới để không bị hở 2 lần.
      // LƯU Ý: luôn bọc IndexedStack trong CÙNG 1 kiểu widget (MediaQuery)
      // dù có/không có banner - đổi kiểu widget cha sẽ làm các tab mất trạng
      // thái (tải lại từ đầu) mỗi lần mạng chập chờn.
      body: AnimatedBuilder(
        animation: connectivityService,
        builder: (context, _) {
          final ngoaiTuyen = !connectivityService.dangOnline;
          return Column(
            children: [
              if (ngoaiTuyen)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade800,
                  padding: EdgeInsets.fromLTRB(12, MediaQuery.paddingOf(context).top + 6, 12, 7),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Đang ngoại tuyến - hiển thị dữ liệu đã lưu trước đó',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                key: const ValueKey('noi-dung-cac-tab'),
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: ngoaiTuyen,
                  child: IndexedStack(index: _tabHienTai, children: _tabs),
                ),
              ),
            ],
          );
        },
      ),
      // Nút nổi Trợ lý AI - bấm vào đâu, lúc nào cũng gọi được, không cần
      // chui vào tận tab Cộng đồng mới thấy. Ẩn ở tab Chat nội bộ (index 2)
      // vì nút nổi dễ che mất khung soạn tin nhắn ở đó. Cũng ẩn nếu người
      // dùng đã tự TẮT trong Tài khoản > Cài đặt (đỡ che tầm nhìn khi không cần).
      floatingActionButton: AnimatedBuilder(
        animation: hoiDapBubbleController,
        builder: (context, _) {
          if (_tabHienTai == 2 || !hoiDapBubbleController.hienThi) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WebViewScreen(url: AppConfig.urlHoiDap, title: 'Hỏi đáp tự động')),
            ),
            backgroundColor: AppTheme.viettelRed,
            icon: const Icon(Icons.chat_bubble, color: Colors.white),
            label: const Text('Hỏi đáp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabHienTai,
        onTap: (i) {
          setState(() => _tabHienTai = i);
          if (i == 2) _capNhatSoTinChuaDoc(); // vào tab Chat -> cập nhật lại ngay
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
          const BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Cộng đồng'),
          BottomNavigationBarItem(
            icon: _iconChatCoBadge(Icons.chat_bubble_outline),
            activeIcon: _iconChatCoBadge(Icons.chat_bubble),
            label: 'Chat nội bộ',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }

  Widget _iconChatCoBadge(IconData icon) {
    if (_tongTinChuaDoc <= 0) return Icon(icon);
    return Badge(
      label: Text(_tongTinChuaDoc > 99 ? '99+' : '$_tongTinChuaDoc'),
      backgroundColor: AppTheme.viettelRed,
      child: Icon(icon),
    );
  }
}
