import 'package:flutter/material.dart';
import 'trangchu_tab.dart';
import 'congdong_tab.dart';
import 'chat/chat_list_screen.dart';
import 'account_tab.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabHienTai = 0;

  // Dùng IndexedStack để giữ trạng thái từng tab khi chuyển qua lại (VD Chat
  // không bị load lại danh sách hội thoại mỗi lần chuyển tab)
  final _tabs = const [
    TrangChuTab(),
    CongDongTab(),
    ChatListScreen(),
    TaiKhoanTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabHienTai, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabHienTai,
        onTap: (i) => setState(() => _tabHienTai = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), activeIcon: Icon(Icons.groups), label: 'Cộng đồng'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat nội bộ'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
