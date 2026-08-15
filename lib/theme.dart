import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const Color viettelRed = Color(0xFFEE0033);
  static const Color viettelRedDark = Color(0xFFA8001F);
  static const Color viettelRedLight = Color(0xFFFF4D6D);
  static const Color bgLight = Color(0xFFF7F7FA); // xám rất nhạt, trung tính hơn be cũ - đỡ ám vàng khi đặt cạnh card trắng
  static const Color bgDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Chuyển trang MƯỢT ĐỒNG NHẤT trên MỌI nền tảng (trượt ngang kiểu iOS) -
  /// TRƯỚC ĐÂY dùng hiệu ứng mặc định của từng hệ điều hành (Android dùng
  /// zoom-fade, trông "giật cục" hơn) - đổi 1 chỗ NÀY áp dụng cho TOÀN BỘ
  /// `Navigator.push` trong app, không cần sửa từng màn hình.
  static const _chuyenTrangMuot = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static TextTheme _textTheme(Color mauChu) => TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: mauChu, letterSpacing: -.3),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: mauChu),
        bodyLarge: TextStyle(fontSize: 15, color: mauChu, height: 1.4),
        bodyMedium: TextStyle(fontSize: 13.5, color: mauChu, height: 1.4),
        labelLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: _chuyenTrangMuot,
        colorScheme: ColorScheme.fromSeed(seedColor: viettelRed, primary: viettelRed, brightness: Brightness.light),
        scaffoldBackgroundColor: bgLight,
        textTheme: _textTheme(Colors.black87),
        appBarTheme: const AppBarTheme(
          backgroundColor: viettelRed,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 3,
          shadowColor: Colors.black26,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: viettelRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shadowColor: viettelRed.withValues(alpha: .35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: viettelRed,
            side: const BorderSide(color: viettelRed, width: 1.3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: viettelRed, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: viettelRed,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(fontSize: 11.5),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: .06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey.shade100,
          selectedColor: viettelRed,
          labelStyle: const TextStyle(fontSize: 12.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1, space: 1),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.black87,
        ),
        fontFamily: 'Roboto', // Font mặc định Flutter đã hỗ trợ tốt tiếng Việt có dấu
      );

  /// Giao diện tối - GIỮ NGUYÊN màu đỏ thương hiệu Viettel làm điểm nhấn,
  /// chỉ đổi nền/chữ sang tông tối để đỡ chói mắt khi dùng ban đêm.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashFactory: InkSparkle.splashFactory,
        pageTransitionsTheme: _chuyenTrangMuot,
        colorScheme: ColorScheme.fromSeed(seedColor: viettelRed, primary: viettelRed, brightness: Brightness.dark),
        scaffoldBackgroundColor: bgDark,
        textTheme: _textTheme(Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: viettelRedDark,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 3,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: viettelRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: viettelRedLight,
            side: const BorderSide(color: viettelRedLight, width: 1.3),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceDark,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: viettelRedLight, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: viettelRed,
          unselectedItemColor: Colors.grey,
          backgroundColor: surfaceDark,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: surfaceDark,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          margin: EdgeInsets.zero,
        ),
        dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1, space: 1),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
