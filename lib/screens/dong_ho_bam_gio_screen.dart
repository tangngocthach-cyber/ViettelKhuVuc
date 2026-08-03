import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Đồng hồ bấm giờ - đếm thời gian chính xác tới phần trăm giây, lưu được
/// nhiều vòng (lap) để so sánh.
class DongHoBamGioScreen extends StatefulWidget {
  const DongHoBamGioScreen({super.key});

  @override
  State<DongHoBamGioScreen> createState() => _DongHoBamGioScreenState();
}

class _DongHoBamGioScreenState extends State<DongHoBamGioScreen> {
  final _stopwatch = Stopwatch();
  Timer? _timer;
  final List<Duration> _dsVong = [];

  void _batDauTamDung() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timer?.cancel();
      } else {
        _stopwatch.start();
        // Cập nhật lại giao diện mỗi 30ms để số chạy mượt mắt
        _timer = Timer.periodic(const Duration(milliseconds: 30), (_) => setState(() {}));
      }
    });
  }

  void _luuVong() {
    if (!_stopwatch.isRunning) return;
    setState(() => _dsVong.insert(0, _stopwatch.elapsed));
  }

  void _datLai() {
    setState(() {
      _stopwatch.stop();
      _stopwatch.reset();
      _timer?.cancel();
      _dsVong.clear();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _dinhDangThoiGian(Duration d) {
    final gio = d.inHours;
    final phut = d.inMinutes.remainder(60);
    final giay = d.inSeconds.remainder(60);
    final phanTramGiay = (d.inMilliseconds.remainder(1000) / 10).floor();
    final phanGio = gio > 0 ? '${gio.toString().padLeft(2, '0')}:' : '';
    return '$phanGio${phut.toString().padLeft(2, '0')}:${giay.toString().padLeft(2, '0')}.${phanTramGiay.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dangChay = _stopwatch.isRunning;
    return Scaffold(
      appBar: AppBar(title: const Text('Đồng hồ bấm giờ')),
      body: Column(
        children: [
          const SizedBox(height: 50),
          Center(
            child: Text(
              _dinhDangThoiGian(_stopwatch.elapsed),
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 90, height: 90,
                child: OutlinedButton(
                  onPressed: _stopwatch.elapsed == Duration.zero && !dangChay ? null : (dangChay ? _luuVong : _datLai),
                  style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                  child: Text(dangChay ? 'Vòng' : 'Đặt lại'),
                ),
              ),
              const SizedBox(width: 30),
              SizedBox(
                width: 90, height: 90,
                child: ElevatedButton(
                  onPressed: _batDauTamDung,
                  style: ElevatedButton.styleFrom(backgroundColor: dangChay ? Colors.red : Colors.green, shape: const CircleBorder()),
                  child: Text(dangChay ? 'Dừng' : 'Bắt đầu', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Divider(height: 1),
          Expanded(
            child: _dsVong.isEmpty
                ? Center(child: Text('Chưa có vòng nào.', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _dsVong.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final soThuTuVong = _dsVong.length - i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Vòng $soThuTuVong', style: TextStyle(color: Colors.grey.shade600)),
                            Text(_dinhDangThoiGian(_dsVong[i]), style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
