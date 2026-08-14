import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

/// Speedtest - đo Ping/Tải xuống/Tải lên qua endpoint công khai Cloudflare.
///
/// GHI CHÚ QUAN TRỌNG VỀ PHƯƠNG PHÁP LUẬN (đọc trước khi sửa file này):
/// Đây KHÔNG PHẢI bản sao/giả lập Speedtest by Ookla - Ookla dùng hạ tầng máy
/// chủ và SDK riêng, không công khai, không được phép reverse-engineer. Kết
/// quả app này và Ookla ĐO QUA 2 TUYẾN MẠNG KHÁC NHAU (khác máy chủ, khác nhà
/// cung cấp hạ tầng đo) nên CÓ THỂ khác nhau dù cả 2 đều đo đúng - đây là hạn
/// chế tất yếu của việc dùng máy chủ đo công khai (Cloudflare), không phải
/// lỗi tính toán. File này áp dụng đúng phương pháp luận đo chuẩn (tách Idle/
/// Loaded Latency, cửa sổ ổn định bỏ qua giai đoạn tăng tốc TCP, nhiều luồng
/// song song, kiểm định độ ổn định) để kết quả PHẢN ÁNH ĐÚNG NHẤT khả năng
/// của đường truyền đo được qua máy chủ Cloudflare - không nhân/chia hệ số
/// nào để "cho đẹp số".
class SpeedtestScreen extends StatefulWidget {
  const SpeedtestScreen({super.key});

  @override
  State<SpeedtestScreen> createState() => _SpeedtestScreenState();
}

enum _GiaiDoan { chuaBatDau, dangDoPing, dangTaiXuong, dangTaiLen, xongHoanTat, loi }

class _SpeedtestScreenState extends State<SpeedtestScreen> with SingleTickerProviderStateMixin {
  _GiaiDoan _giaiDoan = _GiaiDoan.chuaBatDau;

  // Idle Latency (đo lúc KHÔNG có tải) - tách biệt hẳn khỏi Loaded Latency.
  int? _idleLatencyMs; // trung vị (median) - số hiển thị chính, ít bị lệch bởi 1 mẫu bất thường
  int? _jitterMs; // độ lệch trung bình giữa các mẫu liên tiếp
  List<int> _mauPingThoDs = [];

  // Loaded Latency (đo NGAY TRONG LÚC đang tải xuống/tải lên) - phát hiện bufferbloat.
  int? _loadedLatencyTaiXuongMs;
  int? _loadedLatencyTaiLenMs;

  double? _tocDoTaiXuongMbps;
  double? _tocDoTaiLenMbps;
  bool _ketQuaOnDinh = true; // false nếu tốc độ dao động quá lớn trong chính cửa sổ đo - khuyến nghị đo lại
  String? _serverColo; // mã trung tâm dữ liệu Cloudflare thực tế phục vụ - lấy thật qua /cdn-cgi/trace, KHÔNG bịa
  String? _thongBaoLoi;

