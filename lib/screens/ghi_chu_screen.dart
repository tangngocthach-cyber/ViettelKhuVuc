import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  Future<void> _taiDuLieu() async {
    final ds = await GhiChuService.layDanhSach();
    if (!mounted) return;
    setState(() {
      _tatCaGhiChu = ds;
      _dangTai = false;
    });
  }

  List<GhiChu> get _dsHienThi {
    final gio = DateTime.now();
    switch (_boLoc) {
      case _BoLoc.tatCa:
        return _tatCaGhiChu.where((g) => !g.daXong).toList();
      case _BoLoc.sapToi:
        return _tatCaGhiChu.where((g) => !g.daXong && g.thoiGianNhac != null && g.thoiGianNhac!.isAfter(gio)).toList();
      case _BoLoc.quaHan:
        return _tatCaGhiChu.where((g) => !g.daXong && g.thoiGianNhac != null && g.thoiGianNhac!.isBefore(gio)).toList();
      case _BoLoc.daXong:
        return _tatCaGhiChu.where((g) => g.daXong).toList();
    }
  }

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
        messenger.clearSnackBars(); // xóa thông báo cũ đang xếp hàng chờ (nếu có) - tránh bị nuốt mất thông báo mới
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

  /// Hỏi xác nhận trước khi xóa - dùng chung cho cả xóa 1 ghi chú (vuốt trái)
  /// và xóa nhiều ghi chú cùng lúc (chế độ chọn nhiều). Xóa dữ liệu là hành
  /// động KHÔNG THỂ HOÀN TÁC nên bắt buộc phải hỏi lại trước khi thực hiện.
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
        if (_idDaChon.isEmpty) _dangChonNhieu = false; // bỏ chọn hết -> tự thoát chế độ chọn nhiều
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
    await GhiChuService.danhDauXong(gc.id, xong);
    _taiDuLieu();
  }

  Future<void> _sauLuu() async {
    try {
      final file = await GhiChuService.xuatBackup();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'File sao lưu Sổ ghi chú - Viettel Khu Vực Vĩnh Hưng');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sao lưu thất bại: $e')));
    }
  }

  Future<void> _khoiPhuc() async {
    try {
      final ketQua = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (ketQua == null || ketQua.files.single.path == null) return; // người dùng bấm Hủy

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Khôi phục thất bại: file không đúng định dạng sao lưu.')));
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
          _thanhLoc(),
          Expanded(
            child: _dangTai
                ? const Center(child: CircularProgressIndicator())
                : ds.isEmpty
                    ? _trangThaiRong()
                    : RefreshIndicator(
                        onRefresh: _taiDuLieu,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                          itemCount: ds.length,
                          itemBuilder: (context, i) => _theGhiChu(ds[i]),
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
                    label: Text(m.$2),
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

  Widget _theGhiChu(GhiChu gc) {
    final loai = LoaiGhiChu.tuMa(gc.loai);
    final quaHan = gc.thoiGianNhac != null && !gc.daXong && gc.thoiGianNhac!.isBefore(DateTime.now());
    final dangDuocChon = _idDaChon.contains(gc.id);

    // QUAN TRỌNG: KHÔNG dùng Dismissible (vuốt để xóa/đánh dấu xong) kết hợp
    // chung với onLongPress (giữ tay để chọn nhiều) - đây CHÍNH LÀ nguyên
    // nhân lỗi thật đã gặp: 2 cử chỉ (vuốt ngang và giữ tay) cùng tranh chấp
    // trên 1 vùng chạm khiến Flutter đôi khi hiểu "giữ tay rồi thả ra" thành
    // "đã vuốt xóa dở dang", tự động xóa ngoài ý muốn. Thay bằng CÁC NÚT BẤM
    // TƯỜNG MINH - không thể hiểu nhầm, an toàn tuyệt đối cho dữ liệu.
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
              // Ở chế độ chọn nhiều: hiện checkbox CHỌN. Bình thường: hiện
              // checkbox ĐÁNH DẤU XONG - cả 2 đều là BẤM TRỰC TIẾP, không
              // liên quan gì tới vuốt/giữ tay nữa.
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
                    ],
                  ),
                ),
              ),
              // Nút xóa RIÊNG, luôn hiện rõ (trừ lúc đang chọn nhiều) - bấm vào
              // MỚI hỏi xác nhận rồi mới xóa, không còn liên quan gì tới thao
              // tác vuốt/giữ tay mơ hồ dễ xóa nhầm như trước.
              if (!_dangChonNhieu)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey.shade500, size: 22),
                  tooltip: 'Xóa ghi chú',
                  onPressed: () async {
                    final xacNhan = await _xacNhanXoa(1);
                    if (xacNhan) _xoa(gc);
                  },
                ),
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
  late String _loaiChon;
  DateTime? _thoiGianNhac;
  bool _dangLuu = false; // chặn bấm Lưu nhiều lần liên tiếp tạo trùng ghi chú

  @override
  void initState() {
    super.initState();
    final g = widget.ghiChuSua;
    _tieuDeCtrl = TextEditingController(text: g?.tieuDe ?? '');
    _noiDungCtrl = TextEditingController(text: g?.noiDung ?? '');
    _loaiChon = g?.loai ?? 'khac';
    _thoiGianNhac = g?.thoiGianNhac;
  }

  @override
  void dispose() {
    _tieuDeCtrl.dispose();
    _noiDungCtrl.dispose();
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
    if (_dangLuu) return; // ĐANG lưu rồi - bỏ qua các lần bấm thêm, tránh tạo trùng
    if (_tieuDeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tiêu đề.')));
      return;
    }
    setState(() => _dangLuu = true);
    final gc = GhiChu(
      // Dùng MILI-GIÂY (không chia /1000 như trước) làm ID ghi chú mới - loại
      // bỏ hoàn toàn khả năng 2 lần tạo trong CÙNG 1 GIÂY bị trùng ID (dù giờ
      // đã có _dangLuu chặn bấm nhiều lần, vẫn giữ thêm lớp an toàn này).
      id: widget.ghiChuSua?.id ?? DateTime.now().millisecondsSinceEpoch,
      tieuDe: _tieuDeCtrl.text.trim(),
      noiDung: _noiDungCtrl.text.trim(),
      loai: _loaiChon,
      thoiGianNhac: _thoiGianNhac,
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // Cộng thêm CẢ 2: khoảng trống do bàn phím che (viewInsets) VÀ vùng an
        // toàn do thanh điều hướng điện thoại che (padding.bottom) - thiếu 1
        // trong 2 đều khiến nút "Lưu" bị khuất khó bấm (lỗi thật đã gặp).
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
            const SizedBox(height: 14),
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
                // Nếu đang chọn 1 loại TỰ ĐẶT (không nằm trong danh sách dựng
                // sẵn ở trên) -> hiện thêm 1 chip riêng cho đúng tên đã nhập,
                // để người dùng thấy rõ đang chọn đúng loại mình vừa tạo.
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
            const SizedBox(height: 14),
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
                        _thoiGianNhac != null ? DateFormat('HH:mm - dd/MM/yyyy').format(_thoiGianNhac!) : 'Đặt nhắc hẹn (không bắt buộc)',
                        style: TextStyle(color: _thoiGianNhac != null ? Colors.black87 : Colors.grey.shade600),
                      ),
                    ),
                    if (_thoiGianNhac != null)
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _thoiGianNhac = null)),
                  ],
                ),
              ),
            ),
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
