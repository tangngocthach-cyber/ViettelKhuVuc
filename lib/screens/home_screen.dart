import 'dart:async';
import 'package:flutter/material.dart';
import 'trangchu_tab.dart';
import 'congdong_tab.dart';
import 'chat/chat_list_screen.dart';
import 'account_tab.dart';
import 'webview_screen.dart';
import '../config.dart';
import '../services/chat_service.dart';
import '../services/connectivity_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabHienTai = 0;
  int _tongTinChuaDoc = 0;
  Timer? _timerChuaDoc;

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
    _capNhatSoTinChuaDoc();
    // Kiểm tra số tin chưa đọc định kỳ - để hiện chấm đỏ trên icon "Chat nội
    // bộ" kể cả khi đang KHÔNG ở tab Chat (VD đang xem Trang chủ/Cộng đồng)
    _timerChuaDoc = Timer.periodic(const Duration(seconds: 10), (_) => _capNhatSoTinChuaDoc());
  }

  @override
  void dispose() {
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
      body: Column(
        children: [
          // Banner "Đang ngoại tuyến" - hiện NGAY LẬP TỨC khi mất mạng, tự ẩn
          // khi có mạng trở lại, không cần vào lại app.
          AnimatedBuilder(
            animation: connectivityService,
            builder: (context, _) => connectivityService.dangOnline
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: const Text(
                      '📡 Đang ngoại tuyến - hiển thị dữ liệu đã lưu trước đó',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          Expanded(child: IndexedStack(index: _tabHienTai, children: _tabs)),
        ],
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
