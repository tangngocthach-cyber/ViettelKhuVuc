import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';
import '../services/reminder_notification_service.dart';

/// ID thông báo DÀNH RIÊNG cho Đồng hồ hẹn giờ - chọn số RẤT LỚN, ngoài
/// phạm vi ID tin nhắn thật (message_id trong CSDL Chat) để KHÔNG BAO GIỜ
/// trùng/ghi đè lịch nhắc hẹn của Chat khi tái sử dụng chung 1 dịch vụ
/// thông báo (ReminderNotificationService).
const _idThongBaoHenGio = 987654321;

/// Bộ công cụ Đồng hồ - 3 chế độ trong 1 màn hình (dùng chung AppBar/TabBar):
///  - Bấm giờ (Stopwatch): đếm lên, lưu vòng (lap), xuất CSV.
///  - Hẹn giờ (Timer): đếm ngược từ 1 khoảng thời gian chọn sẵn, BÁO ĐƯỢC dù
///    tắt màn hình/thoát app (đặt lịch thông báo cục bộ thật sự, không chỉ
///    dựa vào Timer của Dart - Timer sẽ NGỪNG chạy nếu OS đóng băng app).
///  - Luyện tập ngắt quãng (Interval/HIIT): lặp lại chu kỳ Làm việc/Nghỉ
///    theo số hiệp đã đặt.
class DongHoBamGioScreen extends StatefulWidget {
  const DongHoBamGioScreen({super.key});

  @override
  State<DongHoBamGioScreen> createState() => _DongHoBamGioScreenState();
}

class _DongHoBamGioScreenState extends State<DongHoBamGioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đồng hồ bấm giờ'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Bấm giờ'),
            Tab(text: 'Hẹn giờ'),
            Tab(text: 'Ngắt quãng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TabBamGio(), _TabHenGio(), _TabNgatQuang()],
      ),
    );
  }
}

/// Định dạng Duration -> "GIỜ:PHÚT:GIÂY.PHẦN_TRĂM_GIÂY" (bỏ phần GIỜ nếu = 0
/// để đỡ rối mắt cho các phép đếm ngắn, đúng thói quen đồng hồ bấm giờ thật).
String _dinhDangThoiGian(Duration d, {bool coMili = true}) {
  final am = d.isNegative;
  final dTuyetDoi = d.abs();
  final gio = dTuyetDoi.inHours;
  final phut = dTuyetDoi.inMinutes.remainder(60);
  final giay = dTuyetDoi.inSeconds.remainder(60);
  final phanTramGiay = (dTuyetDoi.inMilliseconds.remainder(1000) / 10).floor();
  final phanGio = gio > 0 ? '${gio.toString().padLeft(2, '0')}:' : '';
  final phanMili = coMili ? '.${phanTramGiay.toString().padLeft(2, '0')}' : '';
  return '${am ? '-' : ''}$phanGio${phut.toString().padLeft(2, '0')}:${giay.toString().padLeft(2, '0')}$phanMili';
}

// =============================================================================
// TAB 1: BẤM GIỜ (Stopwatch + Lap)
// =============================================================================

class _Vong {
  final Duration tongThoiGian;
  final Duration chenhLech;
  _Vong({required this.tongThoiGian, required this.chenhLech});
}

class _TabBamGio extends StatefulWidget {
  const _TabBamGio();
  @override
  State<_TabBamGio> createState() => _TabBamGioState();
}

class _TabBamGioState extends State<_TabBamGio> {
  // ---- Tính thời gian trôi qua dựa trên MỐC THỜI GIAN THỰC (DateTime), KHÔNG
  // chỉ dựa vào việc Timer.periodic có "tích tắc đủ số lần" hay không - vì
  // khi màn hình tắt/app bị hệ điều hành tạm dừng nền, Timer có thể bị delay
  // hoặc ngừng tích tắc, nhưng CÔNG THỨC "giờ hiện tại - giờ bắt đầu" vẫn cho
  // ra kết quả ĐÚNG ngay khi app hoạt động trở lại - đây là cách duy nhất để
  // "chạy nền chuẩn xác" mà không cần viết Foreground Service gốc Android
  // (phức tạp, rủi ro cao, ngoài phạm vi 1 tiện ích đơn giản). ----
  DateTime? _thoiDiemBatDau;
  Duration _thoiGianDaTichLuy = Duration.zero;
  Timer? _timerCapNhatUI;
  bool _dangChay = false;
  final List<_Vong> _dsVong = [];

