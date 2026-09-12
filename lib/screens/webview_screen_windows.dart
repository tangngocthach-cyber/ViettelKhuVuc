import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// PHIÊN BẢN WINDOWS của màn hình WebView dùng chung - viết RIÊNG vì
/// `webview_windows` (dùng lõi Edge WebView2 có sẵn trên Windows 10/11) có
/// API HOÀN TOÀN KHÁC `webview_flutter` (dùng cho Android): không có
/// `NavigationDelegate`/`addJavaScriptChannel` nhiều kênh như bên Android,
/// chỉ có DUY NHẤT 1 kênh `webMessage` chung cho mọi tin nhắn từ JavaScript.
///
/// GIẢI PHÁP CHO KÊNH JS: các trang PHP hiện có gọi thẳng
/// `FlutterViTri.postMessage(...)` và `FlutterChonViTriCamTu.postMessage(...)`
/// (đúng chuẩn API của webview_flutter bên Android) - trên Windows, các biến
/// global này KHÔNG TỒN TẠI. Để KHÔNG PHẢI SỬA CODE PHP, ta TIÊM (inject)
/// một đoạn JavaScript polyfill ngay sau khi trang tải xong, tạo ra 2 biến
/// giả `window.FlutterViTri` / `window.FlutterChonViTriCamTu` có cùng
/// phương thức `.postMessage()`, bên trong gọi
/// `window.chrome.webview.postMessage(...)` (API thật của WebView2) kèm tên
/// kênh để phân biệt khi nhận lại bên Dart.
///
/// GIỚI HẠN ĐÃ BIẾT (so với bản Android) - CẦN THEO DÕI THÊM QUA THỰC TẾ SỬ
/// DỤNG, chưa có môi trường Windows để tự kiểm thử trực tiếp:
///  - Chưa có cơ chế "bắt mạch" (watchdog) phát hiện trang treo trắng như
///    bản Android - PC thường có RAM dồi dào hơn điện thoại nên rủi ro treo
///    vì hết bộ nhớ thấp hơn nhiều, nhưng vẫn có thể xảy ra với mạng yếu.
///  - Lấy vị trí (GPS) qua geolocator trên Windows dùng Windows Location
///    Services - CHÍNH XÁC THẤP HƠN NHIỀU so với chip GPS điện thoại (có thể
///    chỉ định vị theo khu vực/thành phố dựa trên IP nếu máy không có phần
///    cứng định vị) - phù hợp để THAM KHẢO, không nên dùng cho việc chấm tọa
///    độ chính xác cao ngoài thực địa (vốn là việc của App điện thoại).
class WebViewScreenWindows extends StatefulWidget {
  final String url;
  final String title;
  const WebViewScreenWindows({super.key, required this.url, required this.title});

  @override
  State<WebViewScreenWindows> createState() => _WebViewScreenWindowsState();
}

class _WebViewScreenWindowsState extends State<WebViewScreenWindows> {
  final WebviewController _controller = WebviewController();
  bool _dangKhoiTao = true;
  bool _dangTai = true;
  bool _loiMang = false;
  bool _dangTaiFile = false;
  StreamSubscription? _subLoading;
  StreamSubscription? _subUrl;
  StreamSubscription? _subMessage;
  StreamSubscription? _subHistory;

  @override
  void initState() {
    super.initState();
    _khoiTao();
  }

