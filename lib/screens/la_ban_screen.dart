import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../theme.dart';

/// La bàn - chỉ hướng Bắc dựa vào cảm biến từ trường của thiết bị.
class LaBanScreen extends StatefulWidget {
  const LaBanScreen({super.key});

  @override
  State<LaBanScreen> createState() => _LaBanScreenState();
}

class _LaBanScreenState extends State<LaBanScreen> {
  StreamSubscription<CompassEvent>? _subscription;
  double? _huongHienTai; // độ, 0 = Bắc
  bool _khongHoTro = false;

  @override
  void initState() {
    super.initState();
    if (FlutterCompass.events == null) {
      _khongHoTro = true;
      return;
    }
    _subscription = FlutterCompass.events!.listen((event) {
      if (mounted) setState(() => _huongHienTai = event.heading);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _tenHuong(double do_) {
    const tenHuong = ['Bắc', 'Đông Bắc', 'Đông', 'Đông Nam', 'Nam', 'Tây Nam', 'Tây', 'Tây Bắc'];
    final chiSo = (((do_ % 360) + 22.5) / 45).floor() % 8;
    return tenHuong[chiSo];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('La bàn')),
      body: Center(
        child: _khongHoTro
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Thiết bị không có cảm biến la bàn (từ trường).', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              )
            : _huongHienTai == null
                ? const CircularProgressIndicator(color: AppTheme.viettelRed)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${_huongHienTai!.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      Text(_tenHuong(_huongHienTai!), style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300, width: 2),
                              ),
                            ),
                            const Positioned(top: 10, child: Text('B', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.viettelRed))),
                            const Positioned(bottom: 10, child: Text('N', style: TextStyle(color: Colors.grey))),
                            const Positioned(left: 10, child: Text('T', style: TextStyle(color: Colors.grey))),
                            const Positioned(right: 10, child: Text('Đ', style: TextStyle(color: Colors.grey))),
                            // Kim la bàn LUÔN chỉ đúng hướng Bắc thật - xoay
                            // NGƯỢC CHIỀU với hướng thiết bị đang quay (thiết
                            // bị quay phải bao nhiêu độ thì kim quay trái bấy
                            // nhiêu độ để bù lại, giữ nguyên hướng chỉ Bắc thật).
                            Transform.rotate(
                              angle: -(_huongHienTai! * (math.pi / 180)),
                              child: const Icon(Icons.navigation, size: 90, color: AppTheme.viettelRed),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
