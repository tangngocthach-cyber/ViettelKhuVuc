import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bill_cuoc_khach_hang.dart';
import '../services/bill_cuoc_service.dart';

class BillCuocNativeScreen extends StatefulWidget {
  const BillCuocNativeScreen({super.key});

  @override
  State<BillCuocNativeScreen> createState() => _BillCuocNativeScreenState();
}

class _BillCuocNativeScreenState extends State<BillCuocNativeScreen> {
  List<BillCuocKy> _dsKy = [];
  List<BillCuocTvv> _dsTvv = [];
  List<BillCuocKhachHang> _dsKhachHang = [];
  int? _kyIdDangChon;
  String? _tvvDangChon;
  final _oTimKiem = TextEditingController();
  final Set<int> _idDaChon = {};
  bool _dangTai = false;
  bool _dangMoTrinhDuyet = false;
  Timer? _hienGioTimKiem; // trì hoãn tìm kiếm - gõ là tự tìm, không cần bấm Enter

  // ---- Trạng thái máy in nhiệt Bluetooth (Classic Bluetooth/SPP) ----
  List<BluetoothInfo> _dsMayInDaGhepDoi = [];
  BluetoothInfo? _mayInDangKetNoi;
  bool _dangKetNoiMayIn = false;

  static const _khoaMacMayInDaLuu = 'bill_cuoc_mac_may_in_da_luu';
  static const _khoaTenMayInDaLuu = 'bill_cuoc_ten_may_in_da_luu';

  @override
  void initState() {
    super.initState();
    _taiDanhSachKy();
    _tuDongKetNoiLaiMayInDaLuu();
  }

  @override
  void dispose() {
    _oTimKiem.dispose();
    _hienGioTimKiem?.cancel();
    super.dispose();
  }

  /// Tự động kết nối lại máy in đã dùng lần gần nhất (nếu có lưu) - tiện lợi
  /// hơn cho CNKD, không phải ghép nối lại mỗi lần mở app.
  Future<void> _tuDongKetNoiLaiMayInDaLuu() async {
    final prefs = await SharedPreferences.getInstance();
    final macDaLuu = prefs.getString(_khoaMacMayInDaLuu);
    final tenDaLuu = prefs.getString(_khoaTenMayInDaLuu);
    if (macDaLuu == null || tenDaLuu == null) return;
    await _ketNoiMayIn(BluetoothInfo(name: tenDaLuu, macAdress: macDaLuu), luuLaiMacDinh: false);
  }

  Future<void> _taiDanhSachKy() async {
    setState(() => _dangTai = true);
    final ky = await BillCuocService.layDanhSachKy();
    setState(() {
      _dsKy = ky;
      _kyIdDangChon = ky.isNotEmpty ? ky.first.id : null;
      _dangTai = false;
    });
    if (_kyIdDangChon != null) _timKhachHang();
  }

  Future<void> _timKhachHang() async {
    if (_kyIdDangChon == null) return;
    setState(() => _dangTai = true);
    final ketQua = await BillCuocService.timKhachHang(
      kyId: _kyIdDangChon!,
      tvv: _tvvDangChon,
      tuKhoa: _oTimKiem.text.trim(),
    );
    setState(() {
      _dsKhachHang = ketQua.khachHang;
      _dsTvv = ketQua.tvv;
      _dangTai = false;
    });
  }

