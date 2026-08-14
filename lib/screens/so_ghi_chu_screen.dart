import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/ghi_chu_tu_do.dart';
import '../services/ghi_chu_tu_do_service.dart';
import 've_tay_screen.dart';

/// Sổ ghi chú kiểu "Ghi chú" của iOS - hỗ trợ chữ, nét vẽ tay, ghi âm. Lưu
/// hoàn toàn offline trên máy (không đồng bộ server) - dùng cho ghi chú
/// nhanh, riêng tư của từng CNKD. KHÔNG liên quan tới "Quản lý dữ liệu
/// khách hàng" (trước đây gọi là Sổ ghi chú, đã đổi tên và chuyển sang mục
/// Công việc & KPI, dữ liệu 2 bên hoàn toàn tách biệt).
class SoGhiChuScreen extends StatefulWidget {
  const SoGhiChuScreen({super.key});

  @override
  State<SoGhiChuScreen> createState() => _SoGhiChuScreenState();
}

class _SoGhiChuScreenState extends State<SoGhiChuScreen> {
  List<GhiChuTuDo> _danhSach = [];
  bool _dangTai = true;
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

  Future<void> _taiThoiGianSaoLuu() async {
    final t = await GhiChuTuDoService.layLanSaoLuuCuoi();
    if (mounted) setState(() => _lanSaoLuuCuoi = t);
  }

  @override
  void dispose() {
    _oTimKiemCtrl.dispose();
    super.dispose();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ds = await GhiChuTuDoService.layDanhSach();
    if (mounted) setState(() { _danhSach = ds; _dangTai = false; });
  }

  List<GhiChuTuDo> get _dsHienThi {
    if (_tuKhoa.isEmpty) return _danhSach;
    return _danhSach.where((g) =>
        g.tieuDeHienThi.toLowerCase().contains(_tuKhoa) || g.noiDung.toLowerCase().contains(_tuKhoa)).toList();
  }

  Future<void> _moGhiChu([GhiChuTuDo? ghiChu]) async {
    final daLuu = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GhiChuTuDoChiTietScreen(ghiChu: ghiChu)),
    );
    if (daLuu == true) _taiDuLieu();
  }

  Future<void> _xoaGhiChu(GhiChuTuDo ghiChu) async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa ghi chú?'),
        content: Text('Xóa "${ghiChu.tieuDeHienThi}"? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    await GhiChuTuDoService.xoa(ghiChu.id);
    _taiDuLieu();
  }

  Future<void> _saoLuu() async {
    try {
      final file = await GhiChuTuDoService.xuatBackup();
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

      if (!mounted) return;
      final xacNhan = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Khôi phục dữ liệu'),
          content: const Text(
            'Khôi phục sẽ THÊM MỚI/CẬP NHẬT ghi chú (kèm ảnh vẽ tay, ghi âm) từ '
            'file sao lưu vào Sổ ghi chú hiện tại - KHÔNG xóa ghi chú đang có sẵn. Tiếp tục?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Khôi phục')),
          ],
        ),
      );
      if (xacNhan != true) return;

      final soLuong = await GhiChuTuDoService.khoiPhucTuFile(File(ketQua.files.single.path!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã khôi phục $soLuong ghi chú.')));
      _taiDuLieu();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Khôi phục thất bại: file không đúng định dạng sao lưu.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sổ ghi chú'),
        backgroundColor: const Color(0xFFEE0033),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (gt) {
              if (gt == 'sao_luu') _saoLuu();
              if (gt == 'khoi_phuc') _khoiPhuc();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sao_luu', child: ListTile(leading: Icon(Icons.backup), title: Text('Sao lưu'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'khoi_phuc', child: ListTile(leading: Icon(Icons.restore), title: Text('Khôi phục'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _canhBaoSaoLuu(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _oTimKiemCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm ghi chú...',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _tuKhoa.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _oTimKiemCtrl.clear) : null,
              ),
            ),
          ),
          if (_dangTai) const LinearProgressIndicator(),
          Expanded(
            child: _dsHienThi.isEmpty
                ? Center(
                    child: Text(_danhSach.isEmpty ? 'Chưa có ghi chú nào.\nBấm + để tạo ghi chú đầu tiên.' : 'Không tìm thấy ghi chú khớp.',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _dsHienThi.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final g = _dsHienThi[i];
                      final dongTom = g.noiDung.trim().split('\n').where((d) => d.trim().isNotEmpty).skip(g.tieuDe.trim().isEmpty ? 1 : 0).join(' ').trim();
                      return ListTile(
                        title: Text(g.tieuDeHienThi, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd/MM/yyyy HH:mm').format(g.ngayCapNhat), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                            if (dongTom.isNotEmpty) Text(dongTom, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            Row(children: [
                              if (g.coVeTay) const Padding(padding: EdgeInsets.only(top: 4, right: 8), child: Icon(Icons.draw, size: 15, color: Colors.grey)),
                              if (g.coGhiAm) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.mic, size: 15, color: Colors.grey)),
                            ]),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => _moGhiChu(g),
                        onLongPress: () => _xoaGhiChu(g),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => _xoaGhiChu(g)),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFEE0033),
        onPressed: () => _moGhiChu(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Nhắc sao lưu định kỳ - dữ liệu CHỈ nằm trên máy (không đồng bộ server),
  /// XÓA APP CÀI LẠI SẼ MẤT TRẮNG nếu không sao lưu trước. Hiện nếu CHƯA
  /// TỪNG sao lưu, hoặc đã quá 14 ngày chưa sao lưu lại.
  Widget _canhBaoSaoLuu() {
    final quaHan = _lanSaoLuuCuoi == null || DateTime.now().difference(_lanSaoLuuCuoi!).inDays >= 14;
    if (!quaHan || _danhSach.isEmpty) return const SizedBox.shrink();
    final chu = _lanSaoLuuCuoi == null
        ? 'Anh/chị chưa sao lưu Sổ ghi chú lần nào. Nên sao lưu để tránh mất dữ liệu khi xóa/cài lại app.'
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
          TextButton(onPressed: _saoLuu, child: const Text('Sao lưu ngay')),
        ],
      ),
    );
  }
}

