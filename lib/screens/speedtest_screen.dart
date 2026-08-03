import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

/// Speedtest - đo tốc độ mạng thật (Ping/Tải xuống/Tải lên) bằng endpoint
/// công khai của Cloudflare (speed.cloudflare.com) - dịch vụ speed-test phổ
/// biến, miễn phí, không cần đăng ký/API key.
class SpeedtestScreen extends StatefulWidget {
  const SpeedtestScreen({super.key});

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

enum _GiaiDoan { chuaBatDau, dangDoPing, dangTaiXuong, dangTaiLen, xongHoanTat, loi }

class _SpeedtestScreenState extends State<SpeedtestScreen> {
  _GiaiDoan _giaiDoan = _GiaiDoan.chuaBatDau;
  int? _pingMs;
  double? _tocDoTaiXuongMbps;
  double? _tocDoTaiLenMbps;
  String? _thongBaoLoi;

  Future<void> _batDauDoToc() async {
    setState(() {
      _giaiDoan = _GiaiDoan.dangDoPing;
      _pingMs = null;
      _tocDoTaiXuongMbps = null;
      _tocDoTaiLenMbps = null;
      _thongBaoLoi = null;
    });

    try {
      // ---- 1. ĐO PING - đo 3 lần lấy trung bình cho ổn định ----
      final dsPing = <int>[];
      for (var i = 0; i < 3; i++) {
        final batDau = DateTime.now();
        await http.head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0')).timeout(const Duration(seconds: 8));
        dsPing.add(DateTime.now().difference(batDau).inMilliseconds);
      }
      dsPing.sort();
      if (!mounted) return;
      setState(() => _pingMs = dsPing[dsPing.length ~/ 2]); // lấy giá trị trung vị, ổn định hơn trung bình

      // ---- 2. ĐO TỐC ĐỘ TẢI XUỐNG - tải 20MB, đo thời gian thực tế ----
      setState(() => _giaiDoan = _GiaiDoan.dangTaiXuong);
      const soByteTai = 20 * 1000 * 1000; // 20MB
      final batDauTai = DateTime.now();
      final resTaiXuong = await http.get(Uri.parse('https://speed.cloudflare.com/__down?bytes=$soByteTai')).timeout(const Duration(seconds: 30));
      final thoiGianTaiGiay = DateTime.now().difference(batDauTai).inMilliseconds / 1000;
      final soByteThucNhan = resTaiXuong.bodyBytes.length;
      if (!mounted) return;
      if (thoiGianTaiGiay > 0) {
        // Mbps = (số byte * 8 bit) / thời gian(s) / 1_000_000
        setState(() => _tocDoTaiXuongMbps = (soByteThucNhan * 8) / thoiGianTaiGiay / 1000000);
      }

      // ---- 3. ĐO TỐC ĐỘ TẢI LÊN - gửi 5MB dữ liệu ngẫu nhiên ----
      setState(() => _giaiDoan = _GiaiDoan.dangTaiLen);
      const soByteGui = 5 * 1000 * 1000; // 5MB
      final duLieuGui = Uint8List.fromList(List.generate(soByteGui, (_) => Random().nextInt(256)));
      final batDauGui = DateTime.now();
      await http.post(Uri.parse('https://speed.cloudflare.com/__up'), body: duLieuGui).timeout(const Duration(seconds: 30));
      final thoiGianGuiGiay = DateTime.now().difference(batDauGui).inMilliseconds / 1000;
      if (!mounted) return;
      if (thoiGianGuiGiay > 0) {
        setState(() => _tocDoTaiLenMbps = (soByteGui * 8) / thoiGianGuiGiay / 1000000);
      }

      setState(() => _giaiDoan = _GiaiDoan.xongHoanTat);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _giaiDoan = _GiaiDoan.loi;
        _thongBaoLoi = 'Không đo được tốc độ mạng - kiểm tra lại kết nối Internet và thử lại.';
      });
    }
  }

  String _nhanGiaiDoan() {
    switch (_giaiDoan) {
      case _GiaiDoan.dangDoPing: return 'Đang đo Ping...';
      case _GiaiDoan.dangTaiXuong: return 'Đang đo tốc độ Tải xuống...';
      case _GiaiDoan.dangTaiLen: return 'Đang đo tốc độ Tải lên...';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dangDo = _giaiDoan == _GiaiDoan.dangDoPing || _giaiDoan == _GiaiDoan.dangTaiXuong || _giaiDoan == _GiaiDoan.dangTaiLen;
    return Scaffold(
      appBar: AppBar(title: const Text('Speedtest - Đo tốc độ mạng')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_giaiDoan == _GiaiDoan.chuaBatDau) ...[
                Icon(Icons.speed, size: 90, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text('Bấm nút bên dưới để bắt đầu đo tốc độ mạng hiện tại.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
              if (dangDo) ...[
                const CircularProgressIndicator(color: AppTheme.viettelRed),
                const SizedBox(height: 20),
                Text(_nhanGiaiDoan(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
              if (_giaiDoan == _GiaiDoan.xongHoanTat || _giaiDoan == _GiaiDoan.loi) ...[
                if (_pingMs != null) _theKetQua('Ping', '$_pingMs', 'ms', Icons.network_ping, Colors.orange),
                if (_tocDoTaiXuongMbps != null) ...[
                  const SizedBox(height: 14),
                  _theKetQua('Tải xuống', _tocDoTaiXuongMbps!.toStringAsFixed(1), 'Mbps', Icons.download, Colors.blue),
                ],
                if (_tocDoTaiLenMbps != null) ...[
                  const SizedBox(height: 14),
                  _theKetQua('Tải lên', _tocDoTaiLenMbps!.toStringAsFixed(1), 'Mbps', Icons.upload, Colors.green),
                ],
                if (_thongBaoLoi != null) Text(_thongBaoLoi!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: dangDo ? null : _batDauDoToc,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.viettelRed),
                  child: Text(
                    _giaiDoan == _GiaiDoan.chuaBatDau ? 'Bắt đầu đo' : 'Đo lại',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _theKetQua(String nhan, String giaTri, String donVi, IconData icon, Color mau) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: mau.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: mau, size: 26),
          const SizedBox(width: 14),
          Text(nhan, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(giaTri, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: mau)),
          const SizedBox(width: 4),
          Text(donVi, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
