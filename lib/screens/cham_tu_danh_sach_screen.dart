import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/cham_tu.dart';
import '../services/cham_tu_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'cham_tu_screen.dart';
import 'webview_screen.dart';
import '../config.dart';

class ChamTuDanhSachScreen extends StatefulWidget {
  const ChamTuDanhSachScreen({super.key});

  @override
  State<ChamTuDanhSachScreen> createState() => _ChamTuDanhSachScreenState();
}

class _ChamTuDanhSachScreenState extends State<ChamTuDanhSachScreen> {
  List<ChamTu> _danhSach = [];
  bool _laAdmin = false;
  bool _dangTai = true;
  bool _dangXuLy = false; // chặn bấm nhiều lần khi đang backup/restore/xuất-nhập Excel
  int _idCuaToi = 0;
  final _oTimKiemCtrl = TextEditingController();
  String? _loaiTuLoc;
  String? _trangThaiLoc;
  DateTimeRange? _khoangNgayLoc;
  int? _nguoiTaoLoc; // CHỈ Admin dùng được - lọc theo 1 người tạo cụ thể
  final Map<int, String> _danhSachNguoiTao = {}; // tích lũy dần (id -> tên) từ dữ liệu đã tải, đủ dùng để lọc mà không cần thêm API riêng

  @override
  void initState() {
    super.initState();
    _khoiTao();
    _oTimKiemCtrl.addListener(() => _taiDuLieu());
  }

  @override
  void dispose() {
    _oTimKiemCtrl.dispose();
    super.dispose();
  }

