import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models/bill_cuoc_khach_hang.dart';
import '../services/auth_service.dart';
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
  bool? _daThuDangChon; // null = tất cả, true = đã thu, false = chưa thu
  int _trangHienTai = 1;
  int _tongSoTrang = 1;
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
    // Chỉ hỏi quyền đã được cấp hay chưa (KHÔNG chủ động hiện hộp thoại xin
    // quyền ngay lúc mở app - dễ gây khó chịu) - nếu chưa có quyền thì bỏ
    // qua tự kết nối, CNKD tự bấm "Kết nối" (lúc đó mới xin quyền) khi cần.
    final coQuyenKetNoi = await Permission.bluetoothConnect.status;
    final coQuyenQuet = await Permission.bluetoothScan.status;
    if (!coQuyenKetNoi.isGranted || !coQuyenQuet.isGranted) return;
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

  Future<void> _timKhachHang({int trang = 1}) async {
    if (_kyIdDangChon == null) return;
    setState(() => _dangTai = true);
    final ketQua = await BillCuocService.timKhachHang(
      kyId: _kyIdDangChon!,
      tvv: _tvvDangChon,
      tuKhoa: _oTimKiem.text.trim(),
      daThu: _daThuDangChon,
      trang: trang,
    );
    setState(() {
      _dsKhachHang = ketQua.khachHang;
      _dsTvv = ketQua.tvv;
      _trangHienTai = ketQua.trang;
      _tongSoTrang = ketQua.tongSoTrang;
      _dangTai = false;
    });
    // Hiện rõ lỗi thật nếu có - TRƯỚC ĐÂY lỗi bị "nuốt" âm thầm, hiện ra
    // như "không tìm thấy khách hàng" gây hiểu nhầm (lỗi thật đã gặp).
    if (ketQua.loi != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ ${ketQua.loi}'), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 6)),
      );
    }
  }

  Future<void> _moTrangInNgoai(String hanhDong, {String? xuat}) async {
    if (_idDaChon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất 1 khách hàng.')));
      return;
    }
    setState(() => _dangMoTrinhDuyet = true);
    final link = await BillCuocService.taoLinkInNgoai(hanhDong: hanhDong, kyId: _kyIdDangChon!, khIds: _idDaChon.toList(), xuat: xuat);
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

  /// Hiện lựa chọn XUẤT PDF hay ẢNH JPG rõ ràng - theo đúng phản ánh "chưa
  /// thấy" (2 nút này trước đây ẩn bên trong trang web, phải tự tìm) - giờ
  /// chọn ngay trong app, trang web mở ra sẽ TỰ ĐỘNG chạy đúng chức năng.
  void _chonKieuXuat(String hanhDong, String tenLoai) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          Padding(padding: const EdgeInsets.all(14), child: Text('Xuất $tenLoai', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('Xuất / In file PDF'),
            subtitle: const Text('Mở Chrome, tự bật hộp thoại in - chọn "Lưu thành PDF"'),
            onTap: () { Navigator.pop(context); _moTrangInNgoai(hanhDong, xuat: 'pdf'); },
          ),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.blue),
            title: const Text('Xuất file ảnh JPG'),
            subtitle: const Text('Mở Chrome, tự tải về ảnh JPG từng trang'),
            onTap: () { Navigator.pop(context); _moTrangInNgoai(hanhDong, xuat: 'jpg'); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ============================================================================
  // IN NHIỆT 58MM - Bluetooth CỔ ĐIỂN (Classic/SPP) NGAY TRONG APP, không cần
  // mở trình duyệt ngoài như 2 chức năng trên (đây là phần "native thật sự"
  // theo đúng yêu cầu - kết nối Bluetooth thật, không qua WebView).
  // ============================================================================
  /// Xin quyền Bluetooth LÚC CHẠY (runtime permission) - từ Android 12 (API
  /// 31) trở lên, dù đã khai báo BLUETOOTH_CONNECT/BLUETOOTH_SCAN trong
  /// AndroidManifest.xml, hệ điều hành VẪN bắt xin quyền lúc chạy giống hệt
  /// camera/vị trí. THIẾU BƯỚC NÀY khiến `connect()` bị hệ điều hành âm
  /// thầm chặn, luôn trả về false - hiện ra như "Kết nối thất bại" dù mọi
  /// thứ khác đều đúng, KHÔNG liên quan gì tới máy in hay code Bluetooth.
  /// Trả về true nếu đã có đủ quyền, false nếu bị từ chối.
  Future<bool> _xinQuyenBluetooth() async {
    final ketQua = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    final duQuyen = (ketQua[Permission.bluetoothConnect]?.isGranted ?? true) &&
        (ketQua[Permission.bluetoothScan]?.isGranted ?? true);
    if (!duQuyen && mounted) {
      final biTuChoiVinhVien = ketQua.values.any((s) => s.isPermanentlyDenied);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(biTuChoiVinhVien
            ? 'Ứng dụng chưa được cấp quyền Bluetooth. Vào Cài đặt máy > Ứng dụng > Viettel Khu Vực Vĩnh Hưng > Quyền, bật quyền Bluetooth rồi thử lại.'
            : 'Cần cấp quyền Bluetooth để kết nối máy in.'),
        action: biTuChoiVinhVien ? SnackBarAction(label: 'Mở Cài đặt', onPressed: openAppSettings) : null,
      ));
    }
    return duQuyen;
  }

  Future<void> _chonMayIn() async {
    if (!await _xinQuyenBluetooth()) return;
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

  /// ĐÃ CÓ BẰNG CHỨNG THẬT (ảnh hóa đơn in ra từ web bị lỗi phông) - máy in
  /// này KHÔNG hỗ trợ UTF-8, in ra ký tự loạn hoàn toàn không đọc được.
  /// Quay lại BỎ DẤU TIẾNG VIỆT trước khi in - đồng bộ đúng với bản web đã
  /// sửa (trước đó bản app và web bị LỆCH NHAU - app vẫn giữ UTF-8 trong khi
  /// web đã đổi - đây là lỗi thật khiến app "vẫn lỗi font" dù web đã sửa).
  String _boDauTiengVietChoMayIn(String s) {
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

  /// LOGO VIETTEL THẬT (đúng file logo anh gửi) - nhúng dạng ảnh, dùng
  /// chung với bản web.
  static const String _logoVietTelBase64 =
      "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";

  /// IN BẰNG ẢNH BITMAP - ĐỒNG BỘ ĐÚNG NGUYÊN LÝ VỚI BẢN WEB: tự vẽ toàn bộ
  /// nội dung hóa đơn (chữ + logo thật) thành 1 ảnh trước (dùng công cụ vẽ
  /// riêng của Flutter - dart:ui Canvas - hệ thống chữ của chính Flutter,
  /// LUÔN đúng dấu tiếng Việt, không phụ thuộc bảng mã của máy in nữa),
  /// sau đó chuyển ảnh thành lệnh in dạng điểm ảnh - máy in chỉ "in y hệt
  /// như ảnh", không cần hiểu chữ gì cả. NHỜ VẬY GIỜ GIỮ ĐƯỢC ĐẦY ĐỦ DẤU
  /// TIẾNG VIỆT (không cần bỏ dấu như cách in bằng chữ trước đây nữa).
  Future<Uint8List> _taoAnhBitmapHoaDon(({List<_DongInNhiet> than, List<_DongInNhiet> duoi}) noiDung) async {
    const double rong = 384; // 58mm ở 203dpi - khớp đúng bản web

    // Giải mã logo thật từ base64
    final logoBytes = base64Decode(_logoVietTelBase64);
    final logoCodec = await ui.instantiateImageCodec(logoBytes);
    final logoFrame = await logoCodec.getNextFrame();
    final logoImg = logoFrame.image;
    const double rongLogo = 240;
    final double caoLogo = logoImg.height * (rongLogo / logoImg.width);

    final dsDong = [...noiDung.than, _DongInNhiet(''), ...noiDung.duoi];

    // Đo trước layout (giống hệt cách bản web đo trước bằng canvas tạm)
    final layout = <({String text, double y, double size, FontWeight weight, bool giua})>[];
    double y = caoLogo + 20;
    for (final d in dsDong) {
      final double size = d.dam && d.to ? 24 : (d.to ? 24 : 15);
      final weight = d.dam ? FontWeight.w900 : FontWeight.w400;
      layout.add((text: d.text, y: y + size, size: size, weight: weight, giua: true));
      y += size + 10;
    }
    final double cao = y + 16;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, rong, cao));
    canvas.drawRect(Rect.fromLTWH(0, 0, rong, cao), Paint()..color = Colors.white);
    canvas.drawImageRect(
      logoImg,
      Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
      Rect.fromLTWH((rong - rongLogo) / 2, 10, rongLogo, caoLogo),
      Paint(),
    );

    for (final d in layout) {
      if (d.text.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: d.text, style: TextStyle(color: Colors.black, fontSize: d.size, fontWeight: d.weight)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: rong - 20);
      final dx = (rong - tp.width) / 2;
      tp.paint(canvas, Offset(dx, d.y - d.size));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(rong.toInt(), cao.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = byteData!.buffer.asUint8List();

    final rongInt = rong.toInt();
    final caoInt = cao.toInt();
    final wByte = (rongInt + 7) ~/ 8;
    final duLieu = Uint8List(wByte * caoInt);
    for (int yy = 0; yy < caoInt; yy++) {
      for (int xx = 0; xx < rongInt; xx++) {
        final idx = (yy * rongInt + xx) * 4;
        final r = pixels[idx], g = pixels[idx + 1], b = pixels[idx + 2], a = pixels[idx + 3];
        final doSang = (r + g + b) / 3;
        if (a > 128 && doSang < 180) {
          duLieu[yy * wByte + (xx >> 3)] |= (1 << (7 - (xx % 8)));
        }
      }
    }

    // Chuyển thành lệnh ESC/POS dạng điểm ảnh (GS v 0) - chia nhỏ theo đoạn
    final bo = <int>[];
    bo.addAll([0x1B, 0x40]);
    bo.addAll([0x1B, 0x61, 0x01]);
    const caoMoiDoan = 220;
    for (int yBd = 0; yBd < caoInt; yBd += caoMoiDoan) {
      final caoDoan = (caoInt - yBd < caoMoiDoan) ? caoInt - yBd : caoMoiDoan;
      bo.addAll([0x1D, 0x76, 0x30, 0x00, wByte & 0xFF, (wByte >> 8) & 0xFF, caoDoan & 0xFF, (caoDoan >> 8) & 0xFF]);
      for (int yy = yBd; yy < yBd + caoDoan; yy++) {
        for (int xb = 0; xb < wByte; xb++) {
          bo.add(duLieu[yy * wByte + xb]);
        }
      }
    }
    bo.addAll([0x0A, 0x0A, 0x0A]);
    bo.addAll([0x1D, 0x56, 0x00]);
    return Uint8List.fromList(bo);
  }

  List<int> _taoLenhEscPos(({List<_DongInNhiet> than, List<_DongInNhiet> duoi}) noiDung) {
    final bo = <int>[];
    bo.addAll([0x1B, 0x40]); // Reset máy in
    bo.addAll([0x1B, 0x61, 0x01]); // Căn giữa
    void inCacDong(List<_DongInNhiet> dsDong) {
      for (final d in dsDong) {
        if (d.dam) bo.addAll([0x1B, 0x45, 0x01]);
        if (d.to) bo.addAll([0x1D, 0x21, 0x11]);
        bo.addAll(utf8.encode('${_boDauTiengVietChoMayIn(d.text)}\n'));
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Image.memory(base64Decode(_logoVietTelBase64), width: 140),
            const SizedBox(height: 10),
            Text(
              toanBo.map((d) => d.text).join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ]),
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

  /// Đảm bảo kết nối Bluetooth ĐANG THẬT SỰ CÒN SỐNG trước khi gửi lệnh in.
  /// LÝ DO CẦN HÀM NÀY: biến `_mayInDangKetNoi` trong app chỉ ghi nhớ LẦN
  /// KẾT NỐI THÀNH CÔNG GẦN NHẤT, không tự cập nhật khi máy in rớt kết nối
  /// ngầm (hết pin, ra khỏi tầm, tự tắt...) - app vẫn tưởng "đang kết nối"
  /// trong khi thực tế socket đã chết, dẫn tới `writeBytes` âm thầm trả về
  /// false. Gọi `PrintBluetoothThermal.connectionStatus` để hỏi THẲNG hệ
  /// điều hành xem có còn sống không, nếu không thì tự kết nối lại bằng
  /// đúng địa chỉ MAC đã lưu trước khi thử gửi.
  Future<bool> _damBaoConKetNoi() async {
    final conSong = await PrintBluetoothThermal.connectionStatus;
    if (conSong) return true;
    if (_mayInDangKetNoi == null) return false;
    final ketNoiLai = await PrintBluetoothThermal.connect(macPrinterAddress: _mayInDangKetNoi!.macAdress);
    return ketNoiLai;
  }

  Future<void> _inHoaDonNhiet(BillCuocKhachHang kh) async {
    if (_mayInDangKetNoi == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng kết nối máy in trước.')));
      return;
    }
    try {
      final lenh = await _taoAnhBitmapHoaDon(_soanNoiDungHoaDon(kh));

      if (!await _damBaoConKetNoi()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
              '❌ Mất kết nối với máy in "${_mayInDangKetNoi!.name}". Kiểm tra máy in còn bật/còn trong tầm rồi bấm "Đổi máy in" để kết nối lại.')));
        }
        return;
      }

      var ok = await PrintBluetoothThermal.writeBytes(lenh);
      if (!ok) {
        // Gửi lần đầu thất bại dù báo "còn kết nối" - hay gặp khi socket vừa
        // rớt đúng lúc gửi. Tự kết nối lại 1 lần rồi thử gửi lại, thay vì
        // báo lỗi ngay - đỡ CNKD phải tự bấm lại thủ công cho lỗi thoáng qua.
        final ketNoiLai = await PrintBluetoothThermal.connect(macPrinterAddress: _mayInDangKetNoi!.macAdress);
        if (ketNoiLai) {
          await Future.delayed(const Duration(milliseconds: 300));
          ok = await PrintBluetoothThermal.writeBytes(lenh);
        }
      }

      if (ok) await BillCuocService.ghiLogInNhiet(kh.id); // đồng bộ "đã in" với bản web
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok
            ? '✅ Đã gửi lệnh in.'
            : '❌ Gửi lệnh in thất bại sau khi đã thử kết nối lại. Kiểm tra máy in còn giấy/còn pin không.')));
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
          if (_tongSoTrang > 1) _thanhPhanTrang(),
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
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<bool?>(
                value: _daThuDangChon,
                decoration: const InputDecoration(labelText: 'Trạng thái thu', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('-- Tất cả --')),
                  DropdownMenuItem(value: false, child: Text('Chưa thu')),
                  DropdownMenuItem(value: true, child: Text('Đã thu')),
                ],
                onChanged: (v) { setState(() => _daThuDangChon = v); _timKhachHang(); },
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
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text('Bill x${kh.soLanDaInBill}', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
              ),
            if (kh.soLanDaInNhiet > 0)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text('Nhiệt x${kh.soLanDaInNhiet}', style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
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

  Widget _thanhPhanTrang() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.grey.shade100,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _trangHienTai > 1 ? () => _timKhachHang(trang: _trangHienTai - 1) : null,
        ),
        Text('Trang $_trangHienTai / $_tongSoTrang', style: const TextStyle(fontWeight: FontWeight.w600)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _trangHienTai < _tongSoTrang ? () => _timKhachHang(trang: _trangHienTai + 1) : null,
        ),
      ]),
    );
  }

  Widget _thanhHanhDong() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Thông báo cước'),
                onPressed: _dangMoTrinhDuyet ? null : () => _chonKieuXuat('in_bill', 'Thông báo cước'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
                icon: const Icon(Icons.warning_amber, size: 18),
                label: const Text('Thông báo nợ'),
                onPressed: _dangMoTrinhDuyet ? null : () => _chonKieuXuat('in_thongbao', 'Thông báo nợ'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade800),
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text('Xuất Excel danh sách đang lọc'),
              onPressed: _kyIdDangChon == null ? null : _xuatExcel,
            ),
          ),
        ]),
      ),
    );
  }

  /// Xuất Excel TOÀN BỘ danh sách đang lọc (đúng kỳ + CNKD đang chọn trên
  /// app) - mở bằng trình duyệt ngoài để tải file .xls về máy.
  Future<void> _xuatExcel() async {
    final ticket = await AuthService.getWebTicket();
    if (ticket == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tạo được liên kết xuất file, thử lại.')));
      return;
    }
    var duongDan = '/bill-cuoc.php?xuat_toan_bo_excel=1&ky_id=$_kyIdDangChon';
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

class _DongInNhiet {
  final String text;
  final bool dam;
  final bool to;
  _DongInNhiet(this.text, {this.dam = false, this.to = false});
}