  Future<void> _khoiTao() async {
    try {
      await _controller.initialize();

      // Theo dõi trạng thái tải trang
      _subLoading = _controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() => _dangTai = state == LoadingState.loading);
        if (state == LoadingState.navigationCompleted) {
          _tiemPolyfillJs();
        }
      });

      // Theo dõi URL để chặn điều hướng ra ngoài domain (tương đương
      // onNavigationRequest bên Android) - webview_windows KHÔNG có sự kiện
      // "trước khi điều hướng" (before-navigate) ở phiên bản hiện tại, nên
      // chỉ có thể phát hiện SAU KHI đã điều hướng rồi kiểm tra domain, sau
      // đó BẬT LẠI trang gốc nếu phát hiện đi lạc - chấp nhận được vì hành
      // vi vẫn đúng ý (không kẹt ở trang lạ), chỉ khác 1 nhịp rất ngắn.
      _subUrl = _controller.url.listen((url) => _kiemTraDieuHuong(url));

      // Nhận tin nhắn từ JS (đã qua polyfill ở trên) - phân biệt theo "channel"
      _subMessage = _controller.webMessage.listen(_xuLyTinNhanTuJs);

      await _controller.setBackgroundColor(Colors.white);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      setState(() => _dangKhoiTao = false);
      await _taiTrangCoDangNhap();
    } catch (e) {
      // Máy KHÔNG cài WebView2 Runtime (hiếm gặp trên Windows 10/11 bản cập
      // nhật đầy đủ vì Microsoft đã tích hợp sẵn từ 2021, nhưng máy cũ/bản
      // rút gọn có thể thiếu) - báo lỗi rõ ràng thay vì màn trắng khó hiểu.
      if (mounted) setState(() { _dangKhoiTao = false; _loiMang = true; });
    }
  }

  /// Tiêm polyfill để các trang PHP hiện có gọi FlutterViTri.postMessage(...)
  /// và FlutterChonViTriCamTu.postMessage(...) hoạt động được trên Windows
  /// mà KHÔNG CẦN SỬA CODE PHP - chuyển tiếp qua window.chrome.webview
  /// (API thật của WebView2) kèm tên kênh để Dart phân biệt khi nhận lại.
  Future<void> _tiemPolyfillJs() async {
    try {
      await _controller.executeScript('''
        if (window.chrome && window.chrome.webview && !window.__daTiemPolyfillFlutter) {
          window.__daTiemPolyfillFlutter = true;
          window.FlutterViTri = { postMessage: function(msg) {
            window.chrome.webview.postMessage(JSON.stringify({channel: 'FlutterViTri', data: msg}));
          }};
          window.FlutterChonViTriCamTu = { postMessage: function(msg) {
            window.chrome.webview.postMessage(JSON.stringify({channel: 'FlutterChonViTriCamTu', data: msg}));
          }};
        }
      ''');
    } catch (e) {
      // Trang chưa sẵn sàng nhận script (hiếm) - bỏ qua, không chặn hiển thị trang
    }
  }

  void _xuLyTinNhanTuJs(dynamic tinNhanTho) {
    try {
      final goi = jsonDecode(tinNhanTho is String ? tinNhanTho : jsonEncode(tinNhanTho));
      final channel = goi['channel'];
      final data = goi['data'];
      if (channel == 'FlutterViTri') {
        _layViTriChoWeb();
      } else if (channel == 'FlutterChonViTriCamTu') {
        _xacNhanViTriChamTu(data is String ? data : jsonEncode(data));
      }
    } catch (e) {
      // Tin nhắn không đúng định dạng mong đợi - bỏ qua an toàn
    }
  }

  Future<void> _layViTriChoWeb() async {
    try {
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
        await _controller.executeScript("window.loiViTriTuApp && window.loiViTriTuApp('Bạn chưa cấp quyền Vị trí cho ứng dụng trong Cài đặt Windows.');");
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        await _controller.executeScript("window.loiViTriTuApp && window.loiViTriTuApp('Vui lòng bật Dịch vụ định vị (Location Services) trong Cài đặt Windows.');");
        return;
      }
      final viTri = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      await _controller.executeScript('window.nhanViTriTuApp && window.nhanViTriTuApp(${viTri.latitude}, ${viTri.longitude});');
    } catch (e) {
      await _controller.executeScript("window.loiViTriTuApp && window.loiViTriTuApp('Không lấy được vị trí trên máy này.');");
    }
  }

  void _xacNhanViTriChamTu(String jsonChuoi) {
    try {
      final data = jsonDecode(jsonChuoi);
      if (data['thanh_cong'] == true) {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final lat = double.tryParse('${data['lat']}');
      final lng = double.tryParse('${data['lng']}');
      if (lat != null && lng != null && mounted) {
        Navigator.pop(context, {'lat': lat, 'lng': lng});
      }
    } catch (e) {
      // Dữ liệu gửi về không hợp lệ - bỏ qua
    }
  }

  /// Kiểm tra URL hiện tại có đi lạc khỏi domain của site không - nếu có,
  /// mở bằng trình duyệt ngoài (Edge/Chrome mặc định máy) rồi quay lại trang
  /// trước đó trong WebView (webview_windows chưa có API chặn TRƯỚC khi
  /// điều hướng như webview_flutter, chỉ phát hiện được SAU khi đã chuyển).
  bool _dangXuLyDieuHuongLa = false;
  Future<void> _kiemTraDieuHuong(String url) async {
    if (_dangXuLyDieuHuongLa) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final host = uri.host;
    final path = uri.path.toLowerCase();

    // Cùng danh sách/logic domain đã dùng ở bản Android - PHẢI khớp domain
    // CHÍNH XÁC (hoặc đúng subdomain), không dùng endsWith thô để tránh lỗ
    // hổng domain giả (xem ghi chú bảo mật ở webview_screen.dart bản Android).
    final laDomainCuaSite = host.isEmpty || host == 'viettelkhuvuc.com' || host.endsWith('.viettelkhuvuc.com');

    const duoiFileTai = ['.pdf', '.xlsx', '.xls', '.doc', '.docx', '.ppt', '.pptx', '.zip', '.csv', '.apk', '.rar', '.txt'];
    final laLinkTaiFile = path.contains('tai-xuong.php') || path.contains('download.php') || duoiFileTai.any((duoi) => path.endsWith(duoi));

    if (laLinkTaiFile) {
      _dangXuLyDieuHuongLa = true;
      await _moLinkTaiFileCoDangNhap(uri);
      await _controller.goBack();
      _dangXuLyDieuHuongLa = false;
      return;
    }

    if (!laDomainCuaSite) {
      _dangXuLyDieuHuongLa = true;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await _controller.goBack();
      _dangXuLyDieuHuongLa = false;
    }
  }

  Future<void> _moLinkTaiFileCoDangNhap(Uri uriGoc) async {
    if (_dangTaiFile) return;
    setState(() => _dangTaiFile = true);
    HttpClient? client;
    try {
      final ticket = await AuthService.getWebTicket();
      if (ticket == null) throw Exception('Không lấy được vé đăng nhập tạm - kiểm tra lại mạng.');
      final duongDanCanTai = uriGoc.path + (uriGoc.query.isNotEmpty ? '?${uriGoc.query}' : '');
      final urlQuaVe = Uri.parse('${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(duongDanCanTai)}');

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(urlQuaVe);
      final response = await request.close();
      if (response.statusCode != 200) throw Exception('Máy chủ trả về lỗi ${response.statusCode}.');

      final bytesBuilder = BytesBuilder();
      await for (final phanDoan in response) { bytesBuilder.add(phanDoan); }
      final duLieuFile = bytesBuilder.toBytes();
      if (duLieuFile.isEmpty) throw Exception('File tải về rỗng.');

      String tenFile = _layTenFileTuHeader(response.headers.value('content-disposition')) ?? _layTenFileTuUrl(uriGoc);
      final thuMucTam = await getTemporaryDirectory();
      final duongDanLuu = '${thuMucTam.path}\\$tenFile';
      await File(duongDanLuu).writeAsBytes(duLieuFile);

      if (!mounted) return;
      setState(() => _dangTaiFile = false);
      final ketQuaMo = await OpenFilex.open(duongDanLuu);
      if (ketQuaMo.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tải xong nhưng không mở được file: ${ketQuaMo.message}')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dangTaiFile = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tải được file, kiểm tra lại mạng và thử lại.')));
      }
    } finally {
      client?.close(force: true);
    }
  }

  String? _layTenFileTuHeader(String? header) {
    if (header == null) return null;
    final khopUtf8 = RegExp(r"filename\*=UTF-8''([^;]+)").firstMatch(header);
    if (khopUtf8 != null) {
      try { return Uri.decodeComponent(khopUtf8.group(1)!.trim()); } catch (e) {}
    }
    final khopThuong = RegExp(r'filename="?([^";]+)"?').firstMatch(header);
    return khopThuong?.group(1)?.trim();
  }

  String _layTenFileTuUrl(Uri uri) {
    final phanCuoi = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'tai-lieu';
    final coDuoiFile = RegExp(r'\.[a-zA-Z0-9]{2,5}$').hasMatch(phanCuoi);
    return coDuoiFile ? phanCuoi : '$phanCuoi.pdf';
  }

  Future<void> _taiTrangCoDangNhap() async {
    final ticket = await AuthService.getWebTicket();
    try {
      if (ticket != null) {
        final u = Uri.parse(widget.url);
        final urlQuaVe = '${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(u.path + (u.query.isNotEmpty ? "?${u.query}" : ""))}';
        await _controller.loadUrl(urlQuaVe);
      } else {
        await _controller.loadUrl(widget.url);
      }
      if (mounted) setState(() => _loiMang = false);
    } catch (e) {
      if (mounted) setState(() { _dangTai = false; _loiMang = true; });
    }
  }

  @override
  void dispose() {
    _subLoading?.cancel();
    _subUrl?.cancel();
    _subMessage?.cancel();
    _subHistory?.cancel();
    _controller.dispose();
    super.dispose();
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
            if (!_dangKhoiTao && !_loiMang) Webview(_controller),
            if (_dangKhoiTao || (_dangTai && !_loiMang))
              const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed)),
            if (_dangTaiFile)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.viettelRed),
                          SizedBox(height: 14),
                          Text('Đang tải file...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_loiMang)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('Không tải được trang - kiểm tra mạng Internet,\nhoặc máy thiếu Microsoft Edge WebView2 Runtime.'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () { setState(() => _loiMang = false); _taiTrangCoDangNhap(); }, child: const Text('Thử lại')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