/// Màn soạn thảo 1 ghi chú - chữ (chính), kèm nét vẽ tay và/hoặc ghi âm.
class GhiChuTuDoChiTietScreen extends StatefulWidget {
  final GhiChuTuDo? ghiChu; // null = tạo ghi chú mới
  const GhiChuTuDoChiTietScreen({super.key, this.ghiChu});

  @override
  State<GhiChuTuDoChiTietScreen> createState() => _GhiChuTuDoChiTietScreenState();
}

class _GhiChuTuDoChiTietScreenState extends State<GhiChuTuDoChiTietScreen> {
  late final TextEditingController _oTieuDe;
  late final TextEditingController _oNoiDung;
  String? _duongDanVeTay;
  String? _duongDanGhiAm;
  int? _giayGhiAm;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _dangGhiAm = false;
  bool _dangPhat = false;
  int _giayDangGhi = 0;
  Timer? _timerGhiAm;
  String? _duongDanGhiAmTam;

  bool get _laGhiChuMoi => widget.ghiChu == null;

  @override
  void initState() {
    super.initState();
    _oTieuDe = TextEditingController(text: widget.ghiChu?.tieuDe ?? '');
    _oNoiDung = TextEditingController(text: widget.ghiChu?.noiDung ?? '');
    _duongDanVeTay = widget.ghiChu?.duongDanVeTay;
    _duongDanGhiAm = widget.ghiChu?.duongDanGhiAm;
    _giayGhiAm = widget.ghiChu?.giayGhiAm;

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _dangPhat = s == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _dangPhat = false);
    });
  }

  @override
  void dispose() {
    _oTieuDe.dispose();
    _oNoiDung.dispose();
    _timerGhiAm?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _veTay() async {
    Uint8List? anhNenCu;
    if (_duongDanVeTay != null) {
      final f = File(_duongDanVeTay!);
      if (await f.exists()) anhNenCu = await f.readAsBytes();
    }
    if (!mounted) return;
    final ketQua = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => VeTayScreen(anhBanDauNenVe: anhNenCu)),
    );
    if (ketQua == null) return; // hủy, không đổi gì
    final duongDanMoi = await GhiChuTuDoService.duongDanTepMoi('png');
    await File(duongDanMoi).writeAsBytes(ketQua);
    // Xóa file ảnh cũ (nếu có) để không tích rác trên máy.
    if (_duongDanVeTay != null) {
      final fCu = File(_duongDanVeTay!);
      if (await fCu.exists()) await fCu.delete();
    }
    if (mounted) setState(() => _duongDanVeTay = duongDanMoi);
  }

  void _xoaVeTay() {
    setState(() => _duongDanVeTay = null);
  }

  Future<void> _batDauGhiAm() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần cấp quyền micro để ghi âm.')));
      return;
    }
    _duongDanGhiAmTam = await GhiChuTuDoService.duongDanTepMoi('m4a');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _duongDanGhiAmTam!);
    setState(() { _dangGhiAm = true; _giayDangGhi = 0; });
    _timerGhiAm = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _giayDangGhi++);
      if (_giayDangGhi >= 600) _dungGhiAm(); // tự dừng ở mốc 10 phút
    });
  }

  Future<void> _dungGhiAm() async {
    _timerGhiAm?.cancel();
    final duongDan = await _recorder.stop();
    final thoiLuong = _giayDangGhi;
    setState(() => _dangGhiAm = false);
    if (duongDan == null || thoiLuong < 1) {
      if (duongDan != null) {
        final f = File(duongDan);
        if (await f.exists()) await f.delete();
      }
      return;
    }
    if (_duongDanGhiAm != null) {
      final fCu = File(_duongDanGhiAm!);
      if (await fCu.exists()) await fCu.delete();
    }
    setState(() {
      _duongDanGhiAm = duongDan;
      _giayGhiAm = thoiLuong;
    });
  }

  Future<void> _huyGhiAm() async {
    _timerGhiAm?.cancel();
    if (await _recorder.isRecording()) await _recorder.stop();
    if (_duongDanGhiAmTam != null) {
      final f = File(_duongDanGhiAmTam!);
      if (await f.exists()) await f.delete();
    }
    setState(() => _dangGhiAm = false);
  }

  Future<void> _phatGhiAm() async {
    if (_duongDanGhiAm == null) return;
    if (_dangPhat) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(_duongDanGhiAm!));
    }
  }

  void _xoaGhiAm() {
    setState(() { _duongDanGhiAm = null; _giayGhiAm = null; });
  }

  String _dinhDangGiay(int giay) {
    final p = (giay ~/ 60).toString().padLeft(2, '0');
    final g = (giay % 60).toString().padLeft(2, '0');
    return '$p:$g';
  }

  Future<void> _luuVaThoat() async {
    if (_oTieuDe.text.trim().isEmpty && _oNoiDung.text.trim().isEmpty && _duongDanVeTay == null && _duongDanGhiAm == null) {
      if (mounted) Navigator.pop(context, false); // ghi chú trống - không lưu gì cả
      return;
    }
    final gio = DateTime.now();
    final ghiChu = GhiChuTuDo(
      id: widget.ghiChu?.id ?? gio.millisecondsSinceEpoch,
      tieuDe: _oTieuDe.text.trim(),
      noiDung: _oNoiDung.text,
      duongDanVeTay: _duongDanVeTay,
      duongDanGhiAm: _duongDanGhiAm,
      giayGhiAm: _giayGhiAm,
      ngayTao: widget.ghiChu?.ngayTao ?? gio,
      ngayCapNhat: gio,
    );
    await GhiChuTuDoService.luu(ghiChu);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _luuVaThoat();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_laGhiChuMoi ? 'Ghi chú mới' : 'Sửa ghi chú'),
          backgroundColor: const Color(0xFFEE0033),
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _luuVaThoat),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  TextField(
                    controller: _oTieuDe,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: 'Tiêu đề (bỏ trống sẽ tự lấy dòng đầu)', border: InputBorder.none),
                  ),
                  TextField(
                    controller: _oNoiDung,
                    maxLines: null,
                    minLines: 6,
                    style: const TextStyle(fontSize: 15.5),
                    decoration: const InputDecoration(hintText: 'Nội dung ghi chú...', border: InputBorder.none),
                  ),
                  if (_duongDanVeTay != null) ...[
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                            child: GestureDetector(onTap: _veTay, child: Image.file(File(_duongDanVeTay!))),
                          ),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: InkWell(
                            onTap: _xoaVeTay,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_duongDanGhiAm != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        IconButton(icon: Icon(_dangPhat ? Icons.pause_circle : Icons.play_circle, color: const Color(0xFFEE0033)), onPressed: _phatGhiAm),
                        Text('🎤 Ghi âm  ${_dinhDangGiay(_giayGhiAm ?? 0)}'),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: _xoaGhiAm),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
            if (_dangGhiAm)
              Container(
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Text('Đang ghi âm  ${_dinhDangGiay(_giayDangGhi)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(onPressed: _huyGhiAm, child: const Text('Hủy')),
                  FilledButton(onPressed: _dungGhiAm, style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEE0033)), child: const Text('Dừng')),
                ]),
              ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.draw_outlined), tooltip: 'Viết tay', onPressed: _veTay),
                  IconButton(
                    icon: const Icon(Icons.mic_none),
                    tooltip: 'Ghi âm',
                    color: _dangGhiAm ? Colors.red : null,
                    onPressed: _dangGhiAm ? null : _batDauGhiAm,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