  Future<void> _moTrangInNgoai(String hanhDong) async {
    if (_idDaChon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất 1 khách hàng.')));
      return;
    }
    setState(() => _dangMoTrinhDuyet = true);
    final link = await BillCuocService.taoLinkInNgoai(hanhDong: hanhDong, kyId: _kyIdDangChon!, khIds: _idDaChon.toList());
    setState(() => _dangMoTrinhDuyet = false);
    if (link == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tạo được liên kết in, vui lòng thử lại.')));
      return;
    }
    // QUAN TRỌNG: mở bằng externalApplication - tức TRÌNH DUYỆT THẬT của máy
    // (Chrome), KHÔNG PHẢI WebView nhúng trong app - vừa tránh đúng loại lỗi
    // WebView hay gặp, vừa để trang có thể dùng Web Bluetooth nếu cần sau này.
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được trình duyệt.')));
    }
  }

  // ============================================================================
  // IN NHIỆT 58MM - Bluetooth CỔ ĐIỂN (Classic/SPP) NGAY TRONG APP, không cần
  // mở trình duyệt ngoài như 2 chức năng trên (đây là phần "native thật sự"
  // theo đúng yêu cầu - kết nối Bluetooth thật, không qua WebView).
  // ============================================================================
  Future<void> _chonMayIn() async {
    final ds = await PrintBluetoothThermal.pairedBluetooths;
    setState(() => _dsMayInDaGhepDoi = ds);
    if (!mounted) return;
    if (ds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chưa có máy in nào được ghép đôi Bluetooth. Vào Cài đặt > Bluetooth của máy để ghép đôi với máy in nhiệt trước.'),
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Chọn máy in đã ghép đôi', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final may in ds)
              ListTile(
                leading: const Icon(Icons.print),
                title: Text(may.name),
                subtitle: Text(may.macAdress),
                onTap: () async {
                  Navigator.pop(context);
                  await _ketNoiMayIn(may);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ketNoiMayIn(BluetoothInfo may, {bool luuLaiMacDinh = true}) async {
    setState(() => _dangKetNoiMayIn = true);
    try {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: may.macAdress);
      setState(() {
        _mayInDangKetNoi = ok ? may : null;
        _dangKetNoiMayIn = false;
      });
      if (ok && luuLaiMacDinh) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_khoaMacMayInDaLuu, may.macAdress);
        await prefs.setString(_khoaTenMayInDaLuu, may.name);
      }
      if (mounted && luuLaiMacDinh) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✅ Đã kết nối: ${may.name}' : '❌ Kết nối thất bại, thử lại.')));
      }
    } catch (e) {
      setState(() => _dangKetNoiMayIn = false);
      // Khi TỰ ĐỘNG kết nối lại lúc mở app mà thất bại (VD máy in đang tắt) -
      // không hiện lỗi làm phiền, chỉ im lặng - CNKD tự bấm "Kết nối" lại khi
      // cần. Chỉ hiện lỗi khi TỰ TAY bấm chọn máy in.
      if (mounted && luuLaiMacDinh) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Lỗi kết nối: $e')));
    }
  }

  String _dinhDangTien(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  /// Thân phiếu chính + phần đuôi xé lưu (theo đúng yêu cầu) - CNKD tự giữ
  /// phần đuôi để ghi chú/gạch nợ khách đã thu, tách bằng đường kẻ đứt.
  ({List<_DongInNhiet> than, List<_DongInNhiet> duoi}) _soanNoiDungHoaDon(BillCuocKhachHang kh) {
    final tongNo = kh.tongCuoc + kh.noTruoc;
    final than = [
      _DongInNhiet('VIETTEL VĨNH HƯNG', dam: true, to: true),
      _DongInNhiet('Hóa đơn cước Viettel'),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('Khách hàng: ${kh.tenKhachHang}'),
      _DongInNhiet('Địa chỉ: ${kh.diaChiTbc}'),
      _DongInNhiet('Số thuê bao: ${kh.soTb}'),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('Nợ trước: ${_dinhDangTien(kh.noTruoc)} đ'),
      _DongInNhiet('Cước kỳ này: ${_dinhDangTien(kh.tongCuoc)} đ'),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('TỔNG THANH TOÁN: ${_dinhDangTien(tongNo)} đ', dam: true, to: true),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('NV địa bàn: ${kh.tenTvv}'),
      _DongInNhiet('SĐT liên hệ: ${kh.soDienThoaiTvv}', dam: true),
      _DongInNhiet('Hotline: 18008119'),
      _DongInNhiet('Cảm ơn Quý khách!'),
    ];
    final duoi = [
      _DongInNhiet('- - - - - - CẮT TẠI ĐÂY - - - - - -'),
      _DongInNhiet('PHIẾU LƯU (CNKD giữ)', dam: true),
      _DongInNhiet(kh.tenKhachHang),
      _DongInNhiet('SĐT: ${kh.soTb}  Tiền: ${_dinhDangTien(tongNo)}đ'),
      _DongInNhiet('Ngày thu: ................  Đã thu: [ ]'),
    ];
    return (than: than, duoi: duoi);
  }

  /// Giữ nguyên dấu tiếng Việt khi in (theo đúng yêu cầu) - mã hóa UTF-8
  /// chuẩn bằng utf8.encode() đầy đủ, KHÔNG lọc bớt byte như trước đây (cách
  /// cũ .where((b) => b < 128) CẮT MẤT ký tự có dấu - đúng lỗi thật đã gặp).
  /// Máy in cần hỗ trợ UTF-8/Unicode - nếu máy in cụ thể vẫn lỗi/ô vuông,
  /// báo lại đúng TÊN/DÒNG MÁY IN để chỉnh đúng bảng mã riêng của máy đó.
  List<int> _taoLenhEscPos(({List<_DongInNhiet> than, List<_DongInNhiet> duoi}) noiDung) {
    final bo = <int>[];
    bo.addAll([0x1B, 0x40]); // Reset máy in
    bo.addAll([0x1B, 0x61, 0x01]); // Căn giữa
    void inCacDong(List<_DongInNhiet> dsDong) {
      for (final d in dsDong) {
        if (d.dam) bo.addAll([0x1B, 0x45, 0x01]);
        if (d.to) bo.addAll([0x1D, 0x21, 0x11]);
        bo.addAll(utf8.encode('${d.text}\n'));
        if (d.to) bo.addAll([0x1D, 0x21, 0x00]);
        if (d.dam) bo.addAll([0x1B, 0x45, 0x00]);
      }
    }
    inCacDong(noiDung.than);
    bo.addAll([0x0A, 0x0A]);
    inCacDong(noiDung.duoi);
    bo.addAll([0x0A, 0x0A, 0x0A]);
    bo.addAll([0x1D, 0x56, 0x00]);
    return bo;
  }

  void _xemTruocHoaDon(BillCuocKhachHang kh) {
    final noiDung = _soanNoiDungHoaDon(kh);
    final toanBo = [...noiDung.than, _DongInNhiet(''), ...noiDung.duoi];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xem trước nội dung in'),
        content: SingleChildScrollView(
          child: Text(
            toanBo.map((d) => d.text).join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          FilledButton(
            onPressed: () { Navigator.pop(context); _inHoaDonNhiet(kh); },
            child: const Text('In ngay'),
          ),
        ],
      ),
    );
  }

  Future<void> _inHoaDonNhiet(BillCuocKhachHang kh) async {
    if (_mayInDangKetNoi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng kết nối máy in trước.')));
      return;
    }
    final lenh = _taoLenhEscPos(_soanNoiDungHoaDon(kh));
    try {
      final ok = await PrintBluetoothThermal.writeBytes(lenh);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✅ Đã gửi lệnh in.' : '❌ Gửi lệnh in thất bại.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Lỗi khi in: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill cước & Thông báo nợ'),
        backgroundColor: const Color(0xFFEE0033),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _khungBoLoc(),
          _khungMayIn(),
          if (_dangTai) const LinearProgressIndicator(),
          Expanded(child: _danhSachKhachHang()),
          _thanhHanhDong(),
        ],
      ),
    );
  }

  Widget _khungBoLoc() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _kyIdDangChon,
                decoration: const InputDecoration(labelText: 'Kỳ cước', isDense: true, border: OutlineInputBorder()),
                items: _dsKy.map((k) => DropdownMenuItem(value: k.id, child: Text(k.tenKy))).toList(),
                onChanged: (v) { setState(() { _kyIdDangChon = v; _tvvDangChon = null; _idDaChon.clear(); }); _timKhachHang(); },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tvvDangChon,
                decoration: const InputDecoration(labelText: 'CNKD', isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- Tất cả --')),
                  ..._dsTvv.map((t) => DropdownMenuItem(value: t.maTvv, child: Text(t.tenTvv.isEmpty ? t.maTvv : t.tenTvv))),
                ],
                onChanged: (v) { setState(() => _tvvDangChon = v); _timKhachHang(); },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _oTimKiem,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên khách hàng, số thuê bao, SĐT...',
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _oTimKiem.clear(); _timKhachHang(); }),
            ),
            onChanged: (_) {
              // Trì hoãn 500ms sau khi gõ xong mới thật sự tìm - tránh gọi API
              // liên tục theo từng ký tự gõ (giật/lag), vẫn cảm giác "tự tìm".
              _hienGioTimKiem?.cancel();
              _hienGioTimKiem = Timer(const Duration(milliseconds: 500), _timKhachHang);
            },
            onSubmitted: (_) => _timKhachHang(),
          ),
        ],
      ),
    );
  }

  Widget _khungMayIn() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(Icons.bluetooth, color: _mayInDangKetNoi != null ? Colors.blue : Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _mayInDangKetNoi != null ? 'Máy in: ${_mayInDangKetNoi!.name}' : 'Chưa kết nối máy in nhiệt',
            style: const TextStyle(fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: _dangKetNoiMayIn ? null : _chonMayIn,
          child: Text(_dangKetNoiMayIn ? 'Đang kết nối...' : (_mayInDangKetNoi != null ? 'Đổi máy in' : 'Kết nối')),
        ),
      ]),
    );
  }

  Widget _danhSachKhachHang() {
    if (_dsKhachHang.isEmpty && !_dangTai) {
      return RefreshIndicator(
        onRefresh: _timKhachHang,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Center(child: Text('Không tìm thấy khách hàng nào.', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _timKhachHang,
      child: ListView.builder(
      itemCount: _dsKhachHang.length,
      itemBuilder: (_, i) {
        final kh = _dsKhachHang[i];
        final daChon = _idDaChon.contains(kh.id);
        return CheckboxListTile(
          value: daChon,
          onChanged: (v) => setState(() { v == true ? _idDaChon.add(kh.id) : _idDaChon.remove(kh.id); }),
          title: Row(children: [
            Expanded(child: Text(kh.tenKhachHang, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (kh.soLanDaInBill > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text('Đã in x${kh.soLanDaInBill}', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
              ),
          ]),
          subtitle: Text('${kh.soTb} · ${kh.tenTvv}\n${_dinhDangTien(kh.tongCuoc)}đ'
              '${kh.noTruoc > 0 ? ' · Nợ trước: ${_dinhDangTien(kh.noTruoc)}đ' : ''}'),
          isThreeLine: true,
          secondary: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.visibility), tooltip: 'Xem trước hóa đơn nhiệt', onPressed: () => _xemTruocHoaDon(kh)),
              IconButton(icon: const Icon(Icons.print), tooltip: 'In nhiệt khách này', onPressed: () => _inHoaDonNhiet(kh)),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _thanhHanhDong() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Thông báo cước'),
              onPressed: _dangMoTrinhDuyet ? null : () => _moTrangInNgoai('in_bill'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
              icon: const Icon(Icons.warning_amber, size: 18),
              label: const Text('Thông báo nợ'),
              onPressed: _dangMoTrinhDuyet ? null : () => _moTrangInNgoai('in_thongbao'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DongInNhiet {
  final String text;
  final bool dam;
  final bool to;
  _DongInNhiet(this.text, {this.dam = false, this.to = false});
}
