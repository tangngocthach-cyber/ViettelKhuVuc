import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/am_lich.dart';
import '../utils/ngay_le.dart';

/// Lịch Âm - Dương Việt Nam. Xem theo tháng, mỗi ô hiện ngày dương lớn + ngày
/// âm nhỏ bên dưới, có chấm đỏ đánh dấu ngày lễ/Tết. Bấm vào 1 ngày xem chi
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

  @override
  Widget build(BuildContext context) {
    final soNgayTrongThang = DateTime(_thangDangXem.year, _thangDangXem.month + 1, 0).day;
    // Thứ của ngày mùng 1 (Dart: Thứ 2 = 1 ... Chủ nhật = 7) -> quy về Chủ
    // nhật đứng đầu tuần cho quen mắt người Việt (Chủ nhật=0, Thứ 2=1...)
    final thuNgayMot = _thangDangXem.weekday % 7;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Âm - Dương'),
        actions: [IconButton(icon: const Icon(Icons.today), tooltip: 'Về hôm nay', onPressed: _veHomNay)],
      ),
      body: Column(
        children: [
          _thanhChonThang(),
          _hangThuTrongTuan(),
          const Divider(height: 1),
          Expanded(child: _luoiNgay(soNgayTrongThang, thuNgayMot)),
          _chuThichHomNay(),
        ],
      ),
    );
  }

  Widget _thanhChonThang() {
    const tenThang = [
      '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _doiThang(-1)),
          SizedBox(
            width: 170,
            child: Text(
              '${tenThang[_thangDangXem.month]} - ${_thangDangXem.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _doiThang(1)),
        ],
      ),
    );
  }

  Widget _hangThuTrongTuan() {
    const thu = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return Row(
      children: thu
          .map((t) => Expanded(
                child: Center(
                  child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: t == 'CN' ? AppTheme.viettelRed : Colors.grey.shade700)),
                ),
              ))
          .toList(),
    );
  }

  Widget _luoiNgay(int soNgayTrongThang, int thuNgayMot) {
    final tongOTrong = thuNgayMot;
    final tongO = tongOTrong + soNgayTrongThang;
    final soHang = (tongO / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1 / (soHang > 5 ? 1.05 : 1.25)),
      itemCount: soHang * 7,
      itemBuilder: (context, index) {
        final ngayThu = index - tongOTrong + 1;
        if (ngayThu < 1 || ngayThu > soNgayTrongThang) return const SizedBox.shrink();

        final ngay = DateTime(_thangDangXem.year, _thangDangXem.month, ngayThu);
        final laHomNay = ngay.year == _homNay.year && ngay.month == _homNay.month && ngay.day == _homNay.day;
        final laChuNhat = index % 7 == 0;
        final amLich = AmLich.duongSangAm(ngay.day, ngay.month, ngay.year);
        final ngayAm = amLich[0];
        final thangAm = amLich[1];

        final leDuong = NgayLe.timTheoDuong(ngay.day, ngay.month);
        final leAm = NgayLe.timTheoAm(ngayAm, thangAm);
        final coLe = leDuong.isNotEmpty || leAm.isNotEmpty;

        return GestureDetector(
          onTap: () => _hienChiTiet(ngay, amLich, [...leDuong, ...leAm]),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: laHomNay ? AppTheme.viettelRed : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$ngayThu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: laHomNay ? FontWeight.bold : FontWeight.w500,
                    color: laHomNay ? Colors.white : (laChuNhat ? AppTheme.viettelRed : Colors.black87),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  ngayAm == 1 ? '$ngayAm/$thangAm' : '$ngayAm',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: laHomNay ? Colors.white70 : (ngayAm == 1 ? AppTheme.viettelRed : Colors.grey.shade600),
                    fontWeight: ngayAm == 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (coLe)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: laHomNay ? Colors.white : Colors.orange, shape: BoxShape.circle),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: Border(top: BorderSide(color: Colors.grey.shade300))),
      child: Text(
        'Hôm nay: ${_homNay.day}/${_homNay.month}/${_homNay.year} (Dương lịch)  •  '
        '${amLich[0]}/${amLich[1]}/${amLich[2]} Âm lịch (${AmLich.namCanChi(amLich[2])})',
        style: const TextStyle(fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _hienChiTiet(DateTime ngay, List<int> amLich, List<NgayLe> danhSachLe) {
    const thuTrongTuan = ['Chủ nhật', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${thuTrongTuan[ngay.weekday % 7]}, ${ngay.day}/${ngay.month}/${ngay.year}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Âm lịch: ${amLich[0]}/${amLich[1]}${amLich[3] == 1 ? " (nhuận)" : ""}/${amLich[2]} - Năm ${AmLich.namCanChi(amLich[2])}',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            if (danhSachLe.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...danhSachLe.map((le) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration, color: AppTheme.viettelRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(le.ten, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
