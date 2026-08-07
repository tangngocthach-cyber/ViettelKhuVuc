import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
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
  bool _dangTaiFile = false; // đang tải file tài liệu về máy - hiện overlay loading riêng
  bool _trangDaTaiXongLanNao = false; // reset mỗi khi bắt đầu tải trang mới
  Timer? _watchdogTimer; // "bắt mạch" trang định kỳ - phát hiện trang bị treo trắng để tự tải lại
  int _watchdogLoiLienTiep = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _dungWatchdog(); // tạm ngưng "bắt mạch" trong lúc đang chuyển trang, tránh báo nhầm
          setState(() {
            _dangTai = true;
            _loiMang = false;
            _trangDaTaiXongLanNao = false;
          });
        },
        onPageFinished: (_) {
          setState(() {
            _dangTai = false;
            _trangDaTaiXongLanNao = true;
          });
          _batDauWatchdog();
        },
        onWebResourceError: (error) {
          // SỬA LỖI THẬT ĐÃ GẶP: trước đây chỉ kiểm tra "trang đã từng tải
          // xong lần nào chưa" - nhưng ngay sau khi tự tải lại (watchdog),
          // trong khoảng thời gian ĐANG tải lại (trước khi tải xong lần
          // MỚI này), NẾU có bất kỳ 1 tài nguyên phụ nào lỗi (1 file script,
          // 1 lệnh gọi API bên trong trang, 1 ô ảnh bản đồ...) thì cờ "đã
          // tải xong" vẫn đang là false -> bị hiểu NHẦM thành "toàn trang
          // mất mạng", che mất nội dung trang CHÍNH dù nó có thể vẫn đang
          // tải bình thường. Dùng thêm isForMainFrame - CHỈ coi là lỗi toàn
          // trang khi lỗi xảy ra đúng cho bản thân trang chính, không phải
          // 1 tài nguyên phụ bên trong.
          final loiToanTrang = error.isForMainFrame ?? true;
          if (loiToanTrang && !_trangDaTaiXongLanNao) {
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
          // phải tự tải trong app rồi mở bằng OpenFilex.
          //
          // LỖI THẬT ĐÃ GẶP (lần 2): trước đây CHỈ nhận diện đúng tên file
          // "tai-lieu-tai-xuong.php" - nhưng hệ thống có NHIỀU trang tải file
          // khác theo cùng quy ước đặt tên (VD "excel-tai-xuong.php" ở Kho Dữ
          // liệu bán hàng) mà KHÔNG khớp điều kiện cũ, khiến các trang đó rơi
          // vào nhánh "mở như trang web thường" - WebView cố hiển thị file
          // Excel/PDF như 1 trang HTML, KHÔNG PHẢN HỒI GÌ (không lỗi, không
          // tải - im lặng thất bại, đúng hiện tượng đã gặp).
          //
          // SỬA DỨT ĐIỂM: nhận diện theo QUY ƯỚC CHUNG "...tai-xuong.php"
          // (mọi trang tải file trong hệ thống này đều đặt tên theo mẫu này)
          // - áp dụng cho MỌI trang hiện có VÀ tương lai cùng quy ước, không
          // cần liệt kê từng tên cụ thể nữa.
          const duoiFileTai = ['.pdf', '.xlsx', '.xls', '.doc', '.docx', '.ppt', '.pptx', '.zip', '.csv', '.apk', '.rar', '.txt'];
          final laLinkTaiFile = path.contains('tai-xuong.php') || path.contains('download.php') || duoiFileTai.any((duoi) => path.endsWith(duoi));

          if (laLinkTaiFile) {
            _moLinkTaiFileCoDangNhap(uri);
            return NavigationDecision.prevent;
          }

          if (!laDomainCuaSite) {
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

  /// Nhận tín hiệu từ 2 trang khác nhau qua CHUNG 1 kênh:
  /// - Trang "Chọn vị trí đơn giản" (dùng khi Sửa) gửi {lat, lng} - đóng màn
  ///   và trả tọa độ về cho form Flutter tự điền vào.
  /// - Trang "Chấm tủ đầy đủ trên bản đồ" (dùng khi Tạo mới) gửi {thanh_cong:
  ///   true} SAU KHI đã tự lưu xong toàn bộ (loại tủ, ảnh, ghi chú) - đóng
  ///   màn và báo cho màn danh sách biết để tự tải lại, không cần trả tọa độ
  ///   gì nữa vì đã lưu xong hết rồi.
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
      // Dữ liệu gửi về không hợp lệ - bỏ qua, người dùng có thể thử lại
    }
  }

  /// Tải file tài liệu (Tài liệu, Kho Dữ liệu bán hàng...) TRỰC TIẾP TRONG
  /// APP - không còn mở bằng trình duyệt ngoài máy (Chrome) như trước.
  ///
  /// LỖI THẬT ĐÃ GẶP với cách làm cũ (mở trình duyệt ngoài): Chrome có bộ
  /// nhớ đệm/cookie RIÊNG, độc lập với WebView - mỗi lần tải, app xin 1 vé
  /// đăng nhập MỚI, nhưng nếu Chrome đã lưu cookie/trang từ LẦN TRƯỚC (dù đã
  /// hết hạn), nó có thể ưu tiên dùng lại cache cũ thay vì xử lý vé mới,
  /// khiến tải LẶP LẠI bị lỗi mỗi khi thoát vào lại - không ổn định.
  ///
  /// CÁCH SỬA TRIỆT ĐỂ: dùng HttpClient RIÊNG cho MỖI LẦN tải (tạo mới và
  /// hủy ngay sau khi xong) - tự động giữ cookie xuyên suốt CHUỖI CHUYỂN
  /// HƯỚNG (vé -> phiên đăng nhập được thiết lập -> file thật) trong CÙNG 1
  /// lần gọi, không còn phụ thuộc bộ nhớ đệm của bất kỳ trình duyệt nào.
  Future<void> _moLinkTaiFileCoDangNhap(Uri? uriGoc) async {
    if (uriGoc == null || _dangTaiFile) return;
    setState(() => _dangTaiFile = true);
    HttpClient? client;
    try {
      final ticket = await AuthService.getWebTicket();
      if (ticket == null) {
        throw Exception('Không lấy được vé đăng nhập tạm - kiểm tra lại mạng.');
      }
      final duongDanCanTai = uriGoc.path + (uriGoc.query.isNotEmpty ? '?${uriGoc.query}' : '');
      final urlQuaVe = Uri.parse('${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(duongDanCanTai)}');

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 20);
      final request = await client.getUrl(urlQuaVe);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Máy chủ trả về lỗi ${response.statusCode}, không tải được file.');
      }

      // Đọc toàn bộ nội dung file vào bộ nhớ - đủ dùng cho tài liệu/Excel
      // thông thường (không phải video/file cực lớn).
      final bytesBuilder = BytesBuilder();
      await for (final phanDoan in response) {
        bytesBuilder.add(phanDoan);
      }
      final duLieuFile = bytesBuilder.toBytes();
      if (duLieuFile.isEmpty) {
        throw Exception('File tải về rỗng, có thể đã hết hạn hoặc không tồn tại.');
      }

      // Lấy TÊN FILE thật từ header Content-Disposition server trả về (nếu
      // có) - QUAN TRỌNG để giữ đúng phần đuôi file (.xlsx/.pdf/...), nhờ đó
      // OpenFilex mới biết mở bằng đúng ứng dụng tương ứng.
      String tenFile = _layTenFileTuHeader(response.headers.value('content-disposition')) ?? _layTenFileTuUrl(uriGoc);

      final thuMucTam = await getTemporaryDirectory();
      final duongDanLuu = '${thuMucTam.path}/$tenFile';
      final fileDaLuu = File(duongDanLuu);
      await fileDaLuu.writeAsBytes(duLieuFile);

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

  /// Đọc tên file từ header Content-Disposition dạng: attachment;
  /// filename="ten-file.xlsx" hoặc filename*=UTF-8''ten-file.xlsx
  String? _layTenFileTuHeader(String? header) {
    if (header == null) return null;
    final khopUtf8 = RegExp(r"filename\*=UTF-8''([^;]+)").firstMatch(header);
    if (khopUtf8 != null) {
      try {
        return Uri.decodeComponent(khopUtf8.group(1)!.trim());
      } catch (e) {
        // giải mã lỗi thì thử cách khác bên dưới
      }
    }
    final khopThuong = RegExp(r'filename="?([^";]+)"?').firstMatch(header);
    return khopThuong?.group(1)?.trim();
  }

  /// Dự phòng khi không có tên file trong header - lấy từ đoạn cuối URL,
  /// đảm bảo LUÔN có phần đuôi file hợp lệ để OpenFilex mở đúng ứng dụng.
  String _layTenFileTuUrl(Uri uri) {
    final phanCuoi = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'tai-lieu';
    final coDuoiFile = RegExp(r'\.[a-zA-Z0-9]{2,5}$').hasMatch(phanCuoi);
    return coDuoiFile ? phanCuoi : '$phanCuoi.pdf';
  }

  // ==========================================================================
  // "BẮT MẠCH" TRANG - PHÁT HIỆN TRANG BỊ TREO TRẮNG ĐỂ TỰ TẢI LẠI
  // ==========================================================================
  // LỖI THẬT ĐÃ GẶP: bản đồ Vệ tinh (ảnh chụp Esri) tải RẤT NẶNG so với bản
  // đồ thường - trên điện thoại RAM thấp/trung bình, việc này có thể khiến
  // TIẾN TRÌNH HIỂN THỊ (render process) của WebView trên Android bị hệ điều
  // hành TỰ NGẮT vì hết bộ nhớ. Khi đó toàn trang biến thành MÀN TRẮNG ĐỨNG
  // YÊN - không phải lỗi mạng (onWebResourceError KHÔNG bắt được trường hợp
  // này, vì đây là tiến trình con của hệ điều hành bị ngắt, không phải 1 yêu
  // cầu mạng bị lỗi). Gói webview_flutter hiện TẠI THỜI ĐIỂM NÀY CHƯA hỗ trợ
  // sự kiện chính thức "tiến trình đã chết" trên Android (chưa có API
  // onRenderProcessGone như bên Android WebView gốc), nên phải tự dò bằng
  // cách chạy 1 đoạn JavaScript siêu nhẹ định kỳ và chờ phản hồi - nếu trang
  // còn sống, JS luôn trả lời trong tích tắc; nếu tiến trình đã chết, lệnh
  // này sẽ treo vô thời hạn (bắt bằng .timeout).
  void _batDauWatchdog() {
    _dungWatchdog();
    _watchdogLoiLienTiep = 0;
    _watchdogTimer = Timer.periodic(const Duration(seconds: 6), (_) => _kiemTraTrangConSong());
  }

  void _dungWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _kiemTraTrangConSong() async {
    if (!mounted || _dangTai || _loiMang || _dangTaiFile) return;
    try {
      await _controller.runJavaScriptReturningResult('1+1').timeout(const Duration(seconds: 5));
      _watchdogLoiLienTiep = 0;
    } catch (e) {
      _watchdogLoiLienTiep++;
      // Chờ đủ 2 lần liên tiếp không phản hồi (khoảng 12 giây) mới kết luận
      // treo thật - tránh tải lại nhầm chỉ vì 1 lần chậm thoáng qua.
      if (_watchdogLoiLienTiep >= 2 && mounted) {
        _watchdogLoiLienTiep = 0;
        _dungWatchdog();
        // GHI CHÚ: từng thử ép Flutter hủy/dựng lại hẳn bề mặt hiển thị
        // WebView (đổi key) mỗi lần phát hiện treo, với kỳ vọng dọn sạch
        // trạng thái dở dang. ĐÃ GỠ BỎ LẠI: sau khi thêm, tình trạng lỗi
        // hiển thị lan sang CẢ MÀN HÌNH KHỞI ĐỘNG THUẦN FLUTTER (không
        // liên quan WebView) - dấu hiệu việc hủy/dựng lại lặp lại nhiều
        // lần đang làm RÒ RỈ tài nguyên đồ họa thay vì dọn sạch nó. Quay
        // lại cách đơn giản, an toàn hơn: chỉ tải lại nội dung trên CÙNG
        // 1 bề mặt hiển thị, không hủy/dựng lại.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trang bị treo, đang tự tải lại...')),
        );
        _taiTrangCoDangNhap();
      }
    }
  }

  @override
  void dispose() {
    _dungWatchdog();
    super.dispose();
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
