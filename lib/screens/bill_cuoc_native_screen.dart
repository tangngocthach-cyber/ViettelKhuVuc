import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
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

  // ---- Trạng thái máy in nhiệt Bluetooth (Classic Bluetooth/SPP) ----
  List<BluetoothInfo> _dsMayInDaGhepDoi = [];
  BluetoothInfo? _mayInDangKetNoi;
  bool _dangKetNoiMayIn = false;

  @override
  void initState() {
    super.initState();
    _taiDanhSachKy();
  }

  @override
  void dispose() {
    _oTimKiem.dispose();
    super.dispose();
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

  Future<void> _ketNoiMayIn(BluetoothInfo may) async {
    setState(() => _dangKetNoiMayIn = true);
    try {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: may.macAdress);
      setState(() {
        _mayInDangKetNoi = ok ? may : null;
        _dangKetNoiMayIn = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✅ Đã kết nối: ${may.name}' : '❌ Kết nối thất bại, thử lại.')));
      }
    } catch (e) {
      setState(() => _dangKetNoiMayIn = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Lỗi kết nối: $e')));
    }
  }

  /// Bỏ dấu tiếng Việt - hầu hết máy in nhiệt giá rẻ không có font tiếng Việt
  /// có dấu, giữ dấu sẽ in ra ký tự lỗi/ô vuông (giữ nhất quán với bản Web).
  String _boDauTiengViet(String s) {
    const co = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const khong = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final idx = co.indexOf(ch);
      buf.write(idx >= 0 ? khong[idx] : ch);
    }
    return buf.toString();
  }

  String _dinhDangTien(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  List<_DongInNhiet> _soanNoiDungHoaDon(BillCuocKhachHang kh) {
    final tongNo = kh.tongCuoc + kh.noTruoc;
    return [
      _DongInNhiet('VIETTEL KHU VUC VINH HUNG', dam: true, to: true),
      _DongInNhiet('HOA DON CUOC VIETTEL'),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('Khach hang: ${kh.tenKhachHang}'),
      _DongInNhiet('Dia chi: ${kh.diaChiTbc}'),
      _DongInNhiet('So thue bao: ${kh.soTb}'),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('No truoc: ${_dinhDangTien(kh.noTruoc)} d'),
      _DongInNhiet('Cuoc ky nay: ${_dinhDangTien(kh.tongCuoc)} d'),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('TONG THANH TOAN: ${_dinhDangTien(tongNo)} d', dam: true, to: true),
      _DongInNhiet('------------------------------'),
      _DongInNhiet('NV dia ban: ${kh.tenTvv}'),
      _DongInNhiet('SDT lien he: ${kh.soDienThoaiTvv}', dam: true),
      _DongInNhiet('Hotline: 18008119'),
      _DongInNhiet('Cam on Quy khach!'),
    ];
  }

  List<int> _taoLenhEscPos(List<_DongInNhiet> dong) {
    final bo = <int>[];
    bo.addAll([0x1B, 0x40]); // Reset máy in
    bo.addAll([0x1B, 0x61, 0x01]); // Căn giữa
    for (final d in dong) {
      if (d.dam) bo.addAll([0x1B, 0x45, 0x01]);
      if (d.to) bo.addAll([0x1D, 0x21, 0x11]);
      final text = _boDauTiengViet(d.text) + '\n';
      bo.addAll(utf8.encode(text).where((b) => b < 128)); // an toàn: chỉ giữ byte ASCII
      if (d.to) bo.addAll([0x1D, 0x21, 0x00]);
      if (d.dam) bo.addAll([0x1B, 0x45, 0x00]);
    }
    bo.addAll([0x0A, 0x0A, 0x0A]);
    bo.addAll([0x1D, 0x56, 0x00]);
    return bo;
  }

  void _xemTruocHoaDon(BillCuocKhachHang kh) {
    final dong = _soanNoiDungHoaDon(kh);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xem trước nội dung in'),
        content: SingleChildScrollView(
          child: Text(
            dong.map((d) => _boDauTiengViet(d.text)).join('\n'),
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
      return const Center(child: Text('Không tìm thấy khách hàng nào.'));
    }
    return ListView.builder(
      itemCount: _dsKhachHang.length,
      itemBuilder: (_, i) {
        final kh = _dsKhachHang[i];
        final daChon = _idDaChon.contains(kh.id);
        return CheckboxListTile(
          value: daChon,
          onChanged: (v) => setState(() { v == true ? _idDaChon.add(kh.id) : _idDaChon.remove(kh.id); }),
          title: Text(kh.tenKhachHang, style: const TextStyle(fontWeight: FontWeight.w600)),
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
