import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// Màn hình dùng CHUNG cho MỌI module lấy dữ liệu từ website thật (Sản phẩm,
/// Tin tức, Chính sách, Diễn đàn, Tìm kiếm, Quay số, Bốc thăm...) - đúng yêu
/// cầu: KHÔNG dựng lại giao diện riêng, mở thẳng trang thật qua WebView.
///
/// QUAN TRỌNG: TỰ ĐỘNG xin 1 "vé" đăng nhập tạm rồi đi qua trang
/// app-session-login.php TRƯỚC khi vào URL đích - để có phiên đăng nhập web
/// thật giống hệt như đăng nhập tay (Diễn đàn, các trang cần đăng nhập mới
/// dùng được, không cần đăng nhập lại lần 2 trong app).
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _dangTai = true;
  bool _loiMang = false;
  bool _trangDaTaiXongLanNao = false; // reset mỗi khi bắt đầu tải trang mới

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _dangTai = true;
          _loiMang = false;
          _trangDaTaiXongLanNao = false;
        }),
        onPageFinished: (_) => setState(() {
          _dangTai = false;
          _trangDaTaiXongLanNao = true;
        }),
        onWebResourceError: (error) {
          // CHỈ báo lỗi toàn trang nếu trang CHÍNH chưa từng tải xong lần nào.
          // Nếu trang đã tải xong rồi (VD: bản đồ đã hiện ra), lỗi này chỉ là
          // 1 TÀI NGUYÊN PHỤ bị lỗi tạm (như 1 ô ảnh bản đồ/tile khi zoom) -
          // KHÔNG được che mất nội dung đã tải thành công (lỗi thật đã gặp:
          // bản đồ dùng hàng trăm ảnh tile nhỏ, chỉ 1 cái lỗi mạng thoáng qua
          // cũng đủ khiến toàn bộ bản đồ bị che bởi màn "mất mạng" sai lệch).
          if (!_trangDaTaiXongLanNao) {
            setState(() {
              _dangTai = false;
              _loiMang = true;
            });
          }
        },
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          final host = uri?.host ?? '';
          final path = (uri?.path ?? '').toLowerCase();

          // Link ra domain KHÁC (VD notebooklm.google.com) -> Google chặn nhúng,
          // mở bằng trình duyệt ngoài máy thay vì cố tải trong WebView.
          // LƯU Ý BẢO MẬT: PHẢI so khớp domain CHÍNH XÁC (hoặc đúng subdomain có
          // dấu chấm ở trước) - dùng endsWith('viettelkhuvuc.com') trước đây là
          // SAI vì domain giả như "xviettelkhuvuc.com" (không có dấu chấm) cũng
          // khớp điều kiện đó, cho phép trang lạ chạy JavaScript không giới hạn
          // trong WebView và lợi dụng luồng "vé" đăng nhập tạm.
          final laDomainCuaSite = host.isEmpty || host == 'viettelkhuvuc.com' || host.endsWith('.viettelkhuvuc.com');

          // Link TẢI FILE (dù cùng domain) -> WebView của Flutter KHÔNG tự tải
          // file được (không có "Download Manager" như trình duyệt thường), nên
          // phải giao cho trình duyệt ngoài máy tải và lưu đúng vào máy.
          const duoiFileTai = ['.pdf', '.xlsx', '.xls', '.doc', '.docx', '.ppt', '.pptx', '.zip', '.csv', '.apk'];
          final laLinkTaiFile = path.contains('tai-lieu-tai-xuong.php') || duoiFileTai.any((duoi) => path.endsWith(duoi));

          if (!laDomainCuaSite || laLinkTaiFile) {
            if (uri != null) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      // Kênh giao tiếp JS -> Flutter: trang Bản đồ Hộp cáp gọi qua kênh này
      // để NHỜ FLUTTER lấy vị trí bằng thư viện native (geolocator), thay vì
      // dùng navigator.geolocation của chính WebView - đã xác nhận thực tế
      // KHÔNG đáng tin cậy trên WebView (dù app đã được cấp đủ quyền Vị trí ở
      // Cài đặt máy, WebView vẫn báo "chưa cho phép" trong khi mở CÙNG trang
      // bằng trình duyệt thường lại chạy đúng - đây là hạn chế riêng của
      // WebView, không phải thiếu quyền hay sai code trang web).
      ..addJavaScriptChannel('FlutterViTri', onMessageReceived: (_) => _layViTriChoWeb())
      // Kênh riêng cho trang "Chọn vị trí Chấm tủ trên bản đồ" - khi người
      // dùng chạm bản đồ chọn xong vị trí và bấm Xác nhận, trang web gọi qua
      // kênh này gửi tọa độ về, Flutter nhận và ĐÓNG màn WebView luôn, trả
      // kết quả về cho màn Chấm tủ phía trên (không cần thêm màn hình riêng).
      ..addJavaScriptChannel('FlutterChonViTriCamTu', onMessageReceived: (msg) => _xacNhanViTriChamTu(msg.message));

    // Bật navigator.geolocation cho WebView - dùng làm PHƯƠNG ÁN DỰ PHÒNG nếu
    // trang được mở ngoài app (trình duyệt thường), không phải đường chính.
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setGeolocationEnabled(true);
    }

    _taiTrangCoDangNhap();
  }

  /// Lấy vị trí bằng thư viện geolocator NATIVE (giống hệt cách tính năng
  /// chia sẻ vị trí trong Chat đang dùng, đã kiểm chứng chạy tốt trên máy
  /// thật) rồi gửi kết quả VÀO LẠI trang web qua JavaScript.
  Future<void> _layViTriChoWeb() async {
    try {
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
        _controller.runJavaScript("window.loiViTriTuApp && window.loiViTriTuApp('Bạn chưa cấp quyền Vị trí cho app.');");
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _controller.runJavaScript("window.loiViTriTuApp && window.loiViTriTuApp('Vui lòng bật định vị (GPS) trên máy.');");
        return;
      }
      final viTri = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      _controller.runJavaScript('window.nhanViTriTuApp && window.nhanViTriTuApp(${viTri.latitude}, ${viTri.longitude});');
    } catch (e) {
      _controller.runJavaScript("window.loiViTriTuApp && window.loiViTriTuApp('Không lấy được vị trí, kiểm tra lại GPS.');");
    }
  }

  /// Trang "Chọn vị trí Chấm tủ" gửi tọa độ đã chạm chọn về qua đây - đóng
  /// luôn màn WebView và trả kết quả {lat, lng} về cho màn Chấm tủ.
  void _xacNhanViTriChamTu(String jsonChuoi) {
    try {
      final data = jsonDecode(jsonChuoi);
      final lat = double.tryParse('${data['lat']}');
      final lng = double.tryParse('${data['lng']}');
      if (lat != null && lng != null && mounted) {
        Navigator.pop(context, {'lat': lat, 'lng': lng});
      }
    } catch (e) {
      // Dữ liệu gửi về không hợp lệ - bỏ qua, người dùng có thể thử chọn lại
    }
  }

  Future<void> _taiTrangCoDangNhap() async {
    // Trang Bản đồ Hộp cáp GPON cần quyền định vị - CHỦ ĐỘNG xin bằng hộp
    // thoại hệ thống chuẩn TRƯỚC khi vào trang. Chỉ khai báo quyền trong
    // AndroidManifest.xml là CHƯA ĐỦ - từ Android 6.0 trở lên bắt buộc phải
    // xin cấp quyền lúc app đang chạy mới thật sự có quyền, nếu không WebView
    // sẽ luôn báo "chưa cho phép truy cập vị trí" dù người dùng có bật định vị
    // ngoài Cài đặt máy đi nữa (lỗi thật đã gặp).
    if (widget.url.contains('ban-do-hop-cap')) {
      final ketQua = await Permission.location.request();
      // QUAN TRỌNG: nếu người dùng đã bấm "Từ chối" ở LẦN THỬ TRƯỚC (trước khi
      // có tính năng xin quyền này), Android tự chuyển sang "từ chối VĨNH
      // VIỄN" - gọi request() lần nữa sẽ KHÔNG hiện hộp thoại nào cả, chỉ âm
      // thầm trả về denied/permanentlyDenied. Lúc này CHỈ CÓ CÁCH duy nhất là
      // dẫn thẳng người dùng vào đúng màn Cài đặt quyền của app để tự bật tay.
      if (ketQua.isPermanentlyDenied && mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cần quyền Vị trí'),
            content: const Text(
              'App đã từng bị từ chối quyền Vị trí ở lần trước, nên Android sẽ '
              'không tự hỏi lại nữa. Bấm "Mở Cài đặt" bên dưới, chọn mục '
              '"Quyền" (Permissions) → "Vị trí" (Location) → chọn "Cho phép".',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Để sau')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Mở Cài đặt'),
              ),
            ],
          ),
        );
      }
    }

    // QUAN TRỌNG - lý do có lỗi thật đã gặp: mỗi lần mở màn này, server tạo
    // PHIÊN ĐĂNG NHẬP MỚI HOÀN TOÀN (app-session-login.php gọi
    // session_regenerate_id() - đổi cả session lẫn CSRF token). Nếu WebView
    // dùng lại HTML đã cache từ lần mở TRƯỚC (mang CSRF token của phiên CŨ),
    // token đó sẽ LỆCH với phiên MỚI trên server -> mọi form/API cần CSRF
    // (như khung "Hỏi đáp tự động") bị từ chối ÂM THẦM, trông như "không hoạt
    // động" dù không có lỗi hiển thị rõ ràng. Xóa cache TRƯỚC khi tải đảm bảo
    // luôn lấy HTML mới nhất, khớp đúng phiên mới nhất.
    await _controller.clearCache();

    final ticket = await AuthService.getWebTicket();
    if (ticket != null) {
      final urlQuaVe = '${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(Uri.parse(widget.url).path + (Uri.parse(widget.url).query.isNotEmpty ? "?${Uri.parse(widget.url).query}" : ""))}';
      _controller.loadRequest(Uri.parse(urlQuaVe));
    } else {
      // Không xin được vé (VD mất mạng) - vẫn mở trang thường, chỉ là chưa có phiên đăng nhập web
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload()),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (!_loiMang) WebViewWidget(controller: _controller),
            if (_dangTai && !_loiMang) const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed)),
            if (_loiMang)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Không tải được trang, kiểm tra lại mạng Internet.'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _taiTrangCoDangNhap, child: const Text('Thử lại')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
