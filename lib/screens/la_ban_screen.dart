import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../theme.dart';

/// La bàn nâng cao - kim la bàn (cảm biến từ trường, đã LỌC RUNG bằng bộ
/// lọc trung bình trượt mũ để không bị giật lắc), mặt số 360° chi tiết 8
/// hướng chính/phụ, kèm GPS (Vĩ độ/Kinh độ/Cao độ/Địa chỉ), thước thủy cân
/// bằng, khóa hướng mục tiêu, và hướng dẫn hiệu chuẩn khi độ chính xác thấp.
class LaBanScreen extends StatefulWidget {
  const LaBanScreen({super.key});

  @override
  State<LaBanScreen> createState() => _LaBanScreenState();
}

class _LaBanScreenState extends State<LaBanScreen> {
  StreamSubscription<CompassEvent>? _dangKyLaBan;
  StreamSubscription<AccelerometerEvent>? _dangKyGiaToc;

  double? _huongThuc; // giá trị THÔ từ cảm biến, độ (0 = Bắc)
  double _huongDaLoc = 0; // giá trị ĐÃ LỌC RUNG - dùng để vẽ kim, mượt hơn nhiều
  double? _doChinhXac; // radian - null hoặc lớn = độ chính xác thấp, cần hiệu chuẩn
  bool _khongHoTroLaBan = false;

  double _nghiêngX = 0, _nghiêngY = 0; // dùng cho thước thủy, đã lọc rung tương tự

  bool _cheDoToi = true; // mặc định tối cho giống la bàn thật, có thể bật sáng
  double? _huongKhoa; // hướng mục tiêu đã khóa (null = chưa khóa)

  // ---- Trạng thái GPS ----
  bool _dangTaiGps = false;
  Position? _viTri;
  String? _diaChi;
  String? _loiGps;

  @override
  void initState() {
    super.initState();
    _batDauLaBan();
    _batDauCamBienNghieng();
  }

  void _batDauLaBan() {
    if (FlutterCompass.events == null) {
      setState(() => _khongHoTroLaBan = true);
      return;
    }
    _dangKyLaBan = FlutterCompass.events!.listen((event) {
      if (!mounted || event.heading == null) return;
      setState(() {
        _huongThuc = event.heading;
        _doChinhXac = event.accuracy;
        // ---- BỘ LỌC GIẢM RUNG (exponential moving average) - kim la bàn
        // cảm biến từ trường thô rất hay bị "giật" qua lại vài độ dù máy
        // đứng yên. Thay vì vẽ THẲNG giá trị thô, trộn dần vào giá trị đã
        // lọc trước đó (trộn 22% giá trị mới / giữ 78% giá trị cũ mỗi lần
        // cập nhật) - kim xoay MƯỢT hẳn mà vẫn bám sát hướng thật, không bị
        // trễ đáng kể. Xử lý riêng trường hợp "vòng qua 0°/360°" (VD từ
        // 359° sang 2°) để không bị lọc nhảy ngược lại gần 180°.
        var chenhLech = event.heading! - _huongDaLoc;
        if (chenhLech > 180) chenhLech -= 360;
        if (chenhLech < -180) chenhLech += 360;
        _huongDaLoc = (_huongDaLoc + chenhLech * 0.22) % 360;
        if (_huongDaLoc < 0) _huongDaLoc += 360;
      });
    });
  }

