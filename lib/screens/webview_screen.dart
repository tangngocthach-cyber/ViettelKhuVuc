import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

/// Màn hình dùng CHUNG cho MỌI module lấy dữ liệu từ website thật (Sản phẩm,
/// Tin tức, Chính sách, Diễn đàn, Tìm kiếm, Quay số, Bốc thăm...) - đúng yêu
/// cầu: KHÔNG dựng lại giao diện riêng, mở thẳng trang thật qua WebView.
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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _dangTai = true;
          _loiMang = false;
        }),
        onPageFinished: (_) => setState(() => _dangTai = false),
        onWebResourceError: (error) => setState(() {
          _dangTai = false;
          _loiMang = true;
        }),
      ))
      ..loadRequest(Uri.parse(widget.url));
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
      body: Stack(
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
                  ElevatedButton(onPressed: () => _controller.reload(), child: const Text('Thử lại')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