  late AnimationController _kimController;
  double _giaTriKimHienThi = 0;
  static const double _mbpsToiDaTrenDongHo = 1000;

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
      _idleLatencyMs = null;
      _jitterMs = null;
      _mauPingThoDs = [];
      _loadedLatencyTaiXuongMs = null;
      _loadedLatencyTaiLenMs = null;
      _tocDoTaiXuongMbps = null;
      _tocDoTaiLenMbps = null;
      _ketQuaOnDinh = true;
      _serverColo = null;
      _thongBaoLoi = null;
      _giaTriKimHienThi = 0;
    });

    final client = http.Client();
    try {
      await client.head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0')).timeout(const Duration(seconds: 8));

      // ---- Lấy THẬT tên trung tâm dữ liệu Cloudflare đang phục vụ (KHÔNG
      // bịa) - endpoint /cdn-cgi/trace là endpoint chẩn đoán CÔNG KHAI, CHÍNH
      // THỨC của Cloudflare, trả về text dạng "colo=SIN" v.v.
      try {
        final resTrace = await client.get(Uri.parse('https://speed.cloudflare.com/cdn-cgi/trace')).timeout(const Duration(seconds: 5));
        final dongColo = resTrace.body.split('\n').firstWhere((d) => d.startsWith('colo='), orElse: () => '');
        if (dongColo.isNotEmpty && mounted) setState(() => _serverColo = dongColo.substring(5).trim());
      } catch (_) {
        // Không lấy được thì thôi, không quan trọng bằng kết quả đo chính
      }

      // ---- 1. IDLE LATENCY - đo N=12 mẫu KHI CHƯA CÓ TẢI, qua kết nối đã ấm
      // sẵn - lấy TRUNG VỊ (median) làm số chính (ít bị lệch bởi 1-2 mẫu bất
      // thường hơn số trung bình cộng), tính thêm Jitter (độ lệch trung bình
      // giữa các mẫu liên tiếp).
      final dsPing = <int>[];
      for (var i = 0; i < 12; i++) {
        final batDau = DateTime.now();
        await client.head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0')).timeout(const Duration(seconds: 8));
        dsPing.add(DateTime.now().difference(batDau).inMilliseconds);
      }
      final dsPingDaSap = List<int>.from(dsPing)..sort();
      var tongLechLienTiep = 0;
      for (var i = 1; i < dsPing.length; i++) { tongLechLienTiep += (dsPing[i] - dsPing[i - 1]).abs(); }
      if (!mounted) return;
      setState(() {
        _mauPingThoDs = dsPing;
        _idleLatencyMs = dsPingDaSap[dsPingDaSap.length ~/ 2];
        _jitterMs = dsPing.length > 1 ? (tongLechLienTiep / (dsPing.length - 1)).round() : 0;
      });

      // ---- 2. TẢI XUỐNG - kèm đo Loaded Latency song song trong lúc tải ----
      setState(() => _giaiDoan = _GiaiDoan.dangTaiXuong);
      final ketQuaTaiXuong = await _doTocDoTaiXuong(client);
      if (!mounted) return;
      setState(() {
        _tocDoTaiXuongMbps = ketQuaTaiXuong.mbps;
        _loadedLatencyTaiXuongMs = ketQuaTaiXuong.loadedLatencyMs;
        if (!ketQuaTaiXuong.onDinh) _ketQuaOnDinh = false;
      });

      // ---- 3. TẢI LÊN - kèm đo Loaded Latency song song trong lúc tải ----
      setState(() {
        _giaiDoan = _GiaiDoan.dangTaiLen;
        _giaTriKimHienThi = 0;
      });
      _kimController.reset();
      final ketQuaTaiLen = await _doTocDoTaiLen(client);
      if (!mounted) return;
      setState(() {
        _tocDoTaiLenMbps = ketQuaTaiLen.mbps;
        _loadedLatencyTaiLenMs = ketQuaTaiLen.loadedLatencyMs;
        if (!ketQuaTaiLen.onDinh) _ketQuaOnDinh = false;
      });
      _capNhatKim(ketQuaTaiLen.mbps);

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

  static const int _soLuongSongSong = 4;
  static const int _thoiLuongDoGiay = 8;
  // Bỏ qua 25% THỜI GIAN ĐẦU của cửa sổ đo khi tính kết quả cuối - đây là
  // giai đoạn TCP còn đang "tăng tốc" (slow-start) + các luồng song song
  // chưa kịp khởi động hết, LUÔN chậm hơn tốc độ ổn định thật sự - tính cả
  // giai đoạn này vào trung bình sẽ kéo kết quả xuống thấp giả tạo trên
  // đường truyền nhanh (ĐÚNG NGUỒN GỐC gây sai lệch lớn so với Ookla trước
  // đây - Ookla và các công cụ đo chuẩn khác đều loại bỏ giai đoạn này).
  static const double _tiLeBoQuaTangToc = 0.25;

  Future<void> _guiPingTrongLucTai(http.Client client, List<int> ketQuaRa, bool Function() conDangTai) async {
    // Đo Loaded Latency: bắn 1 request HEAD nhẹ (0 byte) mỗi ~1 giây TRONG
    // LÚC các luồng tải xuống/tải lên vẫn đang chạy - qua CÙNG client (cùng
    // hạ tầng kết nối) nên phản ánh đúng độ trễ THẬT dưới tải, không phải độ
    // trễ của 1 kết nối rảnh rỗi riêng biệt.
    while (conDangTai()) {
      try {
        final batDau = DateTime.now();
        await client.head(Uri.parse('https://speed.cloudflare.com/__down?bytes=0')).timeout(const Duration(seconds: 5));
        ketQuaRa.add(DateTime.now().difference(batDau).inMilliseconds);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 900));
    }
  }

  Future<({double mbps, int? loadedLatencyMs, bool onDinh})> _doTocDoTaiXuong(http.Client client) async {
    const kichThuocMoiLan = 25 * 1000 * 1000;
    int tongByteDaNhan = 0;
    final batDau = DateTime.now();
    final ketThucLuc = batDau.add(const Duration(seconds: _thoiLuongDoGiay));
    bool dangTai = true;

    // Ghi lại throughput tức thời theo từng mốc 200ms - dùng để cắt bỏ giai
    // đoạn tăng tốc ban đầu VÀ để tính độ ổn định (coefficient of variation)
    // của cửa sổ đã ổn định.
    final dsMauThoiGian = <double>[]; // giây kể từ lúc bắt đầu
    final dsMauMbps = <double>[];
    DateTime lanCapNhatCuoi = batDau;
    int byteLucCapNhatCuoi = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final baygio = DateTime.now();
      final byteVuaTaiTrongKhoang = tongByteDaNhan - byteLucCapNhatCuoi;
      final giayVuaTrongKhoang = baygio.difference(lanCapNhatCuoi).inMilliseconds / 1000;
      if (giayVuaTrongKhoang > 0) {
        final tocDoTucThoi = (byteVuaTaiTrongKhoang * 8) / giayVuaTrongKhoang / 1000000;
        if (mounted) _capNhatKim(tocDoTucThoi);
        dsMauThoiGian.add(baygio.difference(batDau).inMilliseconds / 1000);
        dsMauMbps.add(tocDoTucThoi);
      }
      lanCapNhatCuoi = baygio;
      byteLucCapNhatCuoi = tongByteDaNhan;
    });

    final dsLoadedPing = <int>[];
    final futurePing = _guiPingTrongLucTai(client, dsLoadedPing, () => dangTai);

    await Future.wait(List.generate(_soLuongSongSong, (_) async {
      while (DateTime.now().isBefore(ketThucLuc)) {
        try {
          final request = http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=$kichThuocMoiLan'));
          final res = await client.send(request).timeout(const Duration(seconds: 12));
          await for (final doan in res.stream) {
            tongByteDaNhan += doan.length;
            if (DateTime.now().isAfter(ketThucLuc)) break;
          }
        } catch (_) {
          break;
        }
      }
    }));

    dangTai = false;
    await futurePing;
    timer.cancel();

    final ketQua = _tinhThongLuongOnDinh(dsMauThoiGian, dsMauMbps, tongByteDaNhan, DateTime.now().difference(batDau).inMilliseconds / 1000);
    dsLoadedPing.sort();
    final loadedLatency = dsLoadedPing.isNotEmpty ? dsLoadedPing[dsLoadedPing.length ~/ 2] : null;
    return (mbps: ketQua.mbps, loadedLatencyMs: loadedLatency, onDinh: ketQua.onDinh);
  }

  Future<({double mbps, int? loadedLatencyMs, bool onDinh})> _doTocDoTaiLen(http.Client client) async {
    const kichThuocMoiLan = 5 * 1000 * 1000;
    int tongByteDaGui = 0;
    final batDau = DateTime.now();
    final ketThucLuc = batDau.add(const Duration(seconds: _thoiLuongDoGiay));
    bool dangTai = true;

    final dsMauThoiGian = <double>[];
    final dsMauMbps = <double>[];
    DateTime lanCapNhatCuoi = batDau;
    int byteLucCapNhatCuoi = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final baygio = DateTime.now();
      final byteVuaGuiTrongKhoang = tongByteDaGui - byteLucCapNhatCuoi;
      final giayVuaTrongKhoang = baygio.difference(lanCapNhatCuoi).inMilliseconds / 1000;
      if (giayVuaTrongKhoang > 0) {
        final tocDoTucThoi = (byteVuaGuiTrongKhoang * 8) / giayVuaTrongKhoang / 1000000;
        if (mounted) _capNhatKim(tocDoTucThoi);
        dsMauThoiGian.add(baygio.difference(batDau).inMilliseconds / 1000);
        dsMauMbps.add(tocDoTucThoi);
      }
      lanCapNhatCuoi = baygio;
      byteLucCapNhatCuoi = tongByteDaGui;
    });

    final dsLoadedPing = <int>[];
    final futurePing = _guiPingTrongLucTai(client, dsLoadedPing, () => dangTai);

    await Future.wait(List.generate(_soLuongSongSong, (_) async {
      while (DateTime.now().isBefore(ketThucLuc)) {
        try {
          final duLieu = Uint8List.fromList(List.generate(kichThuocMoiLan, (_) => Random().nextInt(256)));
          await client.post(Uri.parse('https://speed.cloudflare.com/__up'), body: duLieu).timeout(const Duration(seconds: 10));
          tongByteDaGui += kichThuocMoiLan;
        } catch (_) {
          break;
        }
      }
    }));

    dangTai = false;
    await futurePing;
    timer.cancel();

    final ketQua = _tinhThongLuongOnDinh(dsMauThoiGian, dsMauMbps, tongByteDaGui, DateTime.now().difference(batDau).inMilliseconds / 1000);
    dsLoadedPing.sort();
    final loadedLatency = dsLoadedPing.isNotEmpty ? dsLoadedPing[dsLoadedPing.length ~/ 2] : null;
    return (mbps: ketQua.mbps, loadedLatencyMs: loadedLatency, onDinh: ketQua.onDinh);
  }

  /// Tính tốc độ CUỐI CÙNG từ CỬA SỔ ỔN ĐỊNH (bỏ qua 25% thời gian đầu - giai
  /// đoạn tăng tốc TCP) thay vì trung bình toàn bộ thời gian đo - đây là thay
  /// đổi phương pháp luận CỐT LÕI để khắc phục việc đo thấp hơn thực tế trên
  /// đường truyền nhanh. Đồng thời đánh giá ĐỘ ỔN ĐỊNH: nếu độ lệch chuẩn của
  /// các mẫu trong cửa sổ ổn định VƯỢT QUÁ 35% giá trị trung bình, coi là kết
  /// quả CHƯA ỔN ĐỊNH (mạng dao động mạnh) - khuyến nghị đo lại thay vì âm
  /// thầm nhận 1 con số không đáng tin.
  ({double mbps, bool onDinh}) _tinhThongLuongOnDinh(List<double> dsThoiGian, List<double> dsMbps, int tongByte, double tongGiay) {
    if (dsMbps.isEmpty || tongGiay <= 0) {
      return (mbps: 0, onDinh: false);
    }
    final mocBoQua = tongGiay * _tiLeBoQuaTangToc;
    final dsOnDinh = <double>[];
    for (var i = 0; i < dsThoiGian.length; i++) {
      if (dsThoiGian[i] >= mocBoQua) dsOnDinh.add(dsMbps[i]);
    }
    // Nếu cửa sổ ổn định quá ít mẫu (test quá ngắn/lỗi mạng giữa chừng) - dùng
    // tổng byte/tổng thời gian TOÀN BỘ làm phương án dự phòng, vẫn còn hơn 0.
    if (dsOnDinh.length < 3) {
      return (mbps: (tongByte * 8) / tongGiay / 1000000, onDinh: false);
    }
    final trungBinh = dsOnDinh.reduce((a, b) => a + b) / dsOnDinh.length;
    final phuongSai = dsOnDinh.map((v) => pow(v - trungBinh, 2)).reduce((a, b) => a + b) / dsOnDinh.length;
    final doLechChuan = sqrt(phuongSai);
    final onDinh = trungBinh > 0 ? (doLechChuan / trungBinh) <= 0.35 : false;
    return (mbps: trungBinh, onDinh: onDinh);
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
                      _serverColo != null ? 'Máy chủ: Cloudflare · $_serverColo' : 'Máy chủ: Cloudflare (tự động chọn điểm gần nhất)',
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
                    if (_idleLatencyMs != null) Expanded(child: _theKetQuaNho('Ping', '$_idleLatencyMs', 'ms', Icons.network_ping, Colors.orange)),
                    if (_idleLatencyMs != null && _tocDoTaiLenMbps != null) const SizedBox(width: 10),
                    if (_tocDoTaiLenMbps != null) Expanded(child: _theKetQuaNho('Tải lên', _tocDoTaiLenMbps!.toStringAsFixed(1), 'Mbps', Icons.upload, Colors.green)),
                  ],
                ),
                if (!_ketQuaOnDinh) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: .15), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade700, width: 1)),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Kết quả dao động khá lớn trong lúc đo - mạng có thể chưa ổn định. Nên đo lại để có kết quả đáng tin cậy hơn.', style: TextStyle(fontSize: 12))),
                    ]),
                  ),
                ],
                if (_jitterMs != null || _loadedLatencyTaiXuongMs != null || _loadedLatencyTaiLenMs != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chi tiết độ trễ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 6),
                        if (_jitterMs != null) Text('Jitter (độ rung tín hiệu): $_jitterMs ms', style: const TextStyle(fontSize: 12)),
                        if (_loadedLatencyTaiXuongMs != null) Text('Ping lúc đang tải xuống: $_loadedLatencyTaiXuongMs ms', style: const TextStyle(fontSize: 12)),
                        if (_loadedLatencyTaiLenMs != null) Text('Ping lúc đang tải lên: $_loadedLatencyTaiLenMs ms', style: const TextStyle(fontSize: 12)),
                        if (_idleLatencyMs != null && _loadedLatencyTaiXuongMs != null && (_loadedLatencyTaiXuongMs! - _idleLatencyMs!) > 200)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('⚠️ Độ trễ tăng mạnh khi tải dữ liệu - có dấu hiệu nghẽn mạng (bufferbloat).', style: TextStyle(fontSize: 11.5, color: Colors.deepOrange)),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_tocDoTaiXuongMbps != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                    child: Text(_danhGiaChatLuong(_tocDoTaiXuongMbps, _idleLatencyMs), style: const TextStyle(fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Đây KHÔNG PHẢI phép đo của Speedtest by Ookla. Kết quả đo qua máy chủ Cloudflare công khai - nếu Ookla dùng máy chủ Viettel gần bạn hơn, kết quả 2 bên có thể khác nhau dù cả 2 đều đo đúng - đó là do khác tuyến mạng, không phải lỗi tính toán.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 4),
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
