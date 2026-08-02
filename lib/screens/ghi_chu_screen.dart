import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ghi_chu.dart';
import '../services/ghi_chu_service.dart';
import '../theme.dart';

class GhiChuScreen extends StatefulWidget {
  const GhiChuScreen({super.key});

  @override
  State<GhiChuScreen> createState() => _GhiChuScreenState();
}

enum _BoLoc { tatCa, sapToi, quaHan, daXong }

class _GhiChuScreenState extends State<GhiChuScreen> {
  List<GhiChu> _tatCaGhiChu = [];
  _BoLoc _boLoc = _BoLoc.tatCa;
  bool _dangTai = true;
  bool _dangChonNhieu = false;
  final Set<int> _idDaChon = {};
  final _oTimKiemCtrl = TextEditingController();
  String _tuKhoa = '';
  DateTime? _lanSaoLuuCuoi;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
    _taiThoiGianSaoLuu();
    _oTimKiemCtrl.addListener(() => setState(() => _tuKhoa = _oTimKiemCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _oTimKiemCtrl.dispose();
    super.dispose();
  }

  Future<void> _taiDuLieu() async {
    final ds = await GhiChuService.layDanhSach();
    if (!mounted) return;
    setState(() {
      _tatCaGhiChu = ds;
      _dangTai = false;
    });
  }

  Future<void> _taiThoiGianSaoLuu() async {
    final t = await GhiChuService.layLanSaoLuuCuoi();
    if (mounted) setState(() => _lanSaoLuuCuoi = t);
  }

  /// Danh sách sau khi lọc theo tab (Tất cả/Sắp tới/Quá hạn/Đã xong) VÀ theo
  /// từ khóa tìm kiếm (khớp tiêu đề hoặc nội dung, không phân biệt hoa/thường).
  List<GhiChu> get _dsHienThi {
    final gio = DateTime.now();
    Iterable<GhiChu> ds = _tatCaGhiChu;
    switch (_boLoc) {
      case _BoLoc.tatCa:
        ds = ds.where((g) => !g.daXong);
        break;
      case _BoLoc.sapToi:
        ds = ds.where((g) => !g.daXong && g.thoiGianNhac != null && g.thoiGianNhac!.isAfter(gio));
        break;
      case _BoLoc.quaHan:
        ds = ds.where((g) => !g.daXong && g.thoiGianNhac != null && g.thoiGianNhac!.isBefore(gio));
        break;
      case _BoLoc.daXong:
        ds = ds.where((g) => g.daXong);
        break;
    }
    if (_tuKhoa.isNotEmpty) {
      ds = ds.where((g) => g.tieuDe.toLowerCase().contains(_tuKhoa) || g.noiDung.toLowerCase().contains(_tuKhoa));
    }
    return ds.toList();
  }

  int _demTheoBoLoc(_BoLoc loc) {
    final gio = DateTime.now();
    switch (loc) {
      case _BoLoc.tatCa:
        return _tatCaGhiChu.where((g) => !g.daXong).length;
      case _BoLoc.sapToi:
        return _tatCaGhiChu.where((g) => !g.daXong && g.thoiGianNhac != null && g.thoiGianNhac!.isAfter(gio)).length;
      case _BoLoc.quaHan:
        return _tatCaGhiChu.where((g) => !g.daXong && g.thoiGianNhac != null && g.thoiGianNhac!.isBefore(gio)).length;
      case _BoLoc.daXong:
        return _tatCaGhiChu.where((g) => g.daXong).length;
    }
  }

  /// Nhóm danh sách theo thời điểm nhắc hẹn - cách trình bày hiện đại kiểu
  /// Todoist/TickTick, dễ quét mắt hơn nhiều so với danh sách phẳng dài.
  Map<String, List<GhiChu>> _nhomTheoNgay(List<GhiChu> ds) {
    final now = DateTime.now();
    final homNay = DateTime(now.year, now.month, now.day);
    final ngayMai = homNay.add(const Duration(days: 1));
    final cuoiTuanNay = homNay.add(Duration(days: 7 - now.weekday));

    final nhom = <String, List<GhiChu>>{};
    for (final gc in ds) {
      String key;
      if (gc.thoiGianNhac == null) {
        key = 'Không có hẹn giờ';
      } else {
        final d = gc.thoiGianNhac!;
        final ngayD = DateTime(d.year, d.month, d.day);
        if (!gc.daXong && d.isBefore(now)) {
          key = '⚠️ Quá hạn';
        } else if (ngayD == homNay) {
          key = 'Hôm nay';
        } else if (ngayD == ngayMai) {
          key = 'Ngày mai';
        } else if (!ngayD.isAfter(cuoiTuanNay)) {
          key = 'Tuần này';
        } else {
          key = 'Sắp tới';
        }
      }
      nhom.putIfAbsent(key, () => []).add(gc);
    }
    return nhom;
  }

  static const _thuTuNhom = ['⚠️ Quá hạn', 'Hôm nay', 'Ngày mai', 'Tuần này', 'Sắp tới', 'Không có hẹn giờ'];

  Future<void> _moThemSua({GhiChu? ghiChuSua}) async {
    final ketQua = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormGhiChu(ghiChuSua: ghiChuSua),
    );
    if (ketQua == true) {
      await _taiDuLieu();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(ghiChuSua == null ? 'Đã lưu ghi chú mới.' : 'Đã cập nhật ghi chú.'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Hỏi xác nhận trước khi xóa - dùng chung cho cả xóa 1 ghi chú và xóa
  /// nhiều ghi chú cùng lúc. Xóa dữ liệu là hành động KHÔNG THỂ HOÀN TÁC nên
  /// bắt buộc phải hỏi lại trước khi thực hiện.
  Future<bool> _xacNhanXoa(int soLuong) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(soLuong == 1 ? 'Xóa ghi chú này? Không thể hoàn tác.' : 'Xóa $soLuong ghi chú đã chọn? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return dongY == true;
  }

  Future<void> _xoa(GhiChu gc) async {
    await GhiChuService.xoa(gc.id);
    _taiDuLieu();
  }

  void _toggleChon(int id) {
    setState(() {
      if (_idDaChon.contains(id)) {
        _idDaChon.remove(id);
        if (_idDaChon.isEmpty) _dangChonNhieu = false;
      } else {
        _idDaChon.add(id);
      }
    });
  }

  void _thoatChonNhieu() {
    setState(() {
      _dangChonNhieu = false;
      _idDaChon.clear();
    });
  }

  Future<void> _xoaHangLoat() async {
    if (_idDaChon.isEmpty) return;
    final xacNhan = await _xacNhanXoa(_idDaChon.length);
    if (!xacNhan) return;
    for (final id in _idDaChon.toList()) {
      await GhiChuService.xoa(id);
    }
    _thoatChonNhieu();
    _taiDuLieu();
  }

  Future<void> _danhDauXongHangLoat() async {
    if (_idDaChon.isEmpty) return;
    for (final id in _idDaChon.toList()) {
      await GhiChuService.danhDauXong(id, true);
    }
    _thoatChonNhieu();
    _taiDuLieu();
  }

  Future<void> _danhDauXong(GhiChu gc, bool xong) async {
    // Ghi chú có bật LẶP LẠI (VD đóng cước trước 6 tháng/năm) - khi tick vào
    // ô "xong", KHÔNG được tắt hẳn ngay - phải hỏi rõ ý người dùng: đây là
    // "thu xong kỳ này, tự hẹn lại kỳ sau" hay "dừng hẳn, không lặp nữa".
    // BẮT BUỘC kiểm tra thêm thoiGianNhac != null - dữ liệu khôi phục từ file
    // sao lưu cũ/hỏng lý thuyết có thể có coLapLai=true nhưng thiếu mốc ngày,
    // lúc đó phải coi như KHÔNG lặp lại để tránh crash ứng dụng.
    if (xong && gc.coLapLai && gc.thoiGianNhac != null) {
      final lua = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ghi chú lặp lại theo chu kỳ'),
          content: Text(
            'Đây là công việc lặp lại mỗi ${ChuKyLapLai.tatCa.firstWhere((c) => c.soThang == gc.chuKyLapLaiThang, orElse: () => ChuKyLapLai.tatCa[0]).ten.toLowerCase()}. '
            'Chọn đúng ý bạn:',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'huy'), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, 'dung_han'), child: const Text('Dừng lặp lại')),
            ElevatedButton(onPressed: () => Navigator.pop(context, 'gia_han'), child: const Text('Đã thu - Hẹn kỳ sau')),
          ],
        ),
      );
      if (lua == 'gia_han') {
        final ngayKyToi = GhiChu.congThang(gc.thoiGianNhac!, gc.chuKyLapLaiThang!);
        await GhiChuService.giaHanTheoChuKy(gc.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã tự hẹn lại kỳ sau: ${DateFormat('dd/MM/yyyy').format(ngayKyToi)}')),
          );
        }
        _taiDuLieu();
        return;
      } else if (lua == 'dung_han') {
        await GhiChuService.danhDauXong(gc.id, true);
        _taiDuLieu();
      }
      return; // bấm Hủy hoặc đóng hộp thoại -> không làm gì cả
    }
    await GhiChuService.danhDauXong(gc.id, xong);
    _taiDuLieu();
  }

  /// GIA HẠN NHANH - dời lịch hẹn khi khách hẹn lại/chưa thu được, không cần
  /// vào sửa ghi chú đầy đủ. Có sẵn các mốc quen thuộc + tùy chọn ngày giờ khác.
  Future<void> _moGiaHan(GhiChu gc) async {
    final gioGoc = gc.thoiGianNhac ?? DateTime.now();
    final lua = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gia hạn - dời lịch hẹn', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Hẹn hiện tại: ${DateFormat('HH:mm - dd/MM/yyyy').format(gioGoc)}', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(label: const Text('+1 ngày'), onPressed: () => Navigator.pop(ctx, gioGoc.add(const Duration(days: 1)))),
                  ActionChip(label: const Text('+3 ngày'), onPressed: () => Navigator.pop(ctx, gioGoc.add(const Duration(days: 3)))),
                  ActionChip(label: const Text('+1 tuần'), onPressed: () => Navigator.pop(ctx, gioGoc.add(const Duration(days: 7)))),
                  ActionChip(label: const Text('+1 tháng'), onPressed: () => Navigator.pop(ctx, GhiChu.congThang(gioGoc, 1))),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    final ngay = await showDatePicker(
                      context: ctx,
                      initialDate: gioGoc.isAfter(DateTime.now()) ? gioGoc : DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (ngay == null || !ctx.mounted) return;
                    final gio = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(gioGoc));
                    if (gio == null || !ctx.mounted) return;
                    Navigator.pop(ctx, DateTime(ngay.year, ngay.month, ngay.day, gio.hour, gio.minute));
                  },
                  child: const Text('Chọn ngày giờ khác...'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (lua == null) return;
    await GhiChuService.giaHan(gc.id, lua);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã gia hạn tới ${DateFormat('HH:mm - dd/MM/yyyy').format(lua)}')));
    }
    _taiDuLieu();
  }

  Future<void> _goiDien(String soDienThoai) async {
    final uri = Uri(scheme: 'tel', path: soDienThoai);
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở ứng dụng gọi điện.')));
    }
  }

  Future<void> _sauLuu() async {
    try {
      final file = await GhiChuService.xuatBackup();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'File sao lưu Sổ ghi chú - Viettel Khu Vực Vĩnh Hưng');
      await _taiThoiGianSaoLuu();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sao lưu thất bại: $e')));
    }
  }

  Future<void> _khoiPhuc() async {
    try {
      final ketQua = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (ketQua == null || ketQua.files.single.path == null) return;

      final xacNhan = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Khôi phục dữ liệu'),
          content: const Text(
            'Khôi phục sẽ THÊM MỚI/CẬP NHẬT ghi chú từ file sao lưu vào Sổ ghi '
            'chú hiện tại - KHÔNG xóa các ghi chú đang có sẵn. Tiếp tục?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Khôi phục')),
          ],
        ),
      );
      if (xacNhan != true) return;

      final soLuong = await GhiChuService.khoiPhucTuFile(File(ketQua.files.single.path!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã khôi phục $soLuong ghi chú.')));
      _taiDuLieu();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khôi phục thất bại: file không đúng định dạng sao lưu.')));
    }
  }

  Future<void> _xuatExcel() async {
    try {
      final file = await GhiChuService.xuatXlsx();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Danh sách ghi chú - mở trực tiếp bằng Excel');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xuất file thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = _dsHienThi;
    final nhom = _nhomTheoNgay(ds);

    return Scaffold(
      appBar: _dangChonNhieu
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: _thoatChonNhieu),
              title: Text('Đã chọn ${_idDaChon.length}'),
              actions: [
                IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Đánh dấu xong', onPressed: _danhDauXongHangLoat),
                IconButton(icon: const Icon(Icons.delete), tooltip: 'Xóa đã chọn', onPressed: _xoaHangLoat),
              ],
            )
          : AppBar(
              title: const Text('Sổ ghi chú'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Chọn nhiều để xóa/đánh dấu xong hàng loạt',
                  onPressed: () => setState(() => _dangChonNhieu = true),
                ),
                PopupMenuButton<String>(
                  onSelected: (gt) {
                    if (gt == 'sao_luu') _sauLuu();
                    if (gt == 'khoi_phuc') _khoiPhuc();
                    if (gt == 'xuat_excel') _xuatExcel();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'sao_luu', child: ListTile(leading: Icon(Icons.backup), title: Text('Sao lưu'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'khoi_phuc', child: ListTile(leading: Icon(Icons.restore), title: Text('Khôi phục'), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'xuat_excel', child: ListTile(leading: Icon(Icons.table_chart), title: Text('Xuất Excel'), contentPadding: EdgeInsets.zero)),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          if (!_dangChonNhieu) _canhBaoSaoLuu(),
          _oTimKiem(),
          _thanhLoc(),
          Expanded(
            child: _dangTai
                ? const Center(child: CircularProgressIndicator())
                : ds.isEmpty
                    ? _trangThaiRong()
                    : RefreshIndicator(
                        onRefresh: _taiDuLieu,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          children: [
                            for (final key in _thuTuNhom)
                              if (nhom[key] != null && nhom[key]!.isNotEmpty) ...[
                                _tieuDeNhomNgay(key, nhom[key]!.length),
                                ...nhom[key]!.map(_theGhiChu),
                              ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _dangChonNhieu
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.viettelRed,
              onPressed: () => _moThemSua(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  /// Nhắc sao lưu định kỳ - dữ liệu CHỈ nằm trên máy, mất máy/gỡ app là mất
  /// trắng. Hiện nếu CHƯA TỪNG sao lưu, hoặc đã quá 14 ngày chưa sao lưu lại.
  Widget _canhBaoSaoLuu() {
    final quaHan = _lanSaoLuuCuoi == null || DateTime.now().difference(_lanSaoLuuCuoi!).inDays >= 14;
    if (!quaHan || _tatCaGhiChu.isEmpty) return const SizedBox.shrink();
    final chu = _lanSaoLuuCuoi == null
        ? 'Anh/chị chưa sao lưu Sổ ghi chú lần nào. Nên sao lưu để tránh mất dữ liệu.'
        : 'Đã ${DateTime.now().difference(_lanSaoLuuCuoi!).inDays} ngày chưa sao lưu Sổ ghi chú.';
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(chu, style: const TextStyle(fontSize: 12.5))),
          TextButton(onPressed: _sauLuu, child: const Text('Sao lưu ngay')),
        ],
      ),
    );
  }

  Widget _oTimKiem() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _oTimKiemCtrl,
        decoration: InputDecoration(
          hintText: 'Tìm ghi chú theo tiêu đề, nội dung...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _tuKhoa.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _oTimKiemCtrl.clear())
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _thanhLoc() {
    final muc = [
      (_BoLoc.tatCa, 'Tất cả'),
      (_BoLoc.sapToi, 'Sắp tới'),
      (_BoLoc.quaHan, 'Quá hạn'),
      (_BoLoc.daXong, 'Đã xong'),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: muc
            .map((m) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${m.$2} (${_demTheoBoLoc(m.$1)})'),
                    selected: _boLoc == m.$1,
                    onSelected: (_) => setState(() => _boLoc = m.$1),
                    selectedColor: AppTheme.viettelRed,
                    labelStyle: TextStyle(color: _boLoc == m.$1 ? Colors.white : Colors.black87),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _trangThaiRong() {
    if (_tuKhoa.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('Không tìm thấy ghi chú nào khớp với "$_tuKhoa".', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    final chu = switch (_boLoc) {
      _BoLoc.tatCa => 'Chưa có ghi chú nào.\nBấm nút + để tạo ghi chú đầu tiên.',
      _BoLoc.sapToi => 'Không có nhắc hẹn nào sắp tới.',
      _BoLoc.quaHan => 'Không có việc nào quá hạn. 👍',
      _BoLoc.daXong => 'Chưa có ghi chú nào được đánh dấu xong.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(chu, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _tieuDeNhomNgay(String ten, int soLuong) {
    final laQuaHan = ten == '⚠️ Quá hạn';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Text(
            ten,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: laQuaHan ? Colors.red : Colors.black87),
          ),
          const SizedBox(width: 6),
          Text('($soLuong)', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _theGhiChu(GhiChu gc) {
    final loai = LoaiGhiChu.tuMa(gc.loai);
    final uuTien = MucDoUuTien.tuMa(gc.mucDoUuTien);
    final quaHan = gc.thoiGianNhac != null && !gc.daXong && gc.thoiGianNhac!.isBefore(DateTime.now());
    final dangDuocChon = _idDaChon.contains(gc.id);

    // KHÔNG dùng Dismissible/onLongPress (vuốt/giữ tay) - đã xác nhận đây là
    // nguồn gốc gây xung đột cử chỉ, xóa nhầm dữ liệu. Toàn bộ thao tác ở
    // đây là NÚT BẤM TƯỜNG MINH, không thể hiểu nhầm.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      color: dangDuocChon ? AppTheme.viettelRed.withValues(alpha: .08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: dangDuocChon ? const BorderSide(color: AppTheme.viettelRed, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _dangChonNhieu ? _toggleChon(gc.id) : _moThemSua(ghiChuSua: gc),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dangChonNhieu)
                Checkbox(value: dangDuocChon, onChanged: (_) => _toggleChon(gc.id), activeColor: AppTheme.viettelRed)
              else
                Checkbox(value: gc.daXong, onChanged: (v) => _danhDauXong(gc, v ?? false), activeColor: AppTheme.viettelRed),
              Container(width: 4, height: 42, margin: const EdgeInsets.only(top: 12), decoration: BoxDecoration(color: Color(loai.mauHex), borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Cờ ưu tiên - chỉ hiện khi mức ưu tiên KHÔNG PHẢI trung
                          // bình (mặc định), tránh rối mắt cho phần lớn ghi chú
                          // thường không cần nhấn mạnh.
                          if (gc.mucDoUuTien != 1) ...[
                            Icon(Icons.flag, size: 14, color: Color(uuTien.mauHex)),
                            const SizedBox(width: 3),
                          ],
                          Expanded(
                            child: Text(
                              gc.tieuDe,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                decoration: gc.daXong ? TextDecoration.lineThrough : null,
                                color: gc.daXong ? Colors.grey : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Color(loai.mauHex).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                            child: Text(loai.ten, style: TextStyle(fontSize: 11, color: Color(loai.mauHex), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      if (gc.noiDung.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(gc.noiDung, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700)),
                      ],
                      if (gc.soDienThoai != null && gc.soDienThoai!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _goiDien(gc.soDienThoai!),
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(gc.soDienThoai!, style: const TextStyle(fontSize: 12.5, color: Colors.blue, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                      if (gc.thoiGianNhac != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.alarm, size: 14, color: quaHan ? Colors.red : Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm - dd/MM/yyyy').format(gc.thoiGianNhac!),
                              style: TextStyle(fontSize: 12, color: quaHan ? Colors.red : Colors.grey.shade600, fontWeight: quaHan ? FontWeight.bold : null),
                            ),
                            if (quaHan) ...[
                              const SizedBox(width: 6),
                              const Text('QUÁ HẠN', style: TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ],
                      // Huy hiệu "Lặp lại" - riêng cho ghi chú kiểu đóng cước
                      // định kỳ (6 tháng/năm...), giúp nhận ra ngay từ danh
                      // sách đây là việc sẽ tự lặp, không phải việc 1 lần.
                      if (gc.coLapLai) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.repeat, size: 13, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              ChuKyLapLai.tatCa.firstWhere((c) => c.soThang == gc.chuKyLapLaiThang, orElse: () => ChuKyLapLai.tatCa[0]).ten +
                                  (gc.soLanDaGiaHan > 0 ? ' · Đã thu ${gc.soLanDaGiaHan} kỳ' : ''),
                              style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!_dangChonNhieu) ...[
                if (gc.thoiGianNhac != null)
                  IconButton(
                    icon: const Icon(Icons.update, color: Colors.blue, size: 22),
                    tooltip: 'Gia hạn - dời lịch hẹn',
                    onPressed: () => _moGiaHan(gc),
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade500, size: 22),
                  tooltip: 'Xóa ghi chú',
                  onPressed: () async {
                    final xacNhan = await _xacNhanXoa(1);
                    if (xacNhan) _xoa(gc);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Form thêm/sửa 1 ghi chú - hiện dưới dạng bottom sheet.
class _FormGhiChu extends StatefulWidget {
  final GhiChu? ghiChuSua;
  const _FormGhiChu({this.ghiChuSua});

  @override
  State<_FormGhiChu> createState() => _FormGhiChuState();
}

class _FormGhiChuState extends State<_FormGhiChu> {
  late final TextEditingController _tieuDeCtrl;
  late final TextEditingController _noiDungCtrl;
  late final TextEditingController _sdtCtrl;
  late String _loaiChon;
  late int _uuTienChon;
  int? _chuKyLapLaiChon; // null = Không lặp lại
  DateTime? _thoiGianNhac;
  bool _dangLuu = false;

  @override
  void initState() {
    super.initState();
    final g = widget.ghiChuSua;
    _tieuDeCtrl = TextEditingController(text: g?.tieuDe ?? '');
    _noiDungCtrl = TextEditingController(text: g?.noiDung ?? '');
    _sdtCtrl = TextEditingController(text: g?.soDienThoai ?? '');
    _loaiChon = g?.loai ?? 'khac';
    _uuTienChon = g?.mucDoUuTien ?? 1;
    _chuKyLapLaiChon = g?.chuKyLapLaiThang;
    _thoiGianNhac = g?.thoiGianNhac;
  }

  @override
  void dispose() {
    _tieuDeCtrl.dispose();
    _noiDungCtrl.dispose();
    _sdtCtrl.dispose();
    super.dispose();
  }

  Future<void> _chonThoiGian() async {
    final ngay = await showDatePicker(
      context: context,
      initialDate: _thoiGianNhac ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (ngay == null || !mounted) return;
    final gio = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_thoiGianNhac ?? DateTime.now().add(const Duration(hours: 1))),
    );
    if (gio == null) return;
    setState(() => _thoiGianNhac = DateTime(ngay.year, ngay.month, ngay.day, gio.hour, gio.minute));
  }

  /// Đặt nhanh nhắc hẹn theo mốc quen thuộc - đỡ phải mở lịch/giờ chọn tay
  /// từng bước cho việc đơn giản (VD "để lát nữa gọi lại", "mai gặp khách").
  void _datNhanh(Duration? sauKhoang, {DateTime? chinhXac}) {
    setState(() => _thoiGianNhac = chinhXac ?? DateTime.now().add(sauKhoang!));
  }

  Future<void> _tuDatLoai() async {
    final ctrl = TextEditingController(
      text: LoaiGhiChu.laLoaiTuyChon(_loaiChon) ? LoaiGhiChu.tuMa(_loaiChon).ten : '',
    );
    final tenNhap = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tự đặt loại ghi chú'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: 'VD: Bảo trì thiết bị, Sự cố...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Chọn')),
        ],
      ),
    );
    if (tenNhap != null && tenNhap.isNotEmpty) {
      setState(() => _loaiChon = LoaiGhiChu.taoMaTuyChon(tenNhap));
    }
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (_tieuDeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tiêu đề.')));
      return;
    }
    // Lặp lại BẮT BUỘC phải có 1 ngày hẹn làm mốc gốc để tính kỳ tiếp theo -
    // không có hẹn giờ thì không biết tính "kỳ sau" từ đâu.
    if (_chuKyLapLaiChon != null && _thoiGianNhac == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chọn lặp lại - vui lòng đặt ngày giờ nhắc hẹn làm mốc tính kỳ tiếp theo.')));
      return;
    }
    setState(() => _dangLuu = true);
    final gc = GhiChu(
      id: widget.ghiChuSua?.id ?? DateTime.now().millisecondsSinceEpoch,
      tieuDe: _tieuDeCtrl.text.trim(),
      noiDung: _noiDungCtrl.text.trim(),
      loai: _loaiChon,
      soDienThoai: _sdtCtrl.text.trim().isEmpty ? null : _sdtCtrl.text.trim(),
      mucDoUuTien: _uuTienChon,
      thoiGianNhac: _thoiGianNhac,
      chuKyLapLaiThang: _chuKyLapLaiChon,
      soLanDaGiaHan: widget.ghiChuSua?.soLanDaGiaHan ?? 0,
      daXong: widget.ghiChuSua?.daXong ?? false,
      ngayTao: widget.ghiChuSua?.ngayTao ?? DateTime.now(),
    );
    try {
      await GhiChuService.luu(gc);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _dangLuu = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gioLamViecChieuNay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 17, 0);
    final ngayMai8h = DateTime.now().add(const Duration(days: 1));
    final thuHaiTuanSau = DateTime.now().add(Duration(days: 8 - DateTime.now().weekday));

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.ghiChuSua == null ? 'Ghi chú mới' : 'Sửa ghi chú', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _tieuDeCtrl,
              autofocus: widget.ghiChuSua == null,
              decoration: const InputDecoration(labelText: 'Tiêu đề', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noiDungCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Nội dung (không bắt buộc)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sdtCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại (không bắt buộc)',
                prefixIcon: Icon(Icons.phone, size: 20),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Mức độ ưu tiên', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: MucDoUuTien.tatCa
                  .map((m) => ChoiceChip(
                        avatar: Icon(Icons.flag, size: 16, color: _uuTienChon == m.ma ? Colors.white : Color(m.mauHex)),
                        label: Text(m.ten),
                        selected: _uuTienChon == m.ma,
                        selectedColor: Color(m.mauHex),
                        labelStyle: TextStyle(color: _uuTienChon == m.ma ? Colors.white : Colors.black87),
                        onSelected: (_) => setState(() => _uuTienChon = m.ma),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Loại ghi chú', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...LoaiGhiChu.tatCa.map((l) => ChoiceChip(
                      label: Text(l.ten),
                      selected: _loaiChon == l.ma,
                      selectedColor: Color(l.mauHex),
                      labelStyle: TextStyle(color: _loaiChon == l.ma ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _loaiChon = l.ma),
                    )),
                if (LoaiGhiChu.laLoaiTuyChon(_loaiChon))
                  ChoiceChip(
                    label: Text(LoaiGhiChu.tuMa(_loaiChon).ten),
                    selected: true,
                    selectedColor: Color(LoaiGhiChu.tuMa(_loaiChon).mauHex),
                    labelStyle: const TextStyle(color: Colors.white),
                    onSelected: (_) {},
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Tự đặt loại'),
                  onPressed: _tuDatLoai,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Nhắc hẹn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 8),
            // Đặt nhanh theo mốc quen thuộc - đỡ phải tự mở lịch/giờ cho các
            // việc thường ngày, vẫn có nút "Chọn ngày giờ khác" cho trường
            // hợp cần chính xác tuyệt đối.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(label: const Text('1 giờ nữa'), onPressed: () => _datNhanh(const Duration(hours: 1))),
                if (gioLamViecChieuNay.isAfter(DateTime.now()))
                  ActionChip(label: const Text('Chiều nay 17h'), onPressed: () => _datNhanh(null, chinhXac: gioLamViecChieuNay)),
                ActionChip(
                  label: const Text('Ngày mai 8h'),
                  onPressed: () => _datNhanh(null, chinhXac: DateTime(ngayMai8h.year, ngayMai8h.month, ngayMai8h.day, 8, 0)),
                ),
                ActionChip(
                  label: const Text('Thứ 2 tuần sau'),
                  onPressed: () => _datNhanh(null, chinhXac: DateTime(thuHaiTuanSau.year, thuHaiTuanSau.month, thuHaiTuanSau.day, 8, 0)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _chonThoiGian,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(Icons.alarm, color: _thoiGianNhac != null ? AppTheme.viettelRed : Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _thoiGianNhac != null ? DateFormat('HH:mm - dd/MM/yyyy').format(_thoiGianNhac!) : 'Chọn ngày giờ khác...',
                        style: TextStyle(color: _thoiGianNhac != null ? Colors.black87 : Colors.grey.shade600),
                      ),
                    ),
                    if (_thoiGianNhac != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _thoiGianNhac = null;
                          _chuKyLapLaiChon = null; // xóa hẹn giờ thì không còn mốc để tính lặp lại nữa
                        }),
                      ),
                  ],
                ),
              ),
            ),
            // Lặp lại theo chu kỳ - CHỈ hiện khi đã có hẹn giờ (cần làm mốc gốc
            // để tính đúng kỳ tiếp theo). Dành cho việc như "đóng cước trước
            // 6 tháng/năm" - thu xong tự động hẹn lại kỳ sau, không cần tạo
            // ghi chú mới mỗi lần.
            if (_thoiGianNhac != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.repeat, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  const Text('Lặp lại theo chu kỳ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Khi đánh dấu "Đã thu", hệ thống tự tính và hẹn lại đúng kỳ tiếp theo - phù hợp việc đóng cước trước theo gói 6 tháng/năm.',
                    child: Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ChuKyLapLai.tatCa
                    .map((c) => ChoiceChip(
                          label: Text(c.ten),
                          selected: _chuKyLapLaiChon == c.soThang,
                          selectedColor: Colors.teal,
                          labelStyle: TextStyle(color: _chuKyLapLaiChon == c.soThang ? Colors.white : Colors.black87),
                          onSelected: (_) => setState(() => _chuKyLapLaiChon = c.soThang),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dangLuu ? null : _luu,
                child: _dangLuu
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                    : const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
