import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color viettelRed = Color(0xFFEE0033);
  static const Color viettelRedDark = Color(0xFFA8001F);
  static const Color bgLight = Color(0xFFF8F6F4);
  static const Color bgDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: viettelRed, primary: viettelRed, brightness: Brightness.light),
        scaffoldBackgroundColor: bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: viettelRed,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: viettelRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: viettelRed,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        fontFamily: 'Roboto', // Font mặc định Flutter đã hỗ trợ tốt tiếng Việt có dấu
      );

  /// Giao diện tối - GIỮ NGUYÊN màu đỏ thương hiệu Viettel làm điểm nhấn,
  /// chỉ đổi nền/chữ sang tông tối để đỡ chói mắt khi dùng ban đêm.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: viettelRed, primary: viettelRed, brightness: Brightness.dark),
        scaffoldBackgroundColor: bgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: viettelRedDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: viettelRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: viettelRed,
          unselectedItemColor: Colors.grey,
          backgroundColor: surfaceDark,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        fontFamily: 'Roboto',
      );
}

/// Quản lý chế độ giao diện (Sáng / Tối / Theo hệ thống) - dùng ChangeNotifier
/// để MaterialApp tự vẽ lại NGAY khi người dùng đổi, không cần khởi động lại
/// app. Tự lưu lựa chọn vào SharedPreferences để lần mở app sau vẫn giữ đúng.
/// Instance DÙNG CHUNG toàn app - account_tab.dart gọi themeController.doiCheDo()
/// để đổi giao diện, main.dart lắng nghe để vẽ lại MaterialApp ngay lập tức.
final themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  static const _khoaLuu = 'che_do_giao_dien';
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> khoiTao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final luu = prefs.getString(_khoaLuu);
      if (luu == 'light') _themeMode = ThemeMode.light;
      if (luu == 'dark') _themeMode = ThemeMode.dark;
      notifyListeners();
    } catch (e) {
      // Đọc lỗi thì giữ mặc định "theo hệ thống", không sao cả
    }
  }

  Future<void> doiCheDo(ThemeMode moi) async {
    _themeMode = moi;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_khoaLuu, moi == ThemeMode.light ? 'light' : moi == ThemeMode.dark ? 'dark' : 'system');
    } catch (e) {
      // Lưu lỗi thì thôi, lần sau mở lại app vẫn dùng lại được nhờ notifyListeners() ở trên
    }
  }
}

/// Bật/tắt nút nổi "Hỏi đáp" trên Trang chủ - một số người thấy nút này che
/// khuất tầm nhìn khi không cần dùng tới, cho phép tự tắt đi. Mặc định BẬT
/// (giữ nguyên trải nghiệm cũ cho người chưa từng đổi cài đặt này).
final hoiDapBubbleController = HoiDapBubbleController();

class HoiDapBubbleController extends ChangeNotifier {
  static const _khoaLuu = 'hien_nut_hoi_dap';
  bool _hienThi = true;
  bool get hienThi => _hienThi;

  Future<void> khoiTao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hienThi = prefs.getBool(_khoaLuu) ?? true;
      notifyListeners();
    } catch (e) {
      // Đọc lỗi thì giữ mặc định BẬT, không sao cả
    }
  }

  Future<void> doiTrangThai(bool moi) async {
    _hienThi = moi;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_khoaLuu, moi);
    } catch (e) {
      // Lưu lỗi thì thôi, lần sau mở lại app vẫn dùng được nhờ notifyListeners() ở trên
    }
  }
}
