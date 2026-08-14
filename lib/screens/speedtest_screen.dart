import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

/// Speedtest hiện đại - đồng hồ đo tốc độ dạng cung tròn có animation mượt,
/// đo Ping/Tải xuống/Tải lên THẬT qua endpoint công khai Cloudflare, kèm
/// giải thích ý nghĩa từng thông số và đánh giá chất lượng mạng.
class SpeedtestScreen extends StatefulWidget {
  const SpeedtestScreen({super.key});

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

enum _GiaiDoan { chuaBatDau, dangDoPing, dangTaiXuong, dangTaiLen, xongHoanTat, loi }

class _SpeedtestScreenState extends State<SpeedtestScreen> with SingleTickerProviderStateMixin {
  _GiaiDoan _giaiDoan = _GiaiDoan.chuaBatDau;
  int? _pingMs;
  double? _tocDoTaiXuongMbps;
  double? _tocDoTaiLenMbps;
  String? _thongBaoLoi;

  late AnimationController _kimController;
  double _giaTriKimHienThi = 0; // Mbps đang hiện trên đồng hồ (mượt dần tới giá trị thật)
  static const double _mbpsToiDaTrenDongHo = 1000; // NÂNG TỪ 200 - giờ đo được tốc độ thật (nhiều luồng song song) có thể lên tới hàng trăm Mbps, để 200 kim sẽ bị "kẹt cứng" ở mức tối đa sai lệch

  @override
  void initState() {
    super.initState();
    _kimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _kimController.dispose();
    super.dispose();
  }

  void _capNhatKim(double mbpsMoi) {
    final tuGiaTri = _giaTriKimHienThi;
    final denGiaTri = mbpsMoi.clamp(0, _mbpsToiDaTrenDongHo).toDouble();
    final animation = Tween<double>(begin: tuGiaTri, end: denGiaTri).animate(CurvedAnimation(parent: _kimController, curve: Curves.easeOutCubic));
    animation.addListener(() => setState(() => _giaTriKimHienThi = animation.value));
    _kimController.forward(from: 0);
  }

