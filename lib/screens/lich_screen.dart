import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/am_lich.dart';
import '../utils/ngay_le.dart';

/// Lịch Âm - Dương Việt Nam. Xem theo tháng, mỗi ô hiện ngày dương lớn + ngày
/// âm nhỏ bên dưới, có chấm đánh dấu ngày lễ/Tết. Bấm vào 1 ngày xem chi
/// tiết đầy đủ (âm lịch đầy đủ + tên ngày lễ nếu có).
class LichScreen extends StatefulWidget {
  const LichScreen({super.key});

  @override
  State<LichScreen> createState() => _LichScreenState();
}

class _LichScreenState extends State<LichScreen> {
  late DateTime _thangDangXem;
  final DateTime _homNay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _thangDangXem = DateTime(_homNay.year, _homNay.month, 1);
  }

  void _doiThang(int soThang) {
    setState(() => _thangDangXem = DateTime(_thangDangXem.year, _thangDangXem.month + soThang, 1));
  }

  void _veHomNay() {
    setState(() => _thangDangXem = DateTime(_homNay.year, _homNay.month, 1));
  }

  bool get _dangXemThangHienTai => _thangDangXem.year == _homNay.year && _thangDangXem.month == _homNay.month;

  @override
  Widget build(BuildContext context) {
    final soNgayTrongThang = DateTime(_thangDangXem.year, _thangDangXem.month + 1, 0).day;
    // Thứ của ngày mùng 1 (Dart: Thứ 2 = 1 ... Chủ nhật = 7) -> quy về Chủ
    // nhật đứng đầu tuần cho quen mắt người Việt (Chủ nhật=0, Thứ 2=1...)
    final thuNgayMot = _thangDangXem.weekday % 7;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Lịch Âm - Dương'),
        actions: [
          if (!_dangXemThangHienTai)
            TextButton.icon(
              onPressed: _veHomNay,
              icon: const Icon(Icons.today, size: 18, color: Colors.white),
              label: const Text('Hôm nay', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _thanhChonThang(),
            _theNamAmLich(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _hangThuTrongTuan(),
                    const Divider(height: 1, indent: 12, endIndent: 12),
                    Expanded(child: _luoiNgay(soNgayTrongThang, thuNgayMot)),
                  ],
                ),
              ),
            ),
            _chuThichHomNay(),
          ],
        ),
      ),
    );
  }

  Widget _thanhChonThang() {
    const tenThang = [
      '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.viettelRed, Color(0xFFB8002A)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.viettelRed.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => _doiThang(-1)),
          Text(
            '${tenThang[_thangDangXem.month]} - ${_thangDangXem.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: .3),
          ),
          IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => _doiThang(1)),
        ],
      ),
    );
  }

  /// Dải nhỏ hiện tên năm Can Chi của tháng đang xem - giúp biết ngay đang ở
  /// năm âm nào mà không cần bấm vào từng ngày.
  Widget _theNamAmLich() {
    final amLichDauThang = AmLich.duongSangAm(1, _thangDangXem.month, _thangDangXem.year);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Năm ${AmLich.namCanChi(amLichDauThang[2])}',
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _hangThuTrongTuan() {
    const thu = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: thu
            .map((t) => Expanded(
                  child: Center(
                    child: Text(
                      t,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: t == 'CN' ? AppTheme.viettelRed : Colors.grey.shade600),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _luoiNgay(int soNgayTrongThang, int thuNgayMot) {
    final tongOTrong = thuNgayMot;
    final tongO = tongOTrong + soNgayTrongThang;
    final soHang = (tongO / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1 / (soHang > 5 ? 1.05 : 1.25)),
      itemCount: soHang * 7,
      itemBuilder: (context, index) {
        final ngayThu = index - tongOTrong + 1;
        if (ngayThu < 1 || ngayThu > soNgayTrongThang) return const SizedBox.shrink();

        final ngay = DateTime(_thangDangXem.year, _thangDangXem.month, ngayThu);
        final laHomNay = ngay.year == _homNay.year && ngay.month == _homNay.month && ngay.day == _homNay.day;
        final laChuNhat = index % 7 == 0;
        final laThuBay = index % 7 == 6;
        final amLich = AmLich.duongSangAm(ngay.day, ngay.month, ngay.year);
        final ngayAm = amLich[0];
        final thangAm = amLich[1];

        final leDuong = NgayLe.timTheoDuong(ngay.day, ngay.month);
        final leAm = NgayLe.timTheoAm(ngayAm, thangAm);
        final coLe = leDuong.isNotEmpty || leAm.isNotEmpty;

        // Màu chữ ngày dương: Hôm nay -> trắng (nền đỏ nổi bật); ngày lễ ->
        // cam đậm (khác hẳn đỏ Chủ nhật, tránh nhầm với "ngày nghỉ thường");
        // Chủ nhật -> đỏ thương hiệu; các ngày khác -> đen nhạt.
        Color mauChuDuong;
        if (laHomNay) {
          mauChuDuong = Colors.white;
        } else if (coLe) {
          mauChuDuong = const Color(0xFFE07A00);
        } else if (laChuNhat) {
          mauChuDuong = AppTheme.viettelRed;
        } else {
          mauChuDuong = const Color(0xFF1F2937);
        }

        return GestureDetector(
          onTap: () => _hienChiTiet(ngay, amLich, [...leDuong, ...leAm]),
          child: Container(
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              gradient: laHomNay
                  ? const LinearGradient(colors: [AppTheme.viettelRed, Color(0xFFC2002E)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              color: laHomNay
                  ? null
                  : coLe
                      ? const Color(0xFFFFF4E5)
                      : (laChuNhat || laThuBay)
                          ? const Color(0xFFFAFAFC)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: laHomNay ? [BoxShadow(color: AppTheme.viettelRed.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$ngayThu',
                  style: TextStyle(fontSize: 16, fontWeight: laHomNay ? FontWeight.bold : FontWeight.w600, color: mauChuDuong),
                ),
                const SizedBox(height: 1),
                Text(
                  ngayAm == 1 ? '$ngayAm/$thangAm' : '$ngayAm',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: laHomNay ? Colors.white70 : (ngayAm == 1 ? AppTheme.viettelRed : Colors.grey.shade500),
                    fontWeight: ngayAm == 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (coLe)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(color: laHomNay ? Colors.white : const Color(0xFFE07A00), shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chuThichHomNay() {
    final amLich = AmLich.duongSangAm(_homNay.day, _homNay.month, _homNay.year);
    const thuTrongTuan = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.viettelRed.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: AppTheme.viettelRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.wb_sunny_outlined, color: AppTheme.viettelRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${thuTrongTuan[_homNay.weekday % 7]}, ${_homNay.day}/${_homNay.month}/${_homNay.year}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                ),
                Text(
                  'Âm lịch ${amLich[0]}/${amLich[1]} - Năm ${AmLich.namCanChi(amLich[2])}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _hienChiTiet(DateTime ngay, List<int> amLich, List<NgayLe> danhSachLe) {
    const thuTrongTuan = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    final laHomNay = ngay.year == _homNay.year && ngay.month == _homNay.month && ngay.day == _homNay.day;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        // BẮT BUỘC bọc SafeArea ở đây - nếu không, nội dung bottom sheet bị
        // THANH ĐIỀU HƯỚNG CỦA ĐIỆN THOẠI (3 nút Back/Home/Recent) đè lên
        // phần cuối, khiến chữ bị khuất khó đọc (lỗi thật đã gặp).
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dải đầu màu đỏ thương hiệu - hiển thị ngày dương lớn, nổi bật
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.viettelRed, Color(0xFFB8002A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${ngay.day}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
                        Text(
                          '${thuTrongTuan[ngay.weekday % 7]}, Tháng ${ngay.month}/${ngay.year}',
                          style: const TextStyle(fontSize: 13.5, color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (laHomNay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Hôm nay', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.brightness_2_outlined, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Âm lịch: ${amLich[0]}/${amLich[1]}${amLich[3] == 1 ? " (nhuận)" : ""}/${amLich[2]}',
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text('Năm ${AmLich.namCanChi(amLich[2])}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ),
                    if (danhSachLe.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      ...danhSachLe.map((le) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.celebration, color: Color(0xFFE07A00), size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text(le.ten, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
