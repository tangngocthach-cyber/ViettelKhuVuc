import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import '../theme.dart';

/// Smart Flashlight - dùng package `torch_light ^1.1.0`.
///
/// GIỚI HẠN THẬT CỦA PACKAGE (đã kiểm tra API trước khi viết file này):
/// `torch_light` CHỈ hỗ trợ Bật/Tắt (`enableTorch()`/`disableTorch()`), KHÔNG
/// có API điều chỉnh độ sáng/cường độ đèn (không có `setTorchStrength` hay
/// tương đương nào). Vì vậy tính năng "Độ sáng" trong bản đặc tả KHÔNG được
/// thêm vào - không giả lập bằng cách nhấp nháy nhanh hay bất kỳ thủ thuật
/// nào để "trông giống" điều chỉnh độ sáng, vì đó không phải độ sáng thật.
class DenPinScreen extends StatefulWidget {
  const DenPinScreen({super.key});

  @override
  State<DenPinScreen> createState() => _DenPinScreenState();
}

enum _CheDoNhapNhay { tat, cham, trungBinh, nhanh, sos }

class _DenPinScreenState extends State<DenPinScreen> with WidgetsBindingObserver {
  bool _dangKiemTra = true;
  bool? _coHoTro; // null = chưa xác định, true/false = đã hỏi thiết bị thật
  bool _dangBatThuc = false; // PHẢN ÁNH ĐÚNG trạng thái đèn THẬT SỰ - chỉ đổi SAU KHI gọi API thành công, không đoán trước
  String? _thongBaoLoi;
  _CheDoNhapNhay _cheDoNhapNhay = _CheDoNhapNhay.tat;
  int _theHeVongLap = 0; // đổi giá trị này để "hủy" vòng lặp nhấp nháy đang chạy (an toàn hơn dùng bool đơn thuần khi đổi chế độ liên tục)

