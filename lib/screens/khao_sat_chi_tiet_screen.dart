import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../models/khao_sat.dart';
import '../services/khao_sat_service.dart';

/// Màn hình 2 - danh sách khách hàng trong 1 đợt khảo sát cụ thể. Bấm vào 1
/// khách để mở form khảo sát (lý do + mô tả + các trường tùy chỉnh do Admin
/// tự thiết đặt riêng cho đợt này).
class KhaoSatChiTietScreen extends StatefulWidget {
  final int dotId;
  final String tenDot;
  const KhaoSatChiTietScreen({super.key, required this.dotId, required this.tenDot});

  @override
  State<KhaoSatChiTietScreen> createState() => _KhaoSatChiTietScreenState();
}

class _KhaoSatChiTietScreenState extends State<KhaoSatChiTietScreen> {
  bool _dangTai = true;
  String? _loi;
  List<KhaoSatKhachHang> _dsKhachHang = [];
  List<KhaoSatTruongTin> _dsTruongTin = [];
  List<KhaoSatLyDo> _dsLyDo = [];
  final _oTimKiem = TextEditingController();
  String _tuKhoa = '';
  String? _tvvDangChon; // null = tất cả
  String? _trangThaiDangChon; // null = tất cả, 'da' = đã khảo sát, 'chua' = chưa khảo sát

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
    _oTimKiem.addListener(() => setState(() => _tuKhoa = _oTimKiem.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _oTimKiem.dispose();
    super.dispose();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ketQua = await KhaoSatService.layChiTietDot(widget.dotId);
    if (!mounted) return;
    setState(() {
      _dsKhachHang = ketQua.khachHang;
      _dsTruongTin = ketQua.truongTin;
      _dsLyDo = ketQua.lyDo;
      _loi = ketQua.loi;
      _dangTai = false;
    });
  }

  /// Danh sách MÃ TVV có mặt trong đợt này (lấy từ chính dữ liệu đã tải, KHÔNG
  /// gọi thêm API riêng) - dùng cho dropdown lọc.
  List<String> get _dsMaTvv {
    final s = _dsKhachHang.map((kh) => kh.maTvv).where((tvv) => tvv.isNotEmpty).toSet().toList();
    s.sort();
    return s;
  }

  List<KhaoSatKhachHang> get _dsHienThi {
    var ds = _dsKhachHang;
    if (_tvvDangChon != null) ds = ds.where((kh) => kh.maTvv == _tvvDangChon).toList();
    if (_trangThaiDangChon == 'da') ds = ds.where((kh) => kh.daKhaoSat).toList();
    if (_trangThaiDangChon == 'chua') ds = ds.where((kh) => !kh.daKhaoSat).toList();
    if (_tuKhoa.isNotEmpty) ds = ds.where((kh) => kh.tenKhachHang.toLowerCase().contains(_tuKhoa) || kh.soTb.toLowerCase().contains(_tuKhoa)).toList();
    return ds;
  }

  /// Tiến độ đã/chưa khảo sát theo ĐÚNG mã TVV đang lọc (KHÔNG tính lọc
  /// trạng thái/từ khóa, vì đó chính là cái đang muốn đếm) - để CNKD biết
  /// ngay còn thiếu bao nhiêu người chưa cập nhật, tránh sót.
  ({int tong, int daXong}) get _tienDoTheoTvv {
    final ds = _tvvDangChon == null ? _dsKhachHang : _dsKhachHang.where((kh) => kh.maTvv == _tvvDangChon).toList();
    return (tong: ds.length, daXong: ds.where((kh) => kh.daKhaoSat).length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tenDot, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Xuất Excel KH đã khảo sát',
            onPressed: _xuatExcel,
          ),
        ],
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : _loi != null
              ? _khungLoi()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextField(
                        controller: _oTimKiem,
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên khách hàng hoặc số TB...',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixIcon: _tuKhoa.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: _oTimKiem.clear) : null,
                        ),
                      ),
                    ),
                    if (_dsMaTvv.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: DropdownButtonFormField<String?>(
                          value: _tvvDangChon,
                          decoration: const InputDecoration(labelText: 'Tư vấn viên (CNKD)', isDense: true, border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('-- Tất cả --')),
                            ..._dsMaTvv.map((tvv) => DropdownMenuItem<String?>(value: tvv, child: Text(tvv))),
                          ],
                          onChanged: (v) => setState(() => _tvvDangChon = v),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      child: Row(
                        children: [
                          ChoiceChip(label: const Text('Tất cả'), selected: _trangThaiDangChon == null, onSelected: (_) => setState(() => _trangThaiDangChon = null)),
                          const SizedBox(width: 6),
                          ChoiceChip(label: const Text('Chưa khảo sát'), selected: _trangThaiDangChon == 'chua', onSelected: (_) => setState(() => _trangThaiDangChon = 'chua')),
                          const SizedBox(width: 6),
                          ChoiceChip(label: const Text('Đã khảo sát'), selected: _trangThaiDangChon == 'da', onSelected: (_) => setState(() => _trangThaiDangChon = 'da')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Builder(builder: (context) {
                        final td = _tienDoTheoTvv;
                        final conThieu = td.tong - td.daXong;
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text.rich(TextSpan(
                            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                            children: [
                              TextSpan(text: (_tvvDangChon != null ? 'CNKD $_tvvDangChon: ' : 'Toàn đợt: ')),
                              TextSpan(text: 'đã khảo sát ${td.daXong}/${td.tong} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                              TextSpan(
                                text: conThieu > 0 ? '(còn thiếu $conThieu)' : '(đã xong hết)',
                                style: TextStyle(color: conThieu > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _dsHienThi.isEmpty
                          ? const Center(child: Text('Không tìm thấy khách hàng nào.', style: TextStyle(color: Colors.grey)))
                          : RefreshIndicator(
                              onRefresh: _taiDuLieu,
                              child: ListView.builder(
                                itemCount: _dsHienThi.length,
                                itemBuilder: (context, i) => _dongKhachHang(_dsHienThi[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _khungLoi() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(_loi!, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: _taiDuLieu, child: const Text('Thử lại'))),
      ],
    );
  }

  Widget _dongKhachHang(KhaoSatKhachHang kh) {
    final chiTietPhu = [kh.soTb, kh.sdt, if (_tvvDangChon == null && kh.maTvv.isNotEmpty) 'TVV: ${kh.maTvv}'].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      title: Text(kh.tenKhachHang, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(chiTietPhu),
      trailing: kh.daKhaoSat
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      onTap: () => _moFormKhaoSat(kh),
    );
  }

  Future<void> _moFormKhaoSat(KhaoSatKhachHang kh) async {
    // Nếu lý do đã lưu trước đây KHÔNG CÒN nằm trong danh mục lý do hiện tại
    // (VD Admin đã xóa/sửa lý do đó sau khi khách này đã được khảo sát) thì
    // KHÔNG gán giá trị đó vào dropdown - tránh crash "giá trị không khớp
    // danh sách lựa chọn" của DropdownButtonFormField.
    int? lyDoDangChon = _dsLyDo.any((ld) => ld.id == kh.lyDoId) ? kh.lyDoId : null;
    final oMoTa = TextEditingController(text: kh.moTaChiTiet);
    // 1 controller/giá trị TƯƠNG ỨNG THEO ĐÚNG THỨ TỰ với _dsTruongTin - dùng
    // Map để dễ tra cứu ngược theo id trường khi lưu.
    final oTruongTin = <int, TextEditingController>{
      for (final tt in _dsTruongTin) tt.id: TextEditingController(text: kh.duLieuTuyChinh['${tt.id}'] ?? ''),
    };

    final luu = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(kh.tenKhachHang, overflow: TextOverflow.ellipsis),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dsLyDo.isNotEmpty)
                  DropdownButtonFormField<int?>(
                    value: lyDoDangChon,
                    decoration: const InputDecoration(labelText: 'Lý do'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('-- Chọn lý do --')),
                      ..._dsLyDo.map((ld) => DropdownMenuItem<int?>(value: ld.id, child: Text(ld.lyDo, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setDialogState(() => lyDoDangChon = v),
                  ),
                const SizedBox(height: 10),
                TextField(controller: oMoTa, decoration: const InputDecoration(labelText: 'Mô tả chi tiết'), maxLines: 3),
                ..._dsTruongTin.map((tt) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _oTruongTuyChinh(tt, oTruongTin[tt.id]!, dialogContext, setDialogState),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );

    if (luu != true || !mounted) return;

    // Kiểm tra các trường BẮT BUỘC (do Admin thiết đặt) trước khi gửi lên -
    // tránh gọi API thừa nếu chắc chắn sẽ thiếu dữ liệu, phản hồi nhanh hơn.
    for (final tt in _dsTruongTin) {
      if (tt.batBuoc && (oTruongTin[tt.id]?.text.trim().isEmpty ?? true)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ "${tt.tenTruong}" là trường bắt buộc, vui lòng nhập đầy đủ.')));
        return;
      }
    }

    final duLieuTuyChinh = <String, String>{
      for (final tt in _dsTruongTin) '${tt.id}': oTruongTin[tt.id]!.text.trim(),
    };

    final loi = await KhaoSatService.luuKetQua(
      dotId: widget.dotId,
      khachHangId: kh.id,
      lyDoId: lyDoDangChon,
      moTaChiTiet: oMoTa.text.trim(),
      duLieuTuyChinh: duLieuTuyChinh,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi == null ? '✅ Đã lưu khảo sát.' : '❌ $loi')));
    if (loi == null) _taiDuLieu();
  }

  /// Vẽ đúng loại ô nhập theo `loaiTruong` do Admin đã thiết đặt cho đợt
  /// khảo sát này - KHÔNG cố định, mỗi đợt có thể có bộ trường khác nhau.
  Widget _oTruongTuyChinh(KhaoSatTruongTin tt, TextEditingController oCtrl, BuildContext dialogContext, void Function(void Function()) setDialogState) {
    final nhan = tt.tenTruong + (tt.batBuoc ? ' *' : '');
    switch (tt.loaiTruong) {
      case 'textarea':
        return TextField(controller: oCtrl, decoration: InputDecoration(labelText: nhan), maxLines: 3);
      case 'number':
        return TextField(controller: oCtrl, decoration: InputDecoration(labelText: nhan), keyboardType: TextInputType.number);
      case 'date':
        return TextField(
          controller: oCtrl,
          readOnly: true,
          decoration: InputDecoration(labelText: nhan, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          onTap: () async {
            final ngayBanDau = DateTime.tryParse(oCtrl.text) ?? DateTime.now();
            final ngay = await showDatePicker(
              context: dialogContext,
              initialDate: ngayBanDau,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
            );
            if (ngay != null) {
              setDialogState(() => oCtrl.text = '${ngay.year.toString().padLeft(4, '0')}-${ngay.month.toString().padLeft(2, '0')}-${ngay.day.toString().padLeft(2, '0')}');
            }
          },
        );
      case 'select':
        // Giống nghi vấn ở "Lý do" phía trên - CHỈ gán giá trị hiện có nếu nó
        // THỰC SỰ nằm trong danh sách lựa chọn hiện tại, tránh crash.
        return DropdownButtonFormField<String>(
          value: tt.tuyChon.contains(oCtrl.text) ? oCtrl.text : null,
          decoration: InputDecoration(labelText: nhan),
          items: tt.tuyChon.map((tc) => DropdownMenuItem(value: tc, child: Text(tc, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setDialogState(() => oCtrl.text = v ?? ''),
        );
      default:
        return TextField(controller: oCtrl, decoration: InputDecoration(labelText: nhan));
    }
  }

  /// Xuất Excel khách hàng ĐÃ KHẢO SÁT trong đợt này (đúng bộ lọc CNKD đang
  /// chọn trên app) - dùng CHUNG đúng endpoint đã xây trên web
  /// (khao-sat.php?xuat_excel=1), mở bằng trình duyệt ngoài để tải file về,
  /// giống hệt cơ chế đã dùng cho Bill cước & Thông báo nợ.
  Future<void> _xuatExcel() async {
    final ticket = await AuthService.getWebTicket();
    if (ticket == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tạo được liên kết xuất file, thử lại.')));
      return;
    }
    var duongDan = '/khao-sat.php?dot_id=${widget.dotId}&xuat_excel=1';
    if (_tvvDangChon != null) duongDan += '&tvv=$_tvvDangChon';
    final link = '${AppConfig.urlSessionLogin}?ticket=$ticket&redirect=${Uri.encodeComponent(duongDan)}';
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được trình duyệt.')));
    }
  }
}
