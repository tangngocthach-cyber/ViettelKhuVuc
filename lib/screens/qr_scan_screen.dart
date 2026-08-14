import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/catalog_service.dart';
import '../theme.dart';

/// Quét mã QR/vạch bằng camera (sản phẩm, hợp đồng...). Sau khi quét được:
/// - Luôn cho sao chép nội dung thô
/// - Nếu nội dung là link (http/https) -> cho mở bằng trình duyệt ngoài
/// - Tự dò trong dữ liệu sản phẩm ĐÃ TẢI SẴN (offline cache) xem có khớp
///   không, so khớp CHUỖI THÔ trên toàn bộ dữ liệu - KHÔNG phụ thuộc biết
///   trước tên trường cụ thể nào trong CSDL thật, an toàn dù cấu trúc dữ
///   liệu sản phẩm thay đổi sau này.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with WidgetsBindingObserver {
  // autoStart: false - KHÔNG để plugin tự khởi động camera NGAY LÚC TẠO
  // controller (đúng lúc widget vừa dựng, platform view/texture Android có
  // thể CHƯA gắn xong) - đây là nguyên nhân hay gặp của lỗi native
  // "getClass() on a null object reference" (camera provider null vì được
  // gọi quá sớm). Tự gọi start() thủ công SAU KHI khung hình đầu tiên đã
  // dựng xong (`addPostFrameCallback`), bọc try/catch để không văng lỗi
  // cứng nếu camera vẫn lỗi vì lý do khác.
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, autoStart: false);
  bool _dangXuLy = false; // chặn quét trùng liên tục trong lúc đang hiện kết quả

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _khoiDongCameraAnToan());
  }

  Future<void> _khoiDongCameraAnToan() async {
    try {
      await _controller.start();
    } catch (_) {
      // Lỗi đã được `errorBuilder` của MobileScanner tự bắt và hiện ra màn
      // hình cho người dùng rồi (kèm nút "Thử lại") - không cần xử lý thêm
      // gì ở đây, chỉ cần không để exception này làm crash cả app.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Chủ động DỪNG camera khi app chuyển xuống nền, KHỞI ĐỘNG LẠI khi quay
  /// lại - đúng khuyến nghị chính thức của mobile_scanner. Bỏ qua bước này dễ
  /// khiến camera bị "kẹt" trạng thái lỗi trên một số máy (đặc biệt Xiaomi/
  /// MIUI), gây lỗi native Camera2/CameraX như đã gặp thực tế.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _khoiDongCameraAnToan();
    }
  }

  Future<void> _khiQuetDuoc(BarcodeCapture capture) async {
    if (_dangXuLy) return;
    if (capture.barcodes.isEmpty) return;
    final ma = capture.barcodes.first.rawValue;
    if (ma == null || ma.isEmpty) return;
    setState(() => _dangXuLy = true);
    try {
      await _hienKetQua(ma);
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _hienKetQua(String ma) async {
    final sanPham = await CatalogService.getCached('products');
    final khopList = sanPham.where((sp) => jsonEncode(sp).toLowerCase().contains(ma.toLowerCase())).toList();
    final laLink = ma.startsWith('http://') || ma.startsWith('https://');

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55,
        maxChildSize: .9,
        builder: (context, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              const Text('Kết quả quét', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SelectableText(ma, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: ma));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Sao chép'),
                    ),
                  ),
                  if (laLink) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(ma), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Mở liên kết'),
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(height: 32),
              Text(
                khopList.isEmpty ? 'Không tìm thấy trong dữ liệu sản phẩm đã tải.' : 'Tìm thấy ${khopList.length} kết quả khớp trong Kho dữ liệu bán hàng:',
                style: TextStyle(color: khopList.isEmpty ? Colors.grey : AppTheme.viettelRed, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final sp in khopList)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_tomTat(sp), style: const TextStyle(fontSize: 13)),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Quét tiếp')),
            ],
          ),
        ),
      ),
    );
  }

  /// Cố lấy tên hiển thị từ vài tên trường THƯỜNG GẶP - nếu CSDL thật dùng
  /// tên trường khác, hiện tạm toàn bộ dữ liệu thô để không mất thông tin
  /// thay vì đoán sai và hiện rỗng.
  String _tomTat(dynamic sp) {
    if (sp is Map) {
      for (final key in ['ten_san_pham', 'ten', 'name', 'title', 'tieu_de']) {
        final gt = sp[key];
        if (gt != null && '$gt'.isNotEmpty) return '$gt';
      }
    }
    return jsonEncode(sp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã QR'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), tooltip: 'Bật/tắt đèn flash', onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch), tooltip: 'Đổi camera', onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _khiQuetDuoc,
            // Hiện ĐÚNG lý do lỗi cụ thể (thiếu quyền camera, máy không có
            // camera, lỗi tải mô-đun quét mã của Google...) thay vì để mặc
            // định plugin hiện "An unexpected error occurred" không rõ nguyên
            // nhân - giúp biết chính xác cần sửa gì thay vì đoán mò.
            errorBuilder: (context, error, child) {
              String lyDo;
              switch (error.errorCode) {
                case MobileScannerErrorCode.permissionDenied:
                  lyDo = 'Chưa cấp quyền Camera cho app. Vào Cài đặt máy > Ứng dụng > Viettel Khu Vực Vĩnh Hưng > Quyền > bật Camera.';
                  break;
                case MobileScannerErrorCode.unsupported:
                  lyDo = 'Máy này không hỗ trợ quét mã QR (thiếu camera hoặc thiếu dịch vụ Google cần thiết).';
                  break;
                default:
                  lyDo = 'Lỗi: ${error.errorDetails?.message ?? error.errorCode.name}';
              }
              return Container(
                color: Colors.black,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text(lyDo, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                        onPressed: _khoiDongCameraAnToan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Khung ngắm để dễ căn mã QR vào giữa - chỉ trang trí, không ảnh hưởng việc quét
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_dangXuLy) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }
}