  Duration? _thoiGianConLai;
  Timer? _dongHoDemNguoc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _kiemTraHoTro();
  }

  Future<void> _kiemTraHoTro() async {
    try {
      final coHoTro = await TorchLight.isTorchAvailable();
      if (mounted) setState(() { _coHoTro = coHoTro; _dangKiemTra = false; });
    } on Exception catch (e, stack) {
      // GHI LOG KỸ THUẬT THẬT - không dùng catch rỗng che lỗi.
      debugPrint('[DenPinScreen] Lỗi kiểm tra hỗ trợ đèn pin: $e');
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: stack, library: 'den_pin_screen'));
      if (mounted) setState(() { _coHoTro = false; _dangKiemTra = false; });
    }
  }

  /// Vòng đời app - TẮT NGAY đèn + dừng mọi hiệu ứng/hẹn giờ đang chạy khi
  /// app chuyển xuống nền (KHÔNG để đèn/nhấp nháy/đếm ngược tiếp tục chạy
  /// "vô hình" phía sau, vừa hao pin vừa có thể gây hiểu nhầm trạng thái).
  /// KHÔNG tự bật lại khi quay lại app - phải để người dùng tự bật lại, an
  /// toàn hơn (tránh đèn tự sáng bất ngờ trong túi quần gây nóng máy/hao pin
  /// mà người dùng không biết).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _dungHetTatCa();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dongHoDemNguoc?.cancel();
    _theHeVongLap++; // hủy mọi vòng lặp nhấp nháy đang chạy dở
    if (_dangBatThuc) {
      // Không thể await trong dispose() - gọi "bắn rồi quên" nhưng vẫn xử lý
      // lỗi đàng hoàng (log lại) thay vì catch rỗng, không chặn dispose().
      TorchLight.disableTorch().then((_) {}, onError: (e, stack) {
        debugPrint('[DenPinScreen] Lỗi tắt đèn lúc dispose(): $e');
      });
    }
    super.dispose();
  }

  Future<void> _dungHetTatCa() async {
    _dongHoDemNguoc?.cancel();
    _dongHoDemNguoc = null;
    _theHeVongLap++; // hủy vòng lặp nhấp nháy/SOS đang chạy
    if (mounted) setState(() { _cheDoNhapNhay = _CheDoNhapNhay.tat; _thoiGianConLai = null; });
    await _datTrangThaiDen(false);
  }

  /// Đặt trạng thái đèn THẬT qua torch_light - CHỈ cập nhật `_dangBatThuc`
  /// SAU KHI gọi API thành công (không đoán trước UI = trạng thái thật).
  Future<bool> _datTrangThaiDen(bool bat) async {
    if (_dangBatThuc == bat) return true; // đã đúng trạng thái, khỏi gọi lại API thừa
    try {
      if (bat) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      if (mounted) setState(() { _dangBatThuc = bat; _thongBaoLoi = null; });
      return true;
    } on Exception catch (e, stack) {
      debugPrint('[DenPinScreen] Lỗi ${bat ? "bật" : "tắt"} đèn: $e');
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: stack, library: 'den_pin_screen'));
      if (mounted) {
        setState(() {
          // RESET UI VỀ ĐÚNG TRẠNG THÁI THẬT - không giữ UI hiện sai lệch
          // với thiết bị thật khi có lỗi.
          _dangBatThuc = false;
          _thongBaoLoi = bat
              ? 'Không bật được đèn pin - có thể camera đang được ứng dụng khác sử dụng, hoặc thiết bị không hỗ trợ.'
              : 'Không tắt được đèn pin - vui lòng thử lại.';
        });
      }
      return false;
    }
  }

  Future<void> _bamNutChinh() async {
    if (_cheDoNhapNhay != _CheDoNhapNhay.tat) {
      // Đang ở chế độ nhấp nháy/SOS - bấm nút chính = DỪNG NGAY hiệu ứng.
      await _dungHetTatCa();
      return;
    }
    await _datTrangThaiDen(!_dangBatThuc);
  }

  /// Chạy 1 vòng lặp bật/tắt theo đúng mẫu thời gian (dùng chung cho cả chế
  /// độ Nhấp nháy thường lẫn SOS - chỉ khác nhau ở mẫu thời gian truyền vào).
  /// Kiểm tra `_theHeVongLap` sau MỖI bước chờ - phát hiện NGAY nếu người
  /// dùng đã bấm dừng/đổi chế độ khác/rời màn hình, không chạy thừa dù chỉ 1
  /// bước sau khi đã hủy.
  Future<void> _chayVongLapNhapNhay(List<({bool bat, Duration keoDai})> mauThoiGian) async {
    final theHeCuaVongLapNay = _theHeVongLap;
    while (mounted && theHeCuaVongLapNay == _theHeVongLap) {
      for (final buoc in mauThoiGian) {
        if (!mounted || theHeCuaVongLapNay != _theHeVongLap) return;
        await _datTrangThaiDen(buoc.bat);
        await Future.delayed(buoc.keoDai);
      }
    }
  }

  static const _donVi = Duration(milliseconds: 200); // 1 đơn vị Morse chuẩn cho chế độ SOS

  void _batCheDoNhapNhay(_CheDoNhapNhay cheDo) {
    _theHeVongLap++; // hủy vòng lặp cũ (nếu có) trước khi bắt đầu cái mới
    setState(() => _cheDoNhapNhay = cheDo);

    switch (cheDo) {
      case _CheDoNhapNhay.cham:
        _chayVongLapNhapNhay([(bat: true, keoDai: const Duration(milliseconds: 800)), (bat: false, keoDai: const Duration(milliseconds: 800))]);
        break;
      case _CheDoNhapNhay.trungBinh:
        _chayVongLapNhapNhay([(bat: true, keoDai: const Duration(milliseconds: 400)), (bat: false, keoDai: const Duration(milliseconds: 400))]);
        break;
      case _CheDoNhapNhay.nhanh:
        _chayVongLapNhapNhay([(bat: true, keoDai: const Duration(milliseconds: 150)), (bat: false, keoDai: const Duration(milliseconds: 150))]);
        break;
      case _CheDoNhapNhay.sos:
        // Chuẩn Morse S-O-S: 3 chấm (ngắn) - 3 gạch (dài gấp 3) - 3 chấm.
        final cham = (bat: true, keoDai: _donVi);
        final ganCham = (bat: false, keoDai: _donVi);
        final gach = (bat: true, keoDai: _donVi * 3);
        final ganGach = (bat: false, keoDai: _donVi);
        final ganChu = (bat: false, keoDai: _donVi * 3);
        final ganLapLai = (bat: false, keoDai: _donVi * 7);
        _chayVongLapNhapNhay([
          cham, ganCham, cham, ganCham, cham, ganChu,
          gach, ganGach, gach, ganGach, gach, ganChu,
          cham, ganCham, cham, ganCham, cham, ganLapLai,
        ]);
        break;
      case _CheDoNhapNhay.tat:
        break;
    }
  }

  void _datHenGio(Duration thoiLuong) {
    _dongHoDemNguoc?.cancel();
    setState(() => _thoiGianConLai = thoiLuong);
    _dongHoDemNguoc = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final conLai = _thoiGianConLai! - const Duration(seconds: 1);
      if (conLai.inSeconds <= 0) {
        t.cancel();
        setState(() => _thoiGianConLai = null);
        _dungHetTatCa();
      } else {
        setState(() => _thoiGianConLai = conLai);
      }
    });
  }

  void _huyHenGio() {
    _dongHoDemNguoc?.cancel();
    _dongHoDemNguoc = null;
    setState(() => _thoiGianConLai = null);
  }

  Future<void> _hoiHenGioTuyChinh() async {
    final oNhap = TextEditingController();
    final soPhut = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hẹn giờ tắt (tùy chỉnh)'),
        content: TextField(
          controller: oNhap,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Số phút', suffixText: 'phút'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, int.tryParse(oNhap.text)), child: const Text('Đặt')),
        ],
      ),
    );
    if (soPhut != null && soPhut > 0) _datHenGio(Duration(minutes: soPhut));
  }

  String _dinhDangDemNguoc(Duration d) {
    final phut = d.inMinutes.toString().padLeft(2, '0');
    final giay = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$phut:$giay';
  }

  @override
  Widget build(BuildContext context) {
    if (_dangKiemTra) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_coHoTro == false) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Đèn pin'), backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Thiết bị không hỗ trợ đèn pin.', style: TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final dangHoatDong = _dangBatThuc || _cheDoNhapNhay != _CheDoNhapNhay.tat;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Đèn pin'),
        backgroundColor: dangHoatDong ? AppTheme.viettelRed : Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _bamNutChinh,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dangHoatDong ? AppTheme.viettelRed : Colors.grey.shade800,
                      boxShadow: dangHoatDong
                          ? [BoxShadow(color: AppTheme.viettelRed.withValues(alpha: .45), blurRadius: 36, spreadRadius: 8)]
                          : const [],
                    ),
                    child: Icon(dangHoatDong ? Icons.flashlight_on : Icons.flashlight_off, size: 68, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _cheDoNhapNhay != _CheDoNhapNhay.tat ? 'ĐANG NHẤP NHÁY' : (_dangBatThuc ? 'ĐÈN ĐANG BẬT' : 'ĐÃ TẮT'),
                  style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                if (_thongBaoLoi != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(_thongBaoLoi!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ],

                const SizedBox(height: 30),
                _tieuDeMuc('Chế độ nhấp nháy'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _chipCheDo('Chậm', _CheDoNhapNhay.cham),
                      _chipCheDo('Trung bình', _CheDoNhapNhay.trungBinh),
                      _chipCheDo('Nhanh', _CheDoNhapNhay.nhanh),
                      _chipCheDo('🆘 SOS', _CheDoNhapNhay.sos),
                    ],
                  ),
                ),
                if (_cheDoNhapNhay != _CheDoNhapNhay.tat)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                      onPressed: _dungHetTatCa,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Dừng ngay'),
                    ),
                  ),

                const SizedBox(height: 26),
                _tieuDeMuc('Hẹn giờ tắt'),
                if (_thoiGianConLai != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        Text(_dinhDangDemNguoc(_thoiGianConLai!), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                        TextButton(onPressed: _huyHenGio, child: const Text('Hủy hẹn giờ', style: TextStyle(color: Colors.white70))),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _chipHenGio('1 phút', const Duration(minutes: 1)),
                      _chipHenGio('5 phút', const Duration(minutes: 5)),
                      _chipHenGio('10 phút', const Duration(minutes: 10)),
                      _chipHenGio('30 phút', const Duration(minutes: 30)),
                      ActionChip(
                        label: const Text('Tùy chỉnh'),
                        backgroundColor: Colors.grey.shade900,
                        labelStyle: const TextStyle(color: Colors.white70),
                        onPressed: _hoiHenGioTuyChinh,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tieuDeMuc(String ten) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(ten, style: const TextStyle(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: .5)),
      );

  Widget _chipCheDo(String nhan, _CheDoNhapNhay cheDo) {
    final dangChon = _cheDoNhapNhay == cheDo;
    return ChoiceChip(
      label: Text(nhan),
      selected: dangChon,
      selectedColor: AppTheme.viettelRed,
      backgroundColor: Colors.grey.shade900,
      labelStyle: TextStyle(color: dangChon ? Colors.white : Colors.white70, fontWeight: dangChon ? FontWeight.bold : FontWeight.normal),
      onSelected: (chon) {
        if (chon) {
          _huyHenGio();
          _batCheDoNhapNhay(cheDo);
        } else {
          _dungHetTatCa();
        }
      },
    );
  }

  Widget _chipHenGio(String nhan, Duration thoiLuong) {
    return ActionChip(
      label: Text(nhan),
      backgroundColor: Colors.grey.shade900,
      labelStyle: const TextStyle(color: Colors.white70),
      onPressed: () async {
        if (_cheDoNhapNhay == _CheDoNhapNhay.tat && !_dangBatThuc) {
          final batDuoc = await _datTrangThaiDen(true);
          if (!batDuoc) return;
        }
        _datHenGio(thoiLuong);
      },
    );
  }
}