  Future<void> _khoiTao() async {
    final nguoiDung = await AuthService.getCurrentUser();
    _idCuaToi = int.tryParse(nguoiDung['id'] ?? '0') ?? 0;
    await _taiDuLieu();
    // Admin: tải thêm 1 lần KHÔNG lọc gì cả (ngầm) để có đủ danh sách người
    // tạo ngay từ đầu cho bộ lọc - tránh trường hợp người tạo B chưa từng
    // "xuất hiện" trong dữ liệu đã tải (do đang lọc riêng người tạo A) nên
    // không có tên trong danh sách để chọn.
    if (_laAdmin) {
      final tatCa = await ChamTuService.layDanhSach();
      for (final ct in tatCa.danhSach) {
        if (ct.tenNguoiTao.isNotEmpty) _danhSachNguoiTao[ct.customerId] = ct.tenNguoiTao;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ketQua = await ChamTuService.layDanhSach(
      tuKhoa: _oTimKiemCtrl.text.trim(),
      loaiTu: _loaiTuLoc,
      trangThai: _trangThaiLoc,
      tuNgay: _khoangNgayLoc?.start,
      denNgay: _khoangNgayLoc?.end,
      customerId: _nguoiTaoLoc,
    );
    if (!mounted) return;
    // Tích lũy dần danh sách "người tạo" (không xóa cái cũ) - đủ để xây dựng
    // bộ lọc theo người tạo mà không cần thêm 1 API riêng chỉ để liệt kê
    // danh sách nhân viên.
    for (final ct in ketQua.danhSach) {
      if (ct.tenNguoiTao.isNotEmpty) _danhSachNguoiTao[ct.customerId] = ct.tenNguoiTao;
    }
    setState(() {
      _danhSach = ketQua.danhSach;
      _laAdmin = ketQua.laAdmin;
      _dangTai = false;
    });
  }

  bool _duocSuaXoa(ChamTu ct) => _laAdmin || ct.customerId == _idCuaToi;

  Future<void> _moChonNguoiTao() async {
    final chon = await showModalBottomSheet<int?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Tất cả người tạo'),
              trailing: _nguoiTaoLoc == null ? const Icon(Icons.check, color: AppTheme.viettelRed) : null,
              onTap: () => Navigator.pop(context, null),
            ),
            const Divider(height: 1),
            ..._danhSachNguoiTao.entries.map((e) => ListTile(
                  title: Text(e.value),
                  trailing: _nguoiTaoLoc == e.key ? const Icon(Icons.check, color: AppTheme.viettelRed) : null,
                  onTap: () => Navigator.pop(context, e.key),
                )),
          ],
        ),
      ),
    );
    // showModalBottomSheet trả về null CẢ KHI người dùng chọn "Tất cả người
    // tạo" (Navigator.pop(context, null)) LẪN KHI tự đóng không chọn gì - 2
    // trường hợp này cùng hành vi (bỏ lọc) nên gộp xử lý chung là an toàn.
    setState(() => _nguoiTaoLoc = chon);
    _taiDuLieu();
  }

  Future<void> _moChonKhoangNgay() async {
    final ket = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _khoangNgayLoc,
    );
    if (ket != null) {
      setState(() => _khoangNgayLoc = ket);
      _taiDuLieu();
    }
  }

  Future<void> _moTrenBanDoGoogle(ChamTu ct) async {
    final uri = Uri.parse(ct.linkGoogleMaps);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được Google Maps.')));
    }
  }

  void _moBanDoChungXem() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WebViewScreen(url: AppConfig.urlBanDoChamTu, title: 'Bản đồ Chấm tủ')));
  }

  Future<void> _moSua(ChamTu ct) async {
    final ketQua = await Navigator.push(context, MaterialPageRoute(builder: (_) => ChamTuScreen(chamTuSua: ct)));
    if (ketQua == true) _taiDuLieu();
  }

  Future<void> _xoa(ChamTu ct) async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Xóa đề xuất này? Không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    final loi = await ChamTuService.xoaDeXuat(ct.id);
    if (!mounted) return;
    if (loi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa đề xuất.')));
      _taiDuLieu();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _duyet(ChamTu ct) async {
    final loi = await ChamTuService.duyetTuChoi(ct.id, 'duyet');
    if (!mounted) return;
    if (loi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã duyệt đề xuất.'), backgroundColor: Colors.green));
      _taiDuLieu();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _tuChoi(ChamTu ct) async {
    final ctrl = TextEditingController();
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Từ chối đề xuất'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Lý do từ chối (không bắt buộc)', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Từ chối', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    final loi = await ChamTuService.duyetTuChoi(ct.id, 'tu_choi', lyDo: ctrl.text.trim());
    if (!mounted) return;
    if (loi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối đề xuất.')));
      _taiDuLieu();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _xemLichSu({int? deXuatId}) async {
    final ds = await ChamTuService.layLichSu(deXuatId: deXuatId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lịch sử thao tác', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: ds.isEmpty
                    ? const Center(child: Text('Chưa có lịch sử nào.'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: ds.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final nk = ds[i];
                          return ListTile(
                            dense: true,
                            title: Text('${nk['mo_ta'] ?? nk['hanh_dong']}'),
                            subtitle: Text('${nk['ten_nguoi_thao_tac'] ?? ''} · ${nk['thoi_gian'] ?? ''}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sauLuu() async {
    if (_dangXuLy) return;
    setState(() => _dangXuLy = true);
    final file = await ChamTuService.taiBackupVe();
    if (mounted) setState(() => _dangXuLy = false);
    if (file == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sao lưu thất bại.')));
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: 'File sao lưu Chấm tủ đề xuất - Viettel Khu Vực Vĩnh Hưng');
  }

  Future<void> _khoiPhuc() async {
    final ketQuaChon = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (ketQuaChon == null || ketQuaChon.files.single.path == null) return;

    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Khôi phục dữ liệu'),
        content: const Text('Khôi phục sẽ THÊM MỚI/CẬP NHẬT theo ID từ file sao lưu - KHÔNG xóa dữ liệu hiện có. Tiếp tục?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Khôi phục')),
        ],
      ),
    );
    if (xacNhan != true) return;

    if (_dangXuLy) return;
    setState(() => _dangXuLy = true);
    final ketQua = await ChamTuService.khoiPhuc(File(ketQuaChon.files.single.path!));
    if (!mounted) return;
    setState(() => _dangXuLy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ketQua.thongBao)));
    if (ketQua.thanhCong) _taiDuLieu();
  }

  Future<void> _xuatExcel() async {
    if (_dangXuLy) return;
    setState(() => _dangXuLy = true);
    try {
      final file = await ChamTuService.xuatExcel(_danhSach);
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Danh sách Chấm tủ - mở trực tiếp bằng Excel');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xuất file thất bại: $e')));
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  Future<void> _nhapExcel() async {
    final ketQuaChon = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (ketQuaChon == null || ketQuaChon.files.single.bytes == null) {
      // Trên 1 số máy, pickFiles không tự trả kèm bytes - đọc lại từ đường dẫn
      if (ketQuaChon?.files.single.path != null) {
        final bytes = await File(ketQuaChon!.files.single.path!).readAsBytes();
        await _xuLyNhapExcel(bytes);
      }
      return;
    }
    await _xuLyNhapExcel(ketQuaChon.files.single.bytes!);
  }

  Future<void> _xuLyNhapExcel(List<int> bytes) async {
    final danhSachDoc = ChamTuService.docFileExcel(bytes);
    if (danhSachDoc.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không đọc được dữ liệu hợp lệ nào trong file. Lưu ý: chỉ nhập lại được thông tin, KHÔNG nhập lại được ảnh thật (Excel không mang theo file ảnh).')));
      return;
    }
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nhập từ Excel'),
        content: Text('Tìm thấy ${danhSachDoc.length} dòng hợp lệ. LƯU Ý: chỉ nhập lại thông tin (tọa độ, địa chỉ, link ảnh cũ...), KHÔNG upload được ảnh thật mới vì Excel không mang theo file ảnh. Tiếp tục?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nhập dữ liệu')),
        ],
      ),
    );
    if (xacNhan != true) return;

    if (_dangXuLy) return;
    setState(() => _dangXuLy = true);
    final ketQua = await ChamTuService.nhapExcel(danhSachDoc);
    if (!mounted) return;
    setState(() => _dangXuLy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ketQua.thongBao)));
    if (ketQua.thanhCong) _taiDuLieu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách Chấm tủ'),
        actions: [
          IconButton(icon: const Icon(Icons.map), tooltip: 'Xem bản đồ', onPressed: _moBanDoChungXem),
          PopupMenuButton<String>(
            enabled: !_dangXuLy,
            onSelected: (gt) {
              if (gt == 'xuat_excel') _xuatExcel();
              if (gt == 'nhap_excel') _nhapExcel();
              if (gt == 'sao_luu') _sauLuu();
              if (gt == 'khoi_phuc') _khoiPhuc();
              if (gt == 'lich_su') _xemLichSu();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'xuat_excel', child: ListTile(leading: Icon(Icons.table_chart), title: Text('Xuất Excel'), contentPadding: EdgeInsets.zero)),
              if (_laAdmin) ...[
                const PopupMenuItem(value: 'nhap_excel', child: ListTile(leading: Icon(Icons.upload_file), title: Text('Nhập từ Excel'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'sao_luu', child: ListTile(leading: Icon(Icons.backup), title: Text('Sao lưu (ZIP)'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'khoi_phuc', child: ListTile(leading: Icon(Icons.restore), title: Text('Khôi phục'), contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'lich_su', child: ListTile(leading: Icon(Icons.history), title: Text('Xem lịch sử'), contentPadding: EdgeInsets.zero)),
              ],
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_dangXuLy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _oTimKiemCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo địa chỉ, ghi chú, người tạo...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          _thanhLoc(),
          Expanded(
            child: _dangTai
                ? const Center(child: CircularProgressIndicator())
                : _danhSach.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('Chưa có đề xuất nào.', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _taiDuLieu,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          itemCount: _danhSach.length,
                          itemBuilder: (context, i) => _theChamTu(_danhSach[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.viettelRed,
        onPressed: () async {
          final ketQua = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChamTuScreen()));
          if (ketQua == true) _taiDuLieu();
        },
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _thanhLoc() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _chipLoc('Tất cả loại', _loaiTuLoc == null, () { setState(() => _loaiTuLoc = null); _taiDuLieu(); }),
          _chipLoc(LoaiTu.ten(LoaiTu.tuCung), _loaiTuLoc == LoaiTu.tuCung, () { setState(() => _loaiTuLoc = LoaiTu.tuCung); _taiDuLieu(); }),
          _chipLoc(LoaiTu.ten(LoaiTu.tu8), _loaiTuLoc == LoaiTu.tu8, () { setState(() => _loaiTuLoc = LoaiTu.tu8); _taiDuLieu(); }),
          _chipLoc('Chờ duyệt', _trangThaiLoc == TrangThaiChamTu.choDuyet, () { setState(() => _trangThaiLoc = _trangThaiLoc == TrangThaiChamTu.choDuyet ? null : TrangThaiChamTu.choDuyet); _taiDuLieu(); }),
          _chipLoc('Đã duyệt', _trangThaiLoc == TrangThaiChamTu.daDuyet, () { setState(() => _trangThaiLoc = _trangThaiLoc == TrangThaiChamTu.daDuyet ? null : TrangThaiChamTu.daDuyet); _taiDuLieu(); }),
          ActionChip(
            avatar: Icon(Icons.date_range, size: 16, color: _khoangNgayLoc != null ? Colors.white : null),
            label: Text(_khoangNgayLoc == null ? 'Chọn ngày' : '${DateFormat('dd/MM').format(_khoangNgayLoc!.start)}-${DateFormat('dd/MM').format(_khoangNgayLoc!.end)}'),
            backgroundColor: _khoangNgayLoc != null ? AppTheme.viettelRed : null,
            labelStyle: TextStyle(color: _khoangNgayLoc != null ? Colors.white : Colors.black87, fontSize: 12.5),
            onPressed: _moChonKhoangNgay,
          ),
          if (_laAdmin)
            ActionChip(
              avatar: Icon(Icons.person, size: 16, color: _nguoiTaoLoc != null ? Colors.white : null),
              label: Text(_nguoiTaoLoc == null ? 'Người tạo' : (_danhSachNguoiTao[_nguoiTaoLoc] ?? 'Người tạo')),
              backgroundColor: _nguoiTaoLoc != null ? AppTheme.viettelRed : null,
              labelStyle: TextStyle(color: _nguoiTaoLoc != null ? Colors.white : Colors.black87, fontSize: 12.5),
              onPressed: _moChonNguoiTao,
            ),
        ],
      ),
    );
  }

  Widget _chipLoc(String ten, bool dangChon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(ten, style: const TextStyle(fontSize: 12.5)),
        selected: dangChon,
        selectedColor: AppTheme.viettelRed,
        labelStyle: TextStyle(color: dangChon ? Colors.white : Colors.black87),
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _theChamTu(ChamTu ct) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _moChiTiet(ct),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  child: Image.network(
                    ct.anhUrl,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                    loadingBuilder: (context, child, progress) => progress == null ? child : Container(width: 90, height: 90, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Color(LoaiTu.mauHex(ct.loaiTu)).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                              child: Text(LoaiTu.ten(ct.loaiTu), style: TextStyle(fontSize: 11, color: Color(LoaiTu.mauHex(ct.loaiTu)), fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Color(TrangThaiChamTu.mauHex(ct.trangThai)).withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
                              child: Text(TrangThaiChamTu.ten(ct.trangThai), style: TextStyle(fontSize: 11, color: Color(TrangThaiChamTu.mauHex(ct.trangThai)), fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(ct.diaChi.isEmpty ? '(Chưa có địa chỉ)' : ct.diaChi, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                        const SizedBox(height: 4),
                        Text('${ct.tenNguoiTao} · ${DateFormat('HH:mm dd/MM/yyyy').format(ct.ngayTao)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Hàng nút thao tác - hiện đúng theo quyền: Admin thấy Duyệt/Từ
            // chối (nếu đang chờ) + Sửa/Xóa của BẤT KỲ AI; User chỉ thấy
            // Sửa/Xóa của CHÍNH MÌNH.
            if (_duocSuaXoa(ct) || (_laAdmin && ct.trangThai == TrangThaiChamTu.choDuyet))
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    if (_laAdmin && ct.trangThai == TrangThaiChamTu.choDuyet) ...[
                      TextButton.icon(onPressed: () => _duyet(ct), icon: const Icon(Icons.check, size: 16, color: Colors.green), label: const Text('Duyệt', style: TextStyle(color: Colors.green, fontSize: 12.5))),
                      TextButton.icon(onPressed: () => _tuChoi(ct), icon: const Icon(Icons.close, size: 16, color: Colors.red), label: const Text('Từ chối', style: TextStyle(color: Colors.red, fontSize: 12.5))),
                    ],
                    if (_duocSuaXoa(ct)) ...[
                      TextButton.icon(onPressed: () => _moSua(ct), icon: const Icon(Icons.edit, size: 16), label: const Text('Sửa', style: TextStyle(fontSize: 12.5))),
                      TextButton.icon(onPressed: () => _xoa(ct), icon: const Icon(Icons.delete, size: 16, color: Colors.grey), label: const Text('Xóa', style: TextStyle(color: Colors.grey, fontSize: 12.5))),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _moChiTiet(ChamTu ct) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(ct.anhUrl, width: double.infinity, height: 220, fit: BoxFit.cover)),
              const SizedBox(height: 14),
              Text(LoaiTu.ten(ct.loaiTu), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(ct.diaChi.isEmpty ? '(Chưa có địa chỉ)' : ct.diaChi, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 6),
              Text('Người tạo: ${ct.tenNguoiTao}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              Text('GPS: ${ct.latitude.toStringAsFixed(6)}, ${ct.longitude.toStringAsFixed(6)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              Text('Thời gian: ${DateFormat('HH:mm dd/MM/yyyy').format(ct.ngayTao)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              if (ct.ghiChu.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Ghi chú: ${ct.ghiChu}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ],
              if (ct.trangThai == TrangThaiChamTu.tuChoi && (ct.lyDoTuChoi ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Lý do từ chối: ${ct.lyDoTuChoi}', style: const TextStyle(fontSize: 13, color: Colors.red)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(onPressed: () => _moTrenBanDoGoogle(ct), icon: const Icon(Icons.map), label: const Text('Mở trên Google Maps')),
              ),
              if (_laAdmin) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(context); _xemLichSu(deXuatId: ct.id); },
                    icon: const Icon(Icons.history),
                    label: const Text('Xem lịch sử đề xuất này'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
