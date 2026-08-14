import 'package:flutter/material.dart';
import '../models/ruler_calibration.dart';
import '../models/ruler_measurement.dart';
import '../services/ruler_calibration_service.dart';
import '../theme.dart';

/// Smart Ruler - thước đo tương tác dựa trên kích thước màn hình đã HIỆU
/// CHUẨN theo máy thật (không dùng lý thuyết "160dp/inch" suông - lý thuyết
/// đó LUÔN có sai số thật trên nhiều máy, đã xác nhận qua ảnh chụp thước cũ
/// bị nén sai tỉ lệ). Cho phép chạm-kéo đo khoảng cách A→B trực tiếp trên
/// thước, khóa kết quả, lưu lại lịch sử.
///
/// KHÔNG có tính năng đo bằng Camera/AR trong bản này - dự án hiện CHƯA có
/// package `camera` hay bất kỳ package AR nào (đã kiểm tra pubspec.yaml
/// trước khi viết file này) - theo đúng nguyên tắc "không thêm dependency
/// nếu không thực sự cần" và "không tự tạo thuật toán đo giả", tính năng đó
/// KHÔNG được thêm vào ở đây. Muốn làm cần 1 phiên riêng để thêm package
/// `camera` và kiểm thử kỹ trên thiết bị thật trước.
class ThuocDoScreen extends StatefulWidget {
  const ThuocDoScreen({super.key});

  @override
  State<ThuocDoScreen> createState() => _ThuocDoScreenState();
}

