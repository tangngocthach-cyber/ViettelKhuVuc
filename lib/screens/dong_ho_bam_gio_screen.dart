import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

class _Vong {
  final Duration tongThoiGian; // thời điểm bấm, tính từ lúc bắt đầu
  final Duration chenhLech; // thời gian CỦA RIÊNG vòng này (so với vòng trước)
  _Vong({required this.tongThoiGian, required this.chenhLech});
}

/// Đồng hồ bấm giờ - đếm thời gian chính xác tới phần trăm giây, lưu nhiều
/// vòng (lap) kèm thời gian CHÊNH LỆCH từng vòng, đánh dấu vòng nhanh
/// nhất/chậm nhất, xóa được từng vòng riêng lẻ.
class DongHoBamGioScreen extends StatefulWidget {
  const DongHoBamGioScreen({super.key});

  @override
  State<DongHoBamGioScreen> createState() => _DongHoBamGioScreenState();
}

class _DongHoBamGioScreenState extends State<DongHoBamGioScreen> {
  final _stopwatch = Stopwatch();
  Timer? _timer;
  final List<_Vong> _dsVong = [];

  void _batDauTamDung() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _timer?.cancel();
      } else {
        _stopwatch.start();
        _timer = Timer.periodic(const Duration(milliseconds: 30), (_) => setState(() {}));
      }
    });
  }

  void _luuVong() {
    if (!_stopwatch.isRunning) return;
    final tongHienTai = _stopwatch.elapsed;
    final chenhLech = _dsVong.isEmpty ? tongHienTai : tongHienTai - _dsVong.first.tongThoiGian;
    setState(() => _dsVong.insert(0, _Vong(tongThoiGian: tongHienTai, chenhLech: chenhLech)));
  }

  void _xoaVong(int index) {
    setState(() => _dsVong.removeAt(index));
  }

  void _datLaiTatCa() {
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

    // Tìm vòng nhanh nhất/chậm nhất (chỉ có ý nghĩa khi >= 2 vòng) để đánh dấu màu
    Duration? nhanhNhat, chamNhat;
    if (_dsVong.length >= 2) {
      nhanhNhat = _dsVong.map((v) => v.chenhLech).reduce((a, b) => a < b ? a : b);
      chamNhat = _dsVong.map((v) => v.chenhLech).reduce((a, b) => a > b ? a : b);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đồng hồ bấm giờ'),
        actions: [
          if (_dsVong.isNotEmpty || _stopwatch.elapsed > Duration.zero)
            IconButton(icon: const Icon(Icons.delete_sweep), tooltip: 'Xóa tất cả', onPressed: _datLaiTatCa),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Center(
              child: Text(
                _dinhDangThoiGian(_stopwatch.elapsed),
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 84, height: 84,
                  child: OutlinedButton(
                    onPressed: !dangChay ? null : _luuVong,
                    style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                    child: const Text('Vòng'),
                  ),
                ),
                const SizedBox(width: 26),
                SizedBox(
                  width: 84, height: 84,
                  child: ElevatedButton(
                    onPressed: _batDauTamDung,
                    style: ElevatedButton.styleFrom(backgroundColor: dangChay ? Colors.red : Colors.green, shape: const CircleBorder()),
                    child: Text(dangChay ? 'Dừng' : (_stopwatch.elapsed > Duration.zero ? 'Tiếp tục' : 'Bắt đầu'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            Expanded(
              child: _dsVong.isEmpty
                  ? Center(child: Text('Chưa có vòng nào - bấm "Vòng" khi đồng hồ đang chạy để lưu lại.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _dsVong.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final v = _dsVong[i];
                        final soThuTuVong = _dsVong.length - i;
                        Color? mauChenhLech;
                        if (nhanhNhat != null && v.chenhLech == nhanhNhat) mauChenhLech = Colors.green.shade700;
                        if (chamNhat != null && v.chenhLech == chamNhat) mauChenhLech = Colors.red.shade700;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 44, child: Text('Vòng $soThuTuVong', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
                              Expanded(
                                child: Text(
                                  '+${_dinhDangThoiGian(v.chenhLech)}',
                                  style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], color: mauChenhLech, fontWeight: mauChenhLech != null ? FontWeight.bold : null),
                                ),
                              ),
                              Text(_dinhDangThoiGian(v.tongThoiGian), style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontFeatures: const [FontFeature.tabularFigures()])),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                onPressed: () => _xoaVong(i),
                                tooltip: 'Xóa vòng này',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