  void _batDauCamBienNghieng() {
    _dangKyGiaToc = accelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        // Lọc rung tương tự la bàn - gia tốc kế thô cũng rung khá nhiều.
        _nghiêngX = _nghiêngX * 0.85 + event.x * 0.15;
        _nghiêngY = _nghiêngY * 0.85 + event.y * 0.15;
      });
    });
  }

  @override
  void dispose() {
    _dangKyLaBan?.cancel();
    _dangKyGiaToc?.cancel();
    super.dispose();
  }

  String _tenHuong(double do_) {
    const tenHuong = ['Bắc', 'Đông Bắc', 'Đông', 'Đông Nam', 'Nam', 'Tây Nam', 'Tây', 'Tây Bắc'];
    final chiSo = (((do_ % 360) + 22.5) / 45).floor() % 8;
    return tenHuong[chiSo];
  }

  /// Độ chính xác THẤP -> cần hiệu chuẩn hình số 8. flutter_compass trả về
  /// accuracy dạng radian trên Android (giá trị CÀNG LỚN = càng KÉM chính
  /// xác) - null hoặc > ~0.5 rad (~28°) coi là cần hiệu chuẩn lại.
  bool get _canHieuChuan => _doChinhXac == null || _doChinhXac!.abs() > 0.5;

  Future<void> _layViTriGps() async {
    setState(() {
      _dangTaiGps = true;
      _loiGps = null;
    });
    try {
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
        setState(() {
          _loiGps = 'Chưa cấp quyền vị trí. Vào Cài đặt máy để cấp quyền cho app.';
          _dangTaiGps = false;
        });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _loiGps = 'Vui lòng bật định vị (GPS) trên máy.';
          _dangTaiGps = false;
        });
        return;
      }
      final viTri = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      String? diaChi;
      try {
        final ds = await placemarkFromCoordinates(viTri.latitude, viTri.longitude);
        if (ds.isNotEmpty) {
          final p = ds.first;
          diaChi = [p.street, p.subLocality, p.locality, p.administrativeArea].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (_) {
        // Không lấy được địa chỉ chữ (VD không có Internet) - vẫn giữ được
        // tọa độ số, không coi là lỗi nghiêm trọng làm hỏng cả tính năng.
      }
      if (!mounted) return;
      setState(() {
        _viTri = viTri;
        _diaChi = diaChi;
        _dangTaiGps = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loiGps = 'Không lấy được vị trí: $e';
        _dangTaiGps = false;
      });
    }
  }

  void _khoaMoHuong() {
    HapticFeedback.mediumImpact();
    setState(() {
      _huongKhoa = _huongKhoa == null ? _huongDaLoc : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mauNen = _cheDoToi ? const Color(0xFF0E0E10) : const Color(0xFFF5F5F7);
    final mauChu = _cheDoToi ? Colors.white : Colors.black87;
    final mauChuPhu = _cheDoToi ? Colors.grey.shade400 : Colors.grey.shade600;
    final mauMatSo = _cheDoToi ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: mauNen,
      appBar: AppBar(
        title: const Text('La bàn'),
        actions: [
          IconButton(
            icon: Icon(_cheDoToi ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: _cheDoToi ? 'Chuyển giao diện sáng' : 'Chuyển giao diện tối',
            onPressed: () => setState(() => _cheDoToi = !_cheDoToi),
          ),
        ],
      ),
      body: _khongHoTroLaBan
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Thiết bị không có cảm biến la bàn (từ trường).', textAlign: TextAlign.center, style: TextStyle(color: mauChuPhu)),
              ),
            )
          : _huongThuc == null
              ? const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        if (_canHieuChuan) _theHieuChuan(mauChu),
                        Text('${_huongDaLoc.toStringAsFixed(0)}°', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: mauChu)),
                        Text(_tenHuong(_huongDaLoc), style: TextStyle(fontSize: 16, color: mauChuPhu)),
                        if (_huongKhoa != null) _theChenhLechMucTieu(mauChu),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: CustomPaint(
                            painter: _VeMatLaBan(
                              huongHienTai: _huongDaLoc,
                              huongKhoa: _huongKhoa,
                              cheDoToi: _cheDoToi,
                            ),
                            child: Center(
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(color: mauMatSo, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)]),
                                child: const Icon(Icons.explore, color: AppTheme.viettelRed, size: 40),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _khoaMoHuong,
                          style: FilledButton.styleFrom(backgroundColor: _huongKhoa != null ? Colors.grey.shade700 : AppTheme.viettelRed),
                          icon: Icon(_huongKhoa != null ? Icons.lock_open : Icons.lock_outline),
                          label: Text(_huongKhoa != null ? 'Mở khóa hướng' : 'Khóa hướng hiện tại'),
                        ),
                        const SizedBox(height: 24),
                        _theThuocThuy(mauMatSo, mauChu, mauChuPhu),
                        const SizedBox(height: 16),
                        _theGps(mauMatSo, mauChu, mauChuPhu),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _theHieuChuan(Color mauChu) => Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.4))),
        child: Row(
          children: [
            const Icon(Icons.explore_off, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Độ chính xác thấp - xoay điện thoại theo hình số 8 (∞) vài lần để hiệu chuẩn lại la bàn.',
                style: TextStyle(color: Colors.amber.shade200, fontSize: 12.5),
              ),
            ),
          ],
        ),
      );

  Widget _theChenhLechMucTieu(Color mauChu) {
    var chenh = (_huongKhoa! - _huongDaLoc) % 360;
    if (chenh > 180) chenh -= 360;
    if (chenh < -180) chenh += 360;
    final daCanBang = chenh.abs() < 3;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: (daCanBang ? Colors.green : AppTheme.viettelRed).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(
          daCanBang ? '🎯 Đã đúng hướng mục tiêu (${_huongKhoa!.toStringAsFixed(0)}°)' : 'Mục tiêu ${_huongKhoa!.toStringAsFixed(0)}° · lệch ${chenh > 0 ? "phải" : "trái"} ${chenh.abs().toStringAsFixed(0)}°',
          style: TextStyle(color: daCanBang ? Colors.green.shade400 : AppTheme.viettelRedLight, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  /// Thước thủy đặt ngay dưới la bàn - dùng độ nghiêng trục X/Y của gia tốc
  /// kế để vẽ 1 bọt khí lệch khỏi tâm khi máy không nằm phẳng, y hệt thước
  /// thủy cơ khí thật.
  Widget _theThuocThuy(Color nen, Color chu, Color chuPhu) {
    // Trọng lực chuẩn ~9.8 m/s² khi máy nằm PHẲNG (trục Z hứng toàn bộ trọng
    // lực, X/Y ~0) - lệch X/Y càng nhiều nghĩa là máy càng nghiêng.
    final lechX = (_nghiêngX / 9.8).clamp(-1.0, 1.0);
    final lechY = (_nghiêngY / 9.8).clamp(-1.0, 1.0);
    final canBang = lechX.abs() < 0.03 && lechY.abs() < 0.03;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.horizontal_rule_rounded, color: chuPhu, size: 18),
              const SizedBox(width: 6),
              Text('Thước thủy cân bằng', style: TextStyle(color: chu, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              if (canBang) const Text('✅ Đã cân bằng', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            height: 140,
            child: CustomPaint(painter: _VeThuocThuy(lechX: lechX, lechY: lechY, canBang: canBang, cheDoToi: _cheDoToi)),
          ),
        ],
      ),
    );
  }

  Widget _theGps(Color nen, Color chu, Color chuPhu) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: nen, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: chuPhu, size: 18),
              const SizedBox(width: 6),
              Text('Vị trí GPS', style: TextStyle(color: chu, fontWeight: FontWeight.w600, fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: _dangTaiGps ? null : _layViTriGps,
                icon: _dangTaiGps
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.viettelRed))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_viTri == null ? 'Lấy vị trí' : 'Làm mới'),
              ),
            ],
          ),
          if (_loiGps != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_loiGps!, style: const TextStyle(color: Colors.orange, fontSize: 12.5))),
          if (_viTri != null) ...[
            const SizedBox(height: 6),
            _dongThongTin('Vĩ độ', _viTri!.latitude.toStringAsFixed(6), chu, chuPhu),
            _dongThongTin('Kinh độ', _viTri!.longitude.toStringAsFixed(6), chu, chuPhu),
            _dongThongTin('Cao độ', '${_viTri!.altitude.toStringAsFixed(1)} m', chu, chuPhu),
            if (_diaChi != null && _diaChi!.isNotEmpty) _dongThongTin('Địa chỉ', _diaChi!, chu, chuPhu),
          ],
        ],
      ),
    );
  }

  Widget _dongThongTin(String nhan, String giaTri, Color chu, Color chuPhu) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 62, child: Text(nhan, style: TextStyle(color: chuPhu, fontSize: 12.5))),
            Expanded(child: Text(giaTri, style: TextStyle(color: chu, fontSize: 12.5, fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

/// Vẽ mặt la bàn 360° chi tiết - vạch chia MỖI 15° (24 vạch), vạch DÀI hơn
/// tại 8 hướng chính (N/NE/E/SE/S/SW/W/NW), chữ hiển thị tại 4 hướng chính
/// N/Đ/N/T cho dễ đọc trên màn hình nhỏ, và kim đỏ LUÔN quay để chỉ đúng
/// hướng Bắc thật (bù trừ NGƯỢC với góc quay của máy).
class _VeMatLaBan extends CustomPainter {
  final double huongHienTai;
  final double? huongKhoa;
  final bool cheDoToi;
  _VeMatLaBan({required this.huongHienTai, required this.huongKhoa, required this.cheDoToi});

  @override
  void paint(Canvas canvas, Size size) {
    final tam = size.center(Offset.zero);
    final banKinh = size.width / 2 - 4;
    final mauVien = cheDoToi ? Colors.grey.shade800 : Colors.grey.shade300;
    final mauChu = cheDoToi ? Colors.white70 : Colors.black54;

    // Vòng viền ngoài
    canvas.drawCircle(tam, banKinh, Paint()..color = mauVien..style = PaintingStyle.stroke..strokeWidth = 1.6);

    // ---- Xoay TOÀN BỘ mặt số (vạch chia + chữ N/Đ/N/T) NGƯỢC CHIỀU với
    // hướng máy đang quay - đây là cách "mặt la bàn thật" hoạt động: khi
    // xoay điện thoại sang phải, các con số trên mặt số quay sang TRÁI để
    // hướng Bắc (số 0) vẫn luôn ở đúng vị trí Bắc thật ngoài đời. ----
    canvas.save();
    canvas.translate(tam.dx, tam.dy);
    canvas.rotate(-huongHienTai * math.pi / 180);
    canvas.translate(-tam.dx, -tam.dy);

    for (int deg = 0; deg < 360; deg += 15) {
      final laHuongChinh = deg % 90 == 0;
      final daiVach = laHuongChinh ? 16.0 : (deg % 45 == 0 ? 11.0 : 6.0);
      final goc = (deg - 90) * math.pi / 180; // -90 để 0° nằm ở ĐỈNH (12h) thay vì bên phải
      final ngoai = tam + Offset(math.cos(goc), math.sin(goc)) * banKinh;
      final trong = tam + Offset(math.cos(goc), math.sin(goc)) * (banKinh - daiVach);
      canvas.drawLine(
        ngoai,
        trong,
        Paint()
          ..color = deg == 0 ? AppTheme.viettelRed : mauVien
          ..strokeWidth = laHuongChinh ? 2.4 : 1.2,
      );
    }

    // Chữ 4 hướng chính - vẽ NGAY SAU KHI xoay hệ tọa độ để chữ xoay THEO mặt số
    _veChu(canvas, tam, banKinh - 30, 0, 'B', deo: true);
    _veChu(canvas, tam, banKinh - 30, 90, 'Đ', mau: mauChu);
    _veChu(canvas, tam, banKinh - 30, 180, 'N', mau: mauChu);
    _veChu(canvas, tam, banKinh - 30, 270, 'T', mau: mauChu);

    canvas.restore();

    // ---- Đánh dấu hướng MỤC TIÊU đã khóa (nếu có) - vẽ SAU KHI restore vì
    // vị trí này tính theo hướng THẬT (không xoay theo mặt số), là 1 điểm
    // CỐ ĐỊNH so với la bàn vật lý (giữ nguyên vị trí trên mặt số, không xoay
    // theo máy) - biểu diễn đúng "đây là hướng cố định trong không gian". ----
    if (huongKhoa != null) {
      canvas.save();
      canvas.translate(tam.dx, tam.dy);
      canvas.rotate((huongKhoa! - huongHienTai - 90) * math.pi / 180);
      canvas.translate(-tam.dx, -tam.dy);
      final diem = tam + Offset(banKinh - 8, 0);
      canvas.drawCircle(diem, 5, Paint()..color = Colors.amber);
      canvas.restore();
    }

    // Kim la bàn - LUÔN chỉ thẳng lên trên (đỉnh màn hình = hướng máy đang
    // hướng tới), vì mặt số đã tự xoay để bù hướng Bắc rồi, kim không cần
    // xoay thêm nữa (kim đại diện cho "hướng mũi điện thoại").
    final duongKim = Path()
      ..moveTo(tam.dx, tam.dy - banKinh + 40)
      ..lineTo(tam.dx - 14, tam.dy + 18)
      ..lineTo(tam.dx, tam.dy + 6)
      ..lineTo(tam.dx + 14, tam.dy + 18)
      ..close();
    canvas.drawPath(duongKim, Paint()..color = AppTheme.viettelRed);
  }

  void _veChu(Canvas canvas, Offset tam, double banKinh, double gocDo, String chu, {Color? mau, bool deo = false}) {
    final goc = (gocDo - 90) * math.pi / 180;
    final viTri = tam + Offset(math.cos(goc), math.sin(goc)) * banKinh;
    final tp = TextPainter(
      text: TextSpan(text: chu, style: TextStyle(color: deo ? AppTheme.viettelRed : mau, fontWeight: FontWeight.bold, fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, viTri - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _VeMatLaBan old) => old.huongHienTai != huongHienTai || old.huongKhoa != huongKhoa || old.cheDoToi != cheDoToi;
}

/// Vẽ thước thủy - bọt khí (chấm tròn) di chuyển lệch khỏi tâm theo hướng
/// nghiêng của máy, 2 vòng tròn tham chiếu để dễ ước lượng độ nghiêng.
class _VeThuocThuy extends CustomPainter {
  final double lechX, lechY;
  final bool canBang;
  final bool cheDoToi;
  _VeThuocThuy({required this.lechX, required this.lechY, required this.canBang, required this.cheDoToi});

  @override
  void paint(Canvas canvas, Size size) {
    final tam = size.center(Offset.zero);
    final banKinh = size.width / 2 - 10;
    final mauVien = cheDoToi ? Colors.grey.shade700 : Colors.grey.shade300;

    canvas.drawCircle(tam, banKinh, Paint()..color = mauVien..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(tam, banKinh * 0.5, Paint()..color = mauVien..style = PaintingStyle.stroke..strokeWidth = 1);
    canvas.drawLine(tam - Offset(banKinh, 0), tam + Offset(banKinh, 0), Paint()..color = mauVien..strokeWidth = 0.8);
    canvas.drawLine(tam - Offset(0, banKinh), tam + Offset(0, banKinh), Paint()..color = mauVien..strokeWidth = 0.8);

    // Bọt khí: nghiêng sang PHẢI (X dương) -> bọt lệch sang phải; nghiêng
    // NGỬA lên (Y dương thường nghĩa là đầu trên hạ xuống tùy cách cầm máy)
    // -> lệch xuống dưới - CHIỀU DẤU đã khớp thực tế qua thử nghiệm cầm máy
    // nằm ngang tự nhiên (mặt màn hình hướng lên trời).
    final viTriBot = tam + Offset(lechX * banKinh, -lechY * banKinh);
    canvas.drawCircle(viTriBot, 14, Paint()..color = (canBang ? Colors.green : AppTheme.viettelRed).withValues(alpha: 0.25));
    canvas.drawCircle(viTriBot, 8, Paint()..color = canBang ? Colors.green : AppTheme.viettelRed);
  }

  @override
  bool shouldRepaint(covariant _VeThuocThuy old) => old.lechX != lechX || old.lechY != lechY || old.canBang != canBang;
}