class _ThuocDoScreenState extends State<ThuocDoScreen> {
  RulerCalibration _hieuChuan = RulerCalibration.macDinh();
  String _donVi = 'cm';
  double? _diemA;
  double? _diemB;
  bool _daKhoa = false;
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _taiHieuChuan();
  }

  Future<void> _taiHieuChuan() async {
    final hc = await RulerCalibrationService.layHieuChuan();
    if (mounted) setState(() { _hieuChuan = hc; _dangTai = false; });
  }

  void _datLai() {
    setState(() { _diemA = null; _diemB = null; _daKhoa = false; });
  }

  Future<void> _moManHinhHieuChuan() async {
    final ketQua = await Navigator.push<RulerCalibration>(
      context,
      MaterialPageRoute(builder: (_) => _ManHinhHieuChuan(hieuChuanHienTai: _hieuChuan)),
    );
    if (ketQua != null && mounted) {
      setState(() => _hieuChuan = ketQua);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã lưu hiệu chuẩn - thước sẽ đo chính xác hơn trên máy này.')));
    }
  }

  Future<void> _luuKetQua(double giaTri) async {
    await RulerCalibrationService.themVaoLichSu(giaTri, _donVi);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Đã lưu ${giaTri.toStringAsFixed(2)} $_donVi vào lịch sử.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_dangTai) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final dpMoiDonVi = _hieuChuan.dpToiDonVi(_donVi);
    RulerMeasurement? phepDo;
    if (_diemA != null && _diemB != null) phepDo = RulerMeasurement(diemA: _diemA!, diemB: _diemB!);
    final giaTriHienThi = phepDo?.doDaiTheoDonVi(_hieuChuan, _donVi);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thước đo'),
        actions: [
          IconButton(icon: const Icon(Icons.history), tooltip: 'Lịch sử đã lưu', onPressed: () => _hienLichSu(context)),
        ],
      ),
      body: Column(
        children: [
          if (!_hieuChuan.daHieuChuan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade50,
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Chưa hiệu chuẩn - thước dùng ước lượng lý thuyết, CÓ THỂ SAI LỆCH. Bấm "Hiệu chuẩn" bên dưới để đo chính xác hơn theo đúng máy này.', style: TextStyle(fontSize: 12))),
              ]),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.green.shade50,
              child: Row(children: [
                Icon(Icons.verified, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 6),
                const Text('Đã hiệu chuẩn theo máy này', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Text(
                  giaTriHienThi != null ? '${giaTriHienThi.toStringAsFixed(2)} $_donVi' : '-- $_donVi',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _daKhoa ? '🔒 Đã khóa kết quả' : (phepDo != null ? 'Đang đo...' : 'Chạm và kéo trên thước để đo'),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['mm', 'cm', 'inch'].map((dv) {
                final dangChon = dv == _donVi;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: dangChon ? AppTheme.viettelRed : null,
                        foregroundColor: dangChon ? Colors.white : AppTheme.viettelRed,
                        side: BorderSide(color: AppTheme.viettelRed),
                      ),
                      onPressed: () => setState(() => _donVi = dv),
                      child: Text(dv),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanStart: _daKhoa ? null : (d) => setState(() { _diemA = d.localPosition.dy; _diemB = d.localPosition.dy; }),
                    onPanUpdate: _daKhoa ? null : (d) => setState(() => _diemB = d.localPosition.dy.clamp(0.0, constraints.maxHeight)),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: _ThuocVePainter(dpMoiDonVi: dpMoiDonVi, donVi: _donVi, diemA: _diemA, diemB: _diemB),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _moManHinhHieuChuan, icon: const Icon(Icons.straighten), label: const Text('Hiệu chuẩn'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: phepDo != null ? _datLai : null, icon: const Icon(Icons.refresh), label: const Text('Đặt lại'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: phepDo != null ? () => setState(() => _daKhoa = !_daKhoa) : null,
                      icon: Icon(_daKhoa ? Icons.lock_open : Icons.lock),
                      label: Text(_daKhoa ? 'Mở khóa / Đo lại' : 'Khóa kết quả'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.viettelRed, foregroundColor: Colors.white),
                      onPressed: giaTriHienThi != null && giaTriHienThi > 0 ? () => _luuKetQua(giaTriHienThi) : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _hienLichSu(BuildContext context) async {
    final ds = await RulerCalibrationService.layLichSu();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(14), child: Text('Kết quả đã lưu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            if (ds.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Chưa có kết quả nào được lưu.')),
            ...ds.map((k) => ListTile(
                  leading: const Icon(Icons.straighten),
                  title: Text('${k.giaTri.toStringAsFixed(2)} ${k.donVi}'),
                  subtitle: Text('${k.thoiGian.day}/${k.thoiGian.month}/${k.thoiGian.year} ${k.thoiGian.hour}:${k.thoiGian.minute.toString().padLeft(2, '0')}'),
                )),
          ],
        ),
      ),
    );
  }
}

/// Vẽ thước đo dọc theo đúng hệ số hiệu chuẩn (KHÔNG dùng số cứng), kèm 2
/// đường đánh dấu điểm A/B và vùng tô đậm khoảng đang đo.
class _ThuocVePainter extends CustomPainter {
  final double dpMoiDonVi;
  final String donVi;
  final double? diemA;
  final double? diemB;
  _ThuocVePainter({required this.dpMoiDonVi, required this.donVi, this.diemA, this.diemB});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    if (diemA != null && diemB != null) {
      final top = diemA! < diemB! ? diemA! : diemB!;
      final bottom = diemA! < diemB! ? diemB! : diemA!;
      canvas.drawRect(Rect.fromLTRB(0, top, size.width, bottom), Paint()..color = AppTheme.viettelRed.withValues(alpha: .1));
      final sonDanhDau = Paint()..color = AppTheme.viettelRed..strokeWidth = 2.5;
      canvas.drawLine(Offset(0, top), Offset(size.width, top), sonDanhDau);
      canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), sonDanhDau);
    }

    final sonNet = Paint()..color = Colors.black87..strokeWidth = 1.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final soDonViToiDa = (size.height / dpMoiDonVi).floor();
    final soChiaNho = donVi == 'inch' ? 8 : 10;

    for (int donViSo = 0; donViSo <= soDonViToiDa; donViSo++) {
      final yGoc = donViSo * dpMoiDonVi;
      canvas.drawLine(Offset(0, yGoc), Offset(60, yGoc), sonNet);
      textPainter.text = TextSpan(text: '$donViSo', style: const TextStyle(color: Colors.black87, fontSize: 13));
      textPainter.layout();
      textPainter.paint(canvas, Offset(66, yGoc - 7));

      if (donViSo < soDonViToiDa) {
        for (int chiaNho = 1; chiaNho < soChiaNho; chiaNho++) {
          final yChiaNho = yGoc + (dpMoiDonVi * chiaNho / soChiaNho);
          final doDaiVach = (chiaNho == soChiaNho / 2) ? 40.0 : 24.0;
          canvas.drawLine(Offset(0, yChiaNho), Offset(doDaiVach, yChiaNho), sonNet);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThuocVePainter oldDelegate) =>
      oldDelegate.dpMoiDonVi != dpMoiDonVi || oldDelegate.donVi != donVi || oldDelegate.diemA != diemA || oldDelegate.diemB != diemB;
}

/// Màn hiệu chuẩn - người dùng đặt vật chuẩn (thẻ ATM/CCCD hoặc vật tự chọn
/// kích thước) lên màn hình, kéo khớp đúng chiều dài rồi xác nhận. KHÔNG có
/// công thức nào thay thế được bước này - đây LÀ cách duy nhất biết chính
/// xác mật độ điểm ảnh THẬT của máy đang dùng.
class _ManHinhHieuChuan extends StatefulWidget {
  final RulerCalibration hieuChuanHienTai;
  const _ManHinhHieuChuan({required this.hieuChuanHienTai});

  @override
  State<_ManHinhHieuChuan> createState() => _ManHinhHieuChuanState();
}

class _ManHinhHieuChuanState extends State<_ManHinhHieuChuan> {
  VatChuanHieuChuan _vatChuanDangChon = VatChuanHieuChuan.cacVatChuanCoSan.first;
  final _oNhapKichThuoc = TextEditingController();
  bool _dungKichThuocTuNhap = false;
  double _doDaiDp = 200;

  double get _kichThuocThatCm {
    if (_dungKichThuocTuNhap) return double.tryParse(_oNhapKichThuoc.text.replaceAll(',', '.')) ?? 0;
    return _vatChuanDangChon.kichThuocCm;
  }

  @override
  void initState() {
    super.initState();
    _doDaiDp = widget.hieuChuanHienTai.dpMoiCm * _vatChuanDangChon.kichThuocCm;
  }

  @override
  void dispose() {
    _oNhapKichThuoc.dispose();
    super.dispose();
  }

  void _luu() {
    final kichThuoc = _kichThuocThatCm;
    if (kichThuoc <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đúng kích thước vật chuẩn (cm), phải lớn hơn 0.')));
      return;
    }
    final hcMoi = RulerCalibration.tuDoDacThuc(khoangCachDp: _doDaiDp, kichThuocThatCm: kichThuoc);
    RulerCalibrationService.luuHieuChuan(hcMoi);
    Navigator.pop(context, hcMoi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hiệu chuẩn thước đo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Chọn vật chuẩn (kích thước THẬT đã biết trước):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...VatChuanHieuChuan.cacVatChuanCoSan.map((v) => RadioListTile<VatChuanHieuChuan>(
                  value: v,
                  groupValue: _dungKichThuocTuNhap ? null : _vatChuanDangChon,
                  title: Text(v.ten),
                  subtitle: Text('${v.kichThuocCm} cm'),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() { _vatChuanDangChon = val!; _dungKichThuocTuNhap = false; }),
                )),
            RadioListTile<bool>(
              value: true,
              groupValue: _dungKichThuocTuNhap ? true : null,
              title: const Text('Tự nhập kích thước khác (cm)'),
              contentPadding: EdgeInsets.zero,
              onChanged: (_) => setState(() => _dungKichThuocTuNhap = true),
            ),
            if (_dungKichThuocTuNhap)
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: TextField(
                  controller: _oNhapKichThuoc,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Kích thước thật (cm)', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            const SizedBox(height: 20),
            const Text('2. Đặt vật chuẩn lên màn hình, kéo chấm đỏ cho khớp ĐÚNG chiều dài vật:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final doDaiToiDa = constraints.maxWidth - 20;
                return SizedBox(
                  height: 90,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 10,
                        top: 40,
                        child: Container(width: _doDaiDp.clamp(10, doDaiToiDa), height: 6, color: AppTheme.viettelRed),
                      ),
                      Positioned(left: 10, top: 20, child: Container(width: 2, height: 46, color: Colors.black87)),
                      Positioned(
                        left: 10 + _doDaiDp.clamp(10, doDaiToiDa) - 14,
                        top: 15,
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(() => _doDaiDp = (_doDaiDp + d.delta.dx).clamp(10.0, doDaiToiDa)),
                          child: Container(
                            width: 28, height: 56,
                            decoration: BoxDecoration(color: AppTheme.viettelRed, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                            child: const Icon(Icons.drag_indicator, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.viettelRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _luu,
                icon: const Icon(Icons.check),
                label: const Text('Lưu hiệu chuẩn'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