  Duration get _thoiGianHienTai => _thoiGianDaTichLuy + (_dangChay ? DateTime.now().difference(_thoiDiemBatDau!) : Duration.zero);

  void _batDauTamDung() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_dangChay) {
        _thoiGianDaTichLuy = _thoiGianHienTai;
        _dangChay = false;
        _timerCapNhatUI?.cancel();
      } else {
        _thoiDiemBatDau = DateTime.now();
        _dangChay = true;
        _timerCapNhatUI = Timer.periodic(const Duration(milliseconds: 30), (_) => setState(() {}));
      }
    });
  }

  void _luuVong() {
    if (!_dangChay) return;
    HapticFeedback.lightImpact();
    final tongHienTai = _thoiGianHienTai;
    final chenhLech = _dsVong.isEmpty ? tongHienTai : tongHienTai - _dsVong.first.tongThoiGian;
    setState(() => _dsVong.insert(0, _Vong(tongThoiGian: tongHienTai, chenhLech: chenhLech)));
  }

  void _xoaVong(int index) => setState(() => _dsVong.removeAt(index));

  void _datLaiTatCa() {
    setState(() {
      _dangChay = false;
      _timerCapNhatUI?.cancel();
      _thoiGianDaTichLuy = Duration.zero;
      _thoiDiemBatDau = null;
      _dsVong.clear();
    });
  }

  Future<void> _xuatCsv() async {
    if (_dsVong.isEmpty) return;
    final buffer = StringBuffer('Vong,Thoi gian vong,Tong thoi gian\n');
    final tongSo = _dsVong.length;
    for (int i = 0; i < _dsVong.length; i++) {
      final v = _dsVong[_dsVong.length - 1 - i]; // ghi theo thứ tự vòng 1 -> vòng cuối
      buffer.writeln('${i + 1},${_dinhDangThoiGian(v.chenhLech)},${_dinhDangThoiGian(v.tongThoiGian)}');
    }
    try {
      final thuMuc = await getTemporaryDirectory();
      final file = File('${thuMuc.path}/vong_bam_gio_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Kết quả $tongSo vòng bấm giờ');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xuất được file: $e')));
    }
  }

  @override
  void dispose() {
    _timerCapNhatUI?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Duration? nhanhNhat, chamNhat;
    if (_dsVong.length >= 2) {
      nhanhNhat = _dsVong.map((v) => v.chenhLech).reduce((a, b) => a < b ? a : b);
      chamNhat = _dsVong.map((v) => v.chenhLech).reduce((a, b) => a > b ? a : b);
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Text(
            _dinhDangThoiGian(_thoiGianHienTai),
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 78, height: 78,
                child: OutlinedButton(
                  onPressed: !_dangChay ? null : _luuVong,
                  style: OutlinedButton.styleFrom(shape: const CircleBorder()),
                  child: const Text('Vòng'),
                ),
              ),
              const SizedBox(width: 22),
              SizedBox(
                width: 78, height: 78,
                child: ElevatedButton(
                  onPressed: _batDauTamDung,
                  style: ElevatedButton.styleFrom(backgroundColor: _dangChay ? Colors.red : Colors.green, shape: const CircleBorder()),
                  child: Text(_dangChay ? 'Dừng' : (_thoiGianDaTichLuy > Duration.zero ? 'Tiếp tục' : 'Bắt đầu'), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 22),
              SizedBox(
                width: 78, height: 78,
                child: OutlinedButton(
                  onPressed: (_dsVong.isEmpty && _thoiGianDaTichLuy == Duration.zero) ? null : _datLaiTatCa,
                  style: OutlinedButton.styleFrom(shape: const CircleBorder(), foregroundColor: Colors.grey),
                  child: const Text('Đặt lại'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_dsVong.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: _xuatCsv, icon: const Icon(Icons.ios_share, size: 16), label: const Text('Xuất CSV')),
              ),
            ),
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
                            SizedBox(width: 52, child: Text('Vòng $soThuTuVong', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
                            Expanded(
                              child: Text(
                                '+${_dinhDangThoiGian(v.chenhLech)}',
                                style: TextStyle(fontFeatures: const [FontFeature.tabularFigures()], color: mauChenhLech, fontWeight: mauChenhLech != null ? FontWeight.bold : null),
                              ),
                            ),
                            Text(_dinhDangThoiGian(v.tongThoiGian), style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontFeatures: const [FontFeature.tabularFigures()])),
                            IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: () => _xoaVong(i), tooltip: 'Xóa vòng này', visualDensity: VisualDensity.compact),
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

// =============================================================================
// TAB 2: HẸN GIỜ (Countdown Timer) - báo được dù tắt màn hình/thoát app
// =============================================================================

class _TabHenGio extends StatefulWidget {
  const _TabHenGio();
  @override
  State<_TabHenGio> createState() => _TabHenGioState();
}

class _TabHenGioState extends State<_TabHenGio> {
  int _gioChon = 0, _phutChon = 5, _giayChon = 0;
  DateTime? _thoiDiemKetThuc;
  Timer? _timer;
  bool _dangChay = false;
  bool _daBaoXong = false;

  Duration get _tongThoiGianDat => Duration(hours: _gioChon, minutes: _phutChon, seconds: _giayChon);
  Duration get _thoiGianConLai {
    if (_thoiDiemKetThuc == null) return _tongThoiGianDat;
    final conLai = _thoiDiemKetThuc!.difference(DateTime.now());
    return conLai.isNegative ? Duration.zero : conLai;
  }

  void _batDau() {
    if (_tongThoiGianDat == Duration.zero) return;
    HapticFeedback.mediumImpact();
    final ketThuc = DateTime.now().add(_tongThoiGianDat);
    setState(() {
      _thoiDiemKetThuc = ketThuc;
      _dangChay = true;
      _daBaoXong = false;
    });
    // Đặt THÔNG BÁO CỤC BỘ THẬT SỰ tại đúng thời điểm kết thúc - đây mới là
    // phần đảm bảo "báo được dù tắt màn hình/thoát app", vì hệ điều hành tự
    // kích hoạt thông báo đúng giờ hẹn dù app đang bị đóng băng/tắt hẳn,
    // KHÁC HẲN với việc chỉ dựa vào Timer.periodic (chắc chắn dừng khi app
    // bị hệ điều hành thu hồi tài nguyên chạy nền).
    ReminderNotificationService.datLich(
      messageId: _idThongBaoHenGio,
      tieuDe: 'Hẹn giờ đã kết thúc!',
      moTa: 'Đã hết ${_dinhDangThoiGian(_tongThoiGianDat, coMili: false)}.',
      thoiGianNhac: ketThuc,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (_thoiGianConLai == Duration.zero && !_daBaoXong) {
        _daBaoXong = true;
        HapticFeedback.heavyImpact();
        _timer?.cancel();
        setState(() => _dangChay = false);
      } else {
        setState(() {});
      }
    });
  }

  void _dungVaDatLai() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    ReminderNotificationService.huyLich(_idThongBaoHenGio); // hủy thông báo đã đặt trước đó (nếu dừng sớm)
    setState(() {
      _dangChay = false;
      _thoiDiemKetThuc = null;
      _daBaoXong = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _dangChay || _daBaoXong
          ? _giaoDienDemNguoc()
          : _giaoDienChonThoiGian(),
    );
  }

  Widget _giaoDienChonThoiGian() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('Chọn thời gian đếm ngược', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                _oChonSo('Giờ', _gioChon, 23, (v) => setState(() => _gioChon = v)),
                _oChonSo('Phút', _phutChon, 59, (v) => setState(() => _phutChon = v)),
                _oChonSo('Giây', _giayChon, 59, (v) => setState(() => _giayChon = v)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Nút hẹn giờ nhanh - rất hay dùng (5p/10p/15p/30p) để không phải kéo picker mỗi lần
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [1, 3, 5, 10, 15, 30].map((phut) {
              return ActionChip(
                label: Text('$phut phút'),
                onPressed: () => setState(() {
                  _gioChon = 0;
                  _phutChon = phut;
                  _giayChon = 0;
                }),
              );
            }).toList(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _tongThoiGianDat == Duration.zero ? null : _batDau,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.viettelRed, padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu đếm ngược'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _oChonSo(String nhan, int giaTri, int max, ValueChanged<int> onChanged) {
    // SỬA LỖI HIỂN THỊ: bản trước dùng perspective/diameterRatio quá mạnh
    // (0.005 / 1.3) khiến các số ở xa tâm bị BÓP MÉO PHỐI CẢNH 3D trông như
    // ký tự lạ (không phải lỗi font, mà do hiệu ứng nghiêng/cong quá mức).
    // Giảm phối cảnh xuống mức nhẹ hơn nhiều + tự tô màu rõ ràng: số ĐANG
    // CHỌN tô đậm màu đỏ Viettel, số khác màu xám nhạt dần theo khoảng
    // cách - để mắt nhìn RÕ số nào đang được chọn, không còn mù mờ.
    final controller = FixedExtentScrollController(initialItem: giaTri);
    return Expanded(
      child: Column(
        children: [
          Text(nhan, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dải nền nổi bật đúng vị trí số đang chọn (chuẩn UX của mọi bộ chọn giờ/phút)
                  Container(
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.viettelRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  double viTriHienTai = giaTri.toDouble();
                  if (controller.hasClients && controller.position.hasContentDimensions) {
                    viTriHienTai = controller.selectedItem.toDouble();
                    // Nội suy mượt theo offset thực tế khi đang kéo (không chỉ nhảy theo item)
                    final offset = controller.offset / 42.0;
                    viTriHienTai = offset;
                  }
                  return ListWheelScrollView.useDelegate(
                    itemExtent: 42,
                    perspective: 0.0015,
                    diameterRatio: 2.2,
                    physics: const FixedExtentScrollPhysics(),
                    controller: controller,
                    onSelectedItemChanged: onChanged,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: max + 1,
                      builder: (context, i) {
                        final khoangCach = (i - viTriHienTai).abs();
                        final dangChon = khoangCach < 0.5;
                        final doMo = (1 - (khoangCach * 0.45)).clamp(0.25, 1.0);
                        return Center(
                          child: Text(
                            i.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: dangChon ? 24 : 20,
                              fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                              color: dangChon ? AppTheme.viettelRed : Colors.grey.shade500.withOpacity(doMo),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _giaoDienDemNguoc() {
    final tongGiay = _tongThoiGianDat.inMilliseconds;
    final conLaiGiay = _thoiGianConLai.inMilliseconds;
    final tienDo = tongGiay == 0 ? 0.0 : 1 - (conLaiGiay / tongGiay);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: tienDo.clamp(0, 1),
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    color: _daBaoXong ? Colors.green : AppTheme.viettelRed,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dinhDangThoiGian(_thoiGianConLai, coMili: false),
                      style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    if (_daBaoXong) const Text('⏰ Đã hết giờ!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _dungVaDatLai,
            icon: const Icon(Icons.refresh),
            label: Text(_daBaoXong ? 'Đặt hẹn giờ mới' : 'Dừng và đặt lại'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 3: LUYỆN TẬP NGẮT QUÃNG (Interval / HIIT)
// =============================================================================

enum _PhaTapLuyen { chuanBi, lamViec, nghi, xongHet }

class _TabNgatQuang extends StatefulWidget {
  const _TabNgatQuang();
  @override
  State<_TabNgatQuang> createState() => _TabNgatQuangState();
}

class _TabNgatQuangState extends State<_TabNgatQuang> {
  int _soHiepDat = 5;
  int _giayLamViecDat = 30;
  int _giayNghiDat = 15;

  bool _dangChay = false;
  _PhaTapLuyen _phaHienTai = _PhaTapLuyen.chuanBi;
  int _hiepHienTai = 1;
  DateTime? _thoiDiemKetThucPha;
  Timer? _timer;

  Duration get _conLaiTrongPha {
    if (_thoiDiemKetThucPha == null) return Duration.zero;
    final d = _thoiDiemKetThucPha!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void _batDau() {
    HapticFeedback.mediumImpact();
    setState(() {
      _dangChay = true;
      _hiepHienTai = 1;
      _phaHienTai = _PhaTapLuyen.lamViec;
      _thoiDiemKetThucPha = DateTime.now().add(Duration(seconds: _giayLamViecDat));
    });
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _kiemTraChuyenPha());
  }

  /// Chuyển pha tự động khi hết giờ pha hiện tại - LÀM VIỆC -> NGHỈ -> (hiệp
  /// tiếp theo) LÀM VIỆC -> ... cho tới khi hết đủ số hiệp đã đặt.
  void _kiemTraChuyenPha() {
    if (!mounted || _thoiDiemKetThucPha == null) return;
    if (DateTime.now().isBefore(_thoiDiemKetThucPha!)) {
      setState(() {}); // chỉ để cập nhật đồng hồ đếm ngược hiển thị
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      if (_phaHienTai == _PhaTapLuyen.lamViec) {
        if (_hiepHienTai >= _soHiepDat) {
          _ketThucBaiTap();
          return;
        }
        _phaHienTai = _PhaTapLuyen.nghi;
        _thoiDiemKetThucPha = DateTime.now().add(Duration(seconds: _giayNghiDat));
      } else {
        _hiepHienTai++;
        _phaHienTai = _PhaTapLuyen.lamViec;
        _thoiDiemKetThucPha = DateTime.now().add(Duration(seconds: _giayLamViecDat));
      }
    });
  }

  void _ketThucBaiTap() {
    _timer?.cancel();
    setState(() {
      _phaHienTai = _PhaTapLuyen.xongHet;
      _dangChay = false;
    });
  }

  void _dungVaDatLai() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _dangChay = false;
      _phaHienTai = _PhaTapLuyen.chuanBi;
      _hiepHienTai = 1;
      _thoiDiemKetThucPha = null;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phaHienTai == _PhaTapLuyen.chuanBi) return SafeArea(child: _giaoDienCaiDat());
    return SafeArea(child: _giaoDienDangTap());
  }

  Widget _giaoDienCaiDat() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text('Cài đặt bài luyện tập ngắt quãng (HIIT)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 24),
          _oCauHinhSo('Số hiệp', _soHiepDat, 1, 50, (v) => setState(() => _soHiepDat = v)),
          const SizedBox(height: 16),
          _oCauHinhSo('Thời gian làm việc (giây)', _giayLamViecDat, 5, 600, (v) => setState(() => _giayLamViecDat = v), buoc: 5),
          const SizedBox(height: 16),
          _oCauHinhSo('Thời gian nghỉ (giây)', _giayNghiDat, 5, 300, (v) => setState(() => _giayNghiDat = v), buoc: 5),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.viettelRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Tổng thời gian: ${_dinhDangThoiGian(Duration(seconds: _soHiepDat * (_giayLamViecDat + _giayNghiDat) - _giayNghiDat), coMili: false)}',
              style: TextStyle(color: AppTheme.viettelRed, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _batDau,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.viettelRed, padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu luyện tập'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _oCauHinhSo(String nhan, int giaTri, int min, int max, ValueChanged<int> onChanged, {int buoc = 1}) {
    return Row(
      children: [
        Expanded(child: Text(nhan)),
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: giaTri > min ? () => onChanged((giaTri - buoc).clamp(min, max)) : null),
        SizedBox(width: 44, child: Text('$giaTri', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: giaTri < max ? () => onChanged((giaTri + buoc).clamp(min, max)) : null),
      ],
    );
  }

  Widget _giaoDienDangTap() {
    if (_phaHienTai == _PhaTapLuyen.xongHet) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Hoàn thành bài tập!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('$_soHiepDat hiệp đã xong', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _dungVaDatLai, style: FilledButton.styleFrom(backgroundColor: AppTheme.viettelRed), child: const Text('Tập bài mới')),
          ],
        ),
      );
    }

    final laLamViec = _phaHienTai == _PhaTapLuyen.lamViec;
    final mauNen = laLamViec ? AppTheme.viettelRed : Colors.blue.shade700;
    return Container(
      color: mauNen,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(laLamViec ? 'LÀM VIỆC' : 'NGHỈ', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('Hiệp $_hiepHienTai/$_soHiepDat', style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 20),
            Text(
              _dinhDangThoiGian(_conLaiTrongPha, coMili: false),
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _dungVaDatLai,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
              icon: const Icon(Icons.stop),
              label: const Text('Dừng bài tập'),
            ),
          ],
        ),
      ),
    );
  }
}