  Future<void> _batDauDoToc() async {
    setState(() {
      _giaiDoan = _GiaiDoan.dangDoPing;
      _pingMs = null;
      _tocDoTaiXuongMbps = null;
      _tocDoTaiLenMbps = null;
      _thongBaoLoi = null;
      _giaTriKimHienThi = 0;
    });

    // Dùng 1 KẾT NỐI DUY NHẤT giữ nguyên xuyên suốt toàn bộ quá trình đo -
    // TÁI SỬ DỤNG (keep-alive) cho các lần gọi sau, đúng cách các công cụ đo
    // tốc độ THẬT SỰ hoạt động (Speedtest.net, Ookla...).
    //
    // LỖI THẬT ĐÃ GẶP TRƯỚC ĐÂY: dùng http.head() cấp cao - mỗi lần gọi TỰ
    // TẠO 1 KẾT NỐI MỚI RỒI ĐÓNG NGAY, nghĩa là MỌI LẦN đo Ping đều phải
    // THIẾT LẬP LẠI TỪ ĐẦU (tra cứu DNS + bắt tay TCP + bắt tay TLS - riêng
    // bắt tay TLS qua mạng di động thường mất 150-300ms) - đây LÀ CHI PHÍ
    // KẾT NỐI, HOÀN TOÀN KHÔNG PHẢI ĐỘ TRỄ MẠNG THẬT, khiến Ping ĐO ĐƯỢC LUÔN
    // RẤT CAO một cách giả tạo (không liên quan gì tới chọn sai máy chủ).
    final client = http.Client();
    try {
      // ---- BƯỚC KHỞI ĐỘNG - "làm ấm" kết nối trước, KHÔNG tính vào kết quả.
      // Sau bước này, các request tiếp theo qua CÙNG client sẽ TÁI SỬ DỤNG
      // kết nối đã có sẵn (không mất công bắt tay lại), đo được ĐÚNG độ trễ
      // round-trip thật sự.
      await client.head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0')).timeout(const Duration(seconds: 8));

      // ---- 1. ĐO PING - đo 5 lần qua kết nối ĐÃ ẤM, lấy trung vị cho ổn định ----
      final dsPing = <int>[];
      for (var i = 0; i < 5; i++) {
        final batDau = DateTime.now();
        await client.head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0')).timeout(const Duration(seconds: 8));
        dsPing.add(DateTime.now().difference(batDau).inMilliseconds);
      }
      dsPing.sort();
      if (!mounted) return;
      setState(() => _pingMs = dsPing[dsPing.length ~/ 2]);

      // ---- 2. TẢI XUỐNG - đo theo TỪNG PHẦN (không chờ tải xong mới biết tốc
      // độ) để kim đồng hồ chạy MƯỢT theo tốc độ THẬT đang đo, không chỉ nhảy
      // 1 phát lúc xong. ----
      setState(() => _giaiDoan = _GiaiDoan.dangTaiXuong);
      final tocDoTaiXuong = await _doTocDoTaiXuong(client);
      if (!mounted) return;
      setState(() => _tocDoTaiXuongMbps = tocDoTaiXuong);

      // ---- 3. TẢI LÊN - nhiều luồng song song, giống hệt tải xuống ----
      setState(() {
        _giaiDoan = _GiaiDoan.dangTaiLen;
        _giaTriKimHienThi = 0;
      });
      _kimController.reset();
      final tocDoTaiLen = await _doTocDoTaiLen(client);
      if (!mounted) return;
      setState(() => _tocDoTaiLenMbps = tocDoTaiLen);
      _capNhatKim(tocDoTaiLen);

      setState(() => _giaiDoan = _GiaiDoan.xongHoanTat);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _giaiDoan = _GiaiDoan.loi;
        _thongBaoLoi = 'Không đo được tốc độ mạng - kiểm tra lại kết nối Internet và thử lại.';
      });
    } finally {
      client.close();
    }
  }

  /// Tải xuống bằng NHIỀU LUỒNG SONG SONG (mặc định 4) - ĐÚNG cách các công
  /// cụ đo tốc độ THẬT hoạt động (Speedtest.net/Ookla). LỖI THẬT ĐÃ GẶP
  /// TRƯỚC ĐÂY: chỉ dùng 1 luồng tải đơn - 1 kết nối TCP luôn có TRẦN THÔNG
  /// LƯỢNG RIÊNG (do cơ chế kiểm soát tắc nghẽn TCP + slow-start), KHÔNG BAO
  /// GIỜ "kéo hết" được đường truyền tốc độ cao dù mạng thật nhanh hơn NHIỀU
  /// - đối chiếu thực tế với app Speedtest chuyên nghiệp cùng thời điểm cho
  /// thấy kết quả SAI LỆCH TỚI 8 LẦN (446 Mbps thật vs chỉ đo được 59.9
  /// Mbps). Đo trong 1 KHOẢNG THỜI GIAN CỐ ĐỊNH (không đợi tải hết file) vì
  /// file cố tình để RẤT LỚN - đây mới là cách đo ĐÚNG "thông lượng thực sự
  /// đạt được", không bị sai lệch bởi giai đoạn tăng tốc ban đầu (slow-start)
  /// của TCP như khi đo qua 1 file nhỏ cố định.
  static const int _soLuongSongSong = 4;
  static const int _thoiLuongDoGiay = 8;

  Future<double> _doTocDoTaiXuong(http.Client client) async {
    const kichThuocMoiLuong = 200 * 1000 * 1000; // 200MB/luồng - đủ lớn, không lo tải hết trước khi hết giờ đo dù mạng rất nhanh
    int tongByteDaNhan = 0;
    bool dangDo = true;

    final dsSub = <StreamSubscription>[];
    for (var i = 0; i < _soLuongSongSong; i++) {
      try {
        final request = http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=$kichThuocMoiLuong'));
        final res = await client.send(request).timeout(const Duration(seconds: 15));
        dsSub.add(res.stream.listen((doan) {
          if (dangDo) tongByteDaNhan += doan.length;
        }));
      } catch (_) {
        // 1 luồng lỗi không làm hỏng cả phép đo - các luồng còn lại vẫn tiếp tục.
      }
    }

    final batDau = DateTime.now();
    DateTime lanCapNhatCuoi = batDau;
    int byteLucCapNhatCuoi = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final baygio = DateTime.now();
      final byteVuaTaiTrongKhoang = tongByteDaNhan - byteLucCapNhatCuoi;
      final giayVuaTrongKhoang = baygio.difference(lanCapNhatCuoi).inMilliseconds / 1000;
      if (giayVuaTrongKhoang > 0 && mounted) {
        final tocDoTucThoi = (byteVuaTaiTrongKhoang * 8) / giayVuaTrongKhoang / 1000000;
        _capNhatKim(tocDoTucThoi);
      }
      lanCapNhatCuoi = baygio;
      byteLucCapNhatCuoi = tongByteDaNhan;
    });

    await Future.delayed(const Duration(seconds: _thoiLuongDoGiay));
    dangDo = false;
    timer.cancel();
    for (final sub in dsSub) { await sub.cancel(); } // dừng hẳn tải để không lãng phí dung lượng di động của CNKD

    final tongThoiGianGiay = DateTime.now().difference(batDau).inMilliseconds / 1000;
    return tongThoiGianGiay > 0 ? (tongByteDaNhan * 8) / tongThoiGianGiay / 1000000 : 0;
  }

  /// Tải lên bằng NHIỀU LUỒNG SONG SONG, MỖI LUỒNG GỬI LIÊN TỤC (không chỉ 1
  /// lần) cho tới hết thời gian đo - cùng lý do như phần tải xuống.
  Future<double> _doTocDoTaiLen(http.Client client) async {
    const kichThuocMoiLan = 5 * 1000 * 1000; // 5MB/lần gửi
    int tongByteDaGui = 0;
    final batDau = DateTime.now();
    final ketThucLuc = batDau.add(const Duration(seconds: _thoiLuongDoGiay));

    DateTime lanCapNhatCuoi = batDau;
    int byteLucCapNhatCuoi = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final baygio = DateTime.now();
      final byteVuaGuiTrongKhoang = tongByteDaGui - byteLucCapNhatCuoi;
      final giayVuaTrongKhoang = baygio.difference(lanCapNhatCuoi).inMilliseconds / 1000;
      if (giayVuaTrongKhoang > 0 && mounted) {
        final tocDoTucThoi = (byteVuaGuiTrongKhoang * 8) / giayVuaTrongKhoang / 1000000;
        _capNhatKim(tocDoTucThoi);
      }
      lanCapNhatCuoi = baygio;
      byteLucCapNhatCuoi = tongByteDaGui;
    });

    await Future.wait(List.generate(_soLuongSongSong, (_) async {
      while (DateTime.now().isBefore(ketThucLuc)) {
        try {
          final duLieu = Uint8List.fromList(List.generate(kichThuocMoiLan, (_) => Random().nextInt(256)));
          await client.post(Uri.parse('https://speed.cloudflare.com/__up'), body: duLieu).timeout(const Duration(seconds: 10));
          tongByteDaGui += kichThuocMoiLan;
        } catch (_) {
          break; // luồng này lỗi thì dừng riêng nó, các luồng khác vẫn tiếp tục
        }
      }
    }));

    timer.cancel();
    final tongThoiGianGiay = DateTime.now().difference(batDau).inMilliseconds / 1000;
    return tongThoiGianGiay > 0 ? (tongByteDaGui * 8) / tongThoiGianGiay / 1000000 : 0;
  }

  String _danhGiaChatLuong(double? taiXuong, int? ping) {
    if (taiXuong == null || ping == null) return '';
    if (taiXuong >= 50 && ping < 50) return '🟢 Xuất sắc - đủ cho họp video, xem 4K, tải file lớn mượt mà.';
    if (taiXuong >= 20 && ping < 100) return '🟢 Tốt - đủ cho hầu hết công việc hằng ngày.';
    if (taiXuong >= 5) return '🟡 Trung bình - có thể giật khi họp video hoặc tải file lớn.';
    return '🔴 Yếu - nên kiểm tra lại đường truyền, có thể ảnh hưởng công việc.';
  }

  @override
  Widget build(BuildContext context) {
    final dangDo = _giaiDoan == _GiaiDoan.dangDoPing || _giaiDoan == _GiaiDoan.dangTaiXuong || _giaiDoan == _GiaiDoan.dangTaiLen;
    final xongHoanTat = _giaiDoan == _GiaiDoan.xongHoanTat;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Speedtest - Đo tốc độ mạng')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 6),
              // ---- Thông tin máy chủ đo - MINH BẠCH cho người dùng biết đang
              // đo qua máy chủ nào, không phải "hộp đen" khó hiểu.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dns_outlined, size: 15, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Máy chủ: Cloudflare (tự động chọn điểm gần nhất)',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ---- ĐỒNG HỒ ĐO TỐC ĐỘ DẠNG CUNG TRÒN ----
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: SizedBox(
                  width: 260,
                  height: 200,
                  child: CustomPaint(
                    painter: _DongHoTocDoPainter(giaTriMbps: _giaTriKimHienThi, giaTriToiDa: _mbpsToiDaTrenDongHo),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dangDo ? _giaTriKimHienThi.toStringAsFixed(0) : (xongHoanTat ? (_tocDoTaiXuongMbps ?? 0).toStringAsFixed(1) : '0'),
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                            ),
                            Text('Mbps', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, letterSpacing: 0.5)),
                            if (dangDo) ...[
                              const SizedBox(height: 4),
                              Text(_nhanGiaiDoan(), style: const TextStyle(fontSize: 11.5, color: AppTheme.viettelRed, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_giaiDoan == _GiaiDoan.chuaBatDau)
                Text('Bấm nút bên dưới để bắt đầu đo tốc độ mạng hiện tại.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),

              if (xongHoanTat || _giaiDoan == _GiaiDoan.loi) ...[
                Row(
                  children: [
                    if (_pingMs != null) Expanded(child: _theKetQuaNho('Ping', '$_pingMs', 'ms', Icons.network_ping, Colors.orange)),
                    if (_pingMs != null && _tocDoTaiLenMbps != null) const SizedBox(width: 10),
                    if (_tocDoTaiLenMbps != null) Expanded(child: _theKetQuaNho('Tải lên', _tocDoTaiLenMbps!.toStringAsFixed(1), 'Mbps', Icons.upload, Colors.green)),
                  ],
                ),
                if (_tocDoTaiXuongMbps != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                    child: Text(_danhGiaChatLuong(_tocDoTaiXuongMbps, _pingMs), style: const TextStyle(fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 16),
                _theGiaiThichThongSo(),
                if (_thongBaoLoi != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_thongBaoLoi!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: dangDo ? null : _batDauDoToc,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.viettelRed,
                    elevation: 3,
                    shadowColor: AppTheme.viettelRed.withValues(alpha: .4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(_giaiDoan == _GiaiDoan.chuaBatDau ? Icons.play_arrow : Icons.refresh, color: Colors.white),
                  label: Text(
                    _giaiDoan == _GiaiDoan.chuaBatDau ? 'Bắt đầu đo' : 'Đo lại',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nhanGiaiDoan() {
    switch (_giaiDoan) {
      case _GiaiDoan.dangDoPing: return 'Đang đo Ping...';
      case _GiaiDoan.dangTaiXuong: return 'Tải xuống';
      case _GiaiDoan.dangTaiLen: return 'Tải lên';
      default: return '';
    }
  }

  Widget _theKetQuaNho(String nhan, String giaTri, String donVi, IconData icon, Color mau) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mau.withValues(alpha: .2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: mau.withValues(alpha: .1), shape: BoxShape.circle),
            child: Icon(icon, color: mau, size: 20),
          ),
          const SizedBox(height: 8),
          Text('$giaTri $donVi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: mau)),
          const SizedBox(height: 2),
          Text(nhan, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _theGiaiThichThongSo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Ý nghĩa các thông số', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 8),
          _DongGiaiThich('Ping', 'Độ trễ phản hồi - CÀNG THẤP càng tốt. Dưới 50ms: rất mượt cho họp video/game online. Trên 150ms: dễ giật, lag.'),
          SizedBox(height: 6),
          _DongGiaiThich('Tải xuống', 'Tốc độ nhận dữ liệu - ảnh hưởng tốc độ xem video, tải file, duyệt web.'),
          SizedBox(height: 6),
          _DongGiaiThich('Tải lên', 'Tốc độ gửi dữ liệu - ảnh hưởng chất lượng họp video, gửi file, live stream.'),
        ],
      ),
    );
  }
}

class _DongGiaiThich extends StatelessWidget {
  final String nhan;
  final String moTa;
  const _DongGiaiThich(this.nhan, this.moTa);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
        children: [
          TextSpan(text: '$nhan: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          TextSpan(text: moTa),
        ],
      ),
    );
  }
}

/// Vẽ đồng hồ đo tốc độ dạng cung tròn (nửa vòng tròn) kiểu speedometer -
/// vạch chia màu xanh (chậm) tới đỏ (nhanh), kim chỉ đúng vị trí giá trị hiện tại.
class _DongHoTocDoPainter extends CustomPainter {
  final double giaTriMbps;
  final double giaTriToiDa;
  _DongHoTocDoPainter({required this.giaTriMbps, required this.giaTriToiDa});

  @override
  void paint(Canvas canvas, Size size) {
    final tamCung = Offset(size.width / 2, size.height - 20);
    final banKinh = size.width / 2 - 20;

    // Cung nền (xám nhạt) - từ 180° tới 360° (nửa vòng tròn phía trên)
    final sonNen = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: tamCung, radius: banKinh), pi, pi, false, sonNen);

    // Cung màu theo giá trị hiện tại - gradient xanh lá -> vàng -> đỏ
    final tiLe = (giaTriMbps / giaTriToiDa).clamp(0.0, 1.0);
    final sonGiaTri = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.red, Colors.orange, Colors.yellow, Colors.lightGreen, Colors.green],
        stops: [0, 0.25, 0.5, 0.75, 1],
      ).createShader(Rect.fromCircle(center: tamCung, radius: banKinh))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: tamCung, radius: banKinh), pi, pi * tiLe, false, sonGiaTri);

    // Kim chỉ giá trị
    final gocKim = pi + (pi * tiLe);
    final diemDauKim = Offset(tamCung.dx + (banKinh - 26) * cos(gocKim), tamCung.dy + (banKinh - 26) * sin(gocKim));
    final sonKim = Paint()
      ..color = Colors.black87
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tamCung, diemDauKim, sonKim);
    canvas.drawCircle(tamCung, 6, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _DongHoTocDoPainter oldDelegate) => oldDelegate.giaTriMbps != giaTriMbps;
}
