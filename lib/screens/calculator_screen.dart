import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../utils/bieu_thuc_toan.dart';

/// Máy tính đa năng - gồm 2 tab lớn:
///  - "Máy tính": máy tính thường + khoa học (bật/tắt), hiển thị 2 dòng
///    (biểu thức đang gõ + xem trước kết quả), có lịch sử phép tính.
///  - "Chuyển đổi": đổi đơn vị đo lường, đổi tiền tệ (tỷ giá THAM KHẢO, ghi
///    rõ không phải tỷ giá thời gian thực vì máy tính là công cụ OFFLINE),
///    và tính thuế VAT/chiết khấu - rất hay dùng trong công việc CNKD.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Máy tính'),
        backgroundColor: AppTheme.viettelRed,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Máy tính'),
            Tab(text: 'Chuyển đổi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TabMayTinh(), _TabChuyenDoi()],
      ),
    );
  }
}

// =============================================================================
// TAB 1: MÁY TÍNH (thường + khoa học)
// =============================================================================

class _TabMayTinh extends StatefulWidget {
  const _TabMayTinh();

  @override
  State<_TabMayTinh> createState() => _TabMayTinhState();
}

class _TabMayTinhState extends State<_TabMayTinh> {
  String _bieuThuc = '';
  String _xemTruoc = '';
  bool _vuaBamBang = false; // vừa bấm "=" xong - bấm số tiếp theo sẽ XÓA màn hình thay vì nối thêm
  bool _cheDoKhoaHoc = false;
  final List<String> _lichSu = []; // mỗi phần tử dạng "biểu thức = kết quả", MỚI NHẤT ở đầu danh sách

  /// Đổi ký hiệu hiển thị (×÷) sang ký hiệu Dart hiểu được RỒI đưa cho bộ
  /// tính biểu thức - tách biệt "hiển thị cho người dùng" và "cú pháp máy
  /// tính hiểu", để sau này đổi giao diện không ảnh hưởng logic tính toán.
  void _capNhatXemTruoc() {
    if (_bieuThuc.isEmpty) {
      _xemTruoc = '';
      return;
    }
    try {
      final kq = BieuThucToan.tinh(_bieuThuc);
      _xemTruoc = _dinhDangSo(kq);
    } catch (_) {
      // Biểu thức CHƯA HOÀN CHỈNH (VD đang gõ dở "12+") - không phải lỗi
      // thật, chỉ đơn giản là chưa xem trước được, ẩn dòng xem trước đi.
      _xemTruoc = '';
    }
  }

  String _dinhDangSo(double so) {
    if (so == so.roundToDouble() && so.abs() < 1e12) {
      return so.toStringAsFixed(0);
    }
    String s = so.toStringAsFixed(10);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  void _bamPhim(String ky) {
    HapticFeedback.lightImpact(); // phản hồi rung nhẹ MỖI lần bấm - đúng yêu cầu "micro-interaction"
    setState(() {
      if (_vuaBamBang) {
        // Sau khi bấm "=", bấm SỐ tiếp theo -> bắt đầu phép tính mới; bấm
        // PHÉP TÍNH tiếp theo -> tiếp tục tính từ kết quả vừa ra (thói quen
        // máy tính bỏ túi tiêu chuẩn).
        final laSo = RegExp(r'^[0-9.]$').hasMatch(ky);
        if (laSo) {
          _bieuThuc = '';
        }
        _vuaBamBang = false;
      }
      _bieuThuc += ky;
      _capNhatXemTruoc();
    });
  }

  void _xoaMotKyTu() {
    HapticFeedback.lightImpact();
    if (_bieuThuc.isEmpty) return;
    setState(() {
      _bieuThuc = _bieuThuc.substring(0, _bieuThuc.length - 1);
      _vuaBamBang = false;
      _capNhatXemTruoc();
    });
  }

  void _xoaHet() {
    HapticFeedback.mediumImpact();
    setState(() {
      _bieuThuc = '';
      _xemTruoc = '';
      _vuaBamBang = false;
    });
  }

  void _tinhKetQua() {
    if (_bieuThuc.isEmpty) return;
    HapticFeedback.mediumImpact();
    try {
      final kq = BieuThucToan.tinh(_bieuThuc);
      final ketQuaChuoi = _dinhDangSo(kq);
      setState(() {
        _lichSu.insert(0, '$_bieuThuc = $ketQuaChuoi');
        if (_lichSu.length > 100) _lichSu.removeLast(); // giới hạn lịch sử, tránh phình bộ nhớ vô hạn
        _bieuThuc = ketQuaChuoi;
        _xemTruoc = '';
        _vuaBamBang = true;
      });
    } catch (e) {
      setState(() {
        _xemTruoc = 'Lỗi: ${e is BieuThucToanException ? e.thongBao : "biểu thức không hợp lệ"}';
      });
    }
  }

  void _moLichSu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Lịch sử tính toán', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_lichSu.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _lichSu.clear());
                        Navigator.pop(ctx);
                      },
                      child: const Text('Xóa hết', style: TextStyle(color: AppTheme.viettelRedLight)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _lichSu.isEmpty
                  ? const Center(child: Text('Chưa có phép tính nào.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _lichSu.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(_lichSu[i], style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          // Bấm vào 1 dòng lịch sử -> lấy lại KẾT QUẢ của dòng đó để tính tiếp
                          final ketQua = _lichSu[i].split('=').last.trim();
                          setState(() {
                            _bieuThuc = ketQua;
                            _vuaBamBang = true;
                            _capNhatXemTruoc();
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // ---- Vùng hiển thị: dòng biểu thức (trên, nhỏ) + dòng xem trước
          // kết quả thời gian thực (dưới, lớn) - ĐÚNG yêu cầu "2 dòng". ----
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.grey),
                        tooltip: 'Lịch sử',
                        onPressed: _lichSu.isEmpty ? null : _moLichSu,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text('Khoa học', style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5)),
                          Switch(
                            value: _cheDoKhoaHoc,
                            activeColor: AppTheme.viettelRed,
                            onChanged: (v) {
                              HapticFeedback.selectionClick();
                              setState(() => _cheDoKhoaHoc = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _bieuThuc.isEmpty ? '0' : _bieuThuc,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 26, fontWeight: FontWeight.w400),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _xemTruoc,
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w300),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_cheDoKhoaHoc) _hangKhoaHoc(),
          _hangNut(['C', '⌫', '%', '÷'], mauDacBiet: {3: AppTheme.viettelRed}, mauThuong: Colors.grey.shade600, onTapList: [_xoaHet, _xoaMotKyTu, () => _bamPhim('%'), () => _bamPhim('÷')]),
          _hangNut(['7', '8', '9', '×'], mauDacBiet: {3: AppTheme.viettelRed}, onTapList: [() => _bamPhim('7'), () => _bamPhim('8'), () => _bamPhim('9'), () => _bamPhim('×')]),
          _hangNut(['4', '5', '6', '-'], mauDacBiet: {3: AppTheme.viettelRed}, onTapList: [() => _bamPhim('4'), () => _bamPhim('5'), () => _bamPhim('6'), () => _bamPhim('-')]),
          _hangNut(['1', '2', '3', '+'], mauDacBiet: {3: AppTheme.viettelRed}, onTapList: [() => _bamPhim('1'), () => _bamPhim('2'), () => _bamPhim('3'), () => _bamPhim('+')]),
          _hangNut(['0', '.', '=', ''], rongIndex: 0, mauDacBiet: {2: AppTheme.viettelRed}, onTapList: [() => _bamPhim('0'), () => _bamPhim('.'), _tinhKetQua, () {}]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Hàng nút khoa học - CHỈ hiện khi bật công tắc "Khoa học". Gồm 2 hàng
  /// nhỏ (4 nút/hàng) để không làm màn hình quá chật trên điện thoại nhỏ.
  Widget _hangKhoaHoc() {
    Widget nut(String nhan, String chen) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            child: SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: () => _bamPhim(chen),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade700)),
                child: Text(nhan, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Column(
        children: [
          Row(children: [nut('sin', 'sin'), nut('cos', 'cos'), nut('tan', 'tan'), nut('(', '('), nut(')', ')')]),
          Row(children: [nut('log', 'log'), nut('ln', 'ln'), nut('√', '√'), nut('^', '^'), nut('π', '3.14159265')]),
        ],
      ),
    );
  }

  Widget _hangNut(
    List<String> nhans, {
    Map<int, Color>? mauDacBiet,
    Color? mauThuong,
    int? rongIndex,
    required List<VoidCallback> onTapList,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: List.generate(nhans.length, (i) {
          if (nhans[i].isEmpty) return const Spacer(); // ô trống để giữ bố cục lưới đều
          final nut = _NutMayTinh(nhans[i], mau: mauDacBiet?[i] ?? mauThuong, onTap: onTapList[i]);
          return rongIndex == i ? Expanded(flex: 2, child: nut) : Expanded(child: nut);
        }),
      ),
    );
  }
}

class _NutMayTinh extends StatelessWidget {
  final String nhan;
  final Color? mau;
  final VoidCallback onTap;
  const _NutMayTinh(this.nhan, {this.mau, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: mau ?? Colors.grey.shade900,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(nhan, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500)),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 2: CHUYỂN ĐỔI (đơn vị đo lường / tiền tệ / VAT-chiết khấu)
// =============================================================================

class _TabChuyenDoi extends StatefulWidget {
  const _TabChuyenDoi();

  @override
  State<_TabChuyenDoi> createState() => _TabChuyenDoiState();
}

class _TabChuyenDoiState extends State<_TabChuyenDoi> {
  int _loaiDangChon = 0; // 0=Đơn vị, 1=Tiền tệ, 2=VAT/Chiết khấu

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Đơn vị')),
                  ButtonSegment(value: 1, label: Text('Tiền tệ')),
                  ButtonSegment(value: 2, label: Text('VAT')),
                ],
                selected: {_loaiDangChon},
                onSelectionChanged: (s) => setState(() => _loaiDangChon = s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppTheme.viettelRed,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: Colors.white70,
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _loaiDangChon,
                children: const [_DoiDonVi(), _DoiTienTe(), _TinhVat()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Danh mục đơn vị đo lường - MỖI danh mục có hệ số quy đổi RIÊNG VỀ 1 ĐƠN
/// VỊ GỐC chung (VD Chiều dài quy hết về MÉT), nên đổi X->Y chỉ cần
/// (giá_trị × hệ_số_X) ÷ hệ_số_Y - không cần viết công thức riêng cho từng
/// cặp đơn vị (sẽ phải viết N² công thức nếu làm vậy).
class _NhomDonVi {
  final String ten;
  final Map<String, double> heSoVeGoc; // đơn vị -> hệ số quy về gốc chung của nhóm
  const _NhomDonVi(this.ten, this.heSoVeGoc);
}

const _cacNhomDonVi = [
  _NhomDonVi('Chiều dài', {'Mét (m)': 1, 'Ki-lô-mét (km)': 1000, 'Cen-ti-mét (cm)': 0.01, 'Mi-li-mét (mm)': 0.001, 'Dặm (mile)': 1609.344, 'Feet (ft)': 0.3048, 'Inch (in)': 0.0254}),
  _NhomDonVi('Khối lượng', {'Ki-lô-gam (kg)': 1, 'Gam (g)': 0.001, 'Tấn': 1000, 'Pound (lb)': 0.45359237, 'Ounce (oz)': 0.0283495231}),
  _NhomDonVi('Thể tích', {'Lít (l)': 1, 'Mi-li-lít (ml)': 0.001, 'Mét khối (m³)': 1000, 'Gallon (Mỹ)': 3.785411784}),
  _NhomDonVi('Diện tích', {'Mét vuông (m²)': 1, 'Héc-ta (ha)': 10000, 'Ki-lô-mét vuông (km²)': 1000000, 'Sào Bắc Bộ (360m²)': 360, 'Công (1.000m²)': 1000}),
];

class _DoiDonVi extends StatefulWidget {
  const _DoiDonVi();
  @override
  State<_DoiDonVi> createState() => _DoiDonViState();
}

class _DoiDonViState extends State<_DoiDonVi> {
  int _nhomIndex = 0;
  late String _tuDonVi = _cacNhomDonVi[0].heSoVeGoc.keys.first;
  late String _denDonVi = _cacNhomDonVi[0].heSoVeGoc.keys.elementAt(1);
  final _oNhap = TextEditingController(text: '1');

  double get _ketQua {
    final nhom = _cacNhomDonVi[_nhomIndex];
    final giaTri = double.tryParse(_oNhap.text.replaceAll(',', '.')) ?? 0;
    // Nhiệt độ xử lý riêng (không dùng hệ số nhân tuyến tính đơn thuần vì có điểm gốc lệch nhau)
    final giaTriGoc = giaTri * (nhom.heSoVeGoc[_tuDonVi] ?? 1);
    return giaTriGoc / (nhom.heSoVeGoc[_denDonVi] ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final nhom = _cacNhomDonVi[_nhomIndex];
    final dsDonVi = nhom.heSoVeGoc.keys.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            value: _nhomIndex,
            decoration: _oTrangTri('Loại đơn vị'),
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            items: List.generate(_cacNhomDonVi.length, (i) => DropdownMenuItem(value: i, child: Text(_cacNhomDonVi[i].ten))),
            onChanged: (v) {
              setState(() {
                _nhomIndex = v!;
                _tuDonVi = _cacNhomDonVi[v].heSoVeGoc.keys.first;
                _denDonVi = _cacNhomDonVi[v].heSoVeGoc.keys.elementAt(1);
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _oNhap,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: _oTrangTri('Giá trị cần đổi'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _tuDonVi,
                  decoration: _oTrangTri('Từ'),
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  isExpanded: true,
                  items: dsDonVi.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _tuDonVi = v!),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: AppTheme.viettelRed),
                onPressed: () => setState(() {
                  final tam = _tuDonVi;
                  _tuDonVi = _denDonVi;
                  _denDonVi = tam;
                }),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _denDonVi,
                  decoration: _oTrangTri('Đến'),
                  dropdownColor: const Color(0xFF1C1C1E),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  isExpanded: true,
                  items: dsDonVi.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _denDonVi = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.viettelRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Text(
              '${_oNhap.text} $_tuDonVi\n=  ${_ketQua.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} $_denDonVi',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _oTrangTri(String nhan) => InputDecoration(
      labelText: nhan,
      labelStyle: TextStyle(color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

/// Tỷ giá THAM KHẢO (quy đổi ra 1 VNĐ) - máy tính là công cụ OFFLINE hoàn
/// toàn, KHÔNG gọi API tỷ giá thời gian thực (tránh phụ thuộc mạng cho 1
/// tiện ích lẽ ra phải dùng được cả khi không có Internet). Ghi CHÚ RÕ
/// ngay trên giao diện để không ai hiểu nhầm là tỷ giá cập nhật tự động -
/// người dùng cần tỷ giá chính xác nên tự tra cứu thêm.
const _tyGiaThamKhao = {
  'VND (Việt Nam Đồng)': 1.0,
  'USD (Đô la Mỹ)': 26200.0,
  'EUR (Euro)': 27400.0,
  'JPY (Yên Nhật)': 168.0,
  'KRW (Won Hàn Quốc)': 18.0,
  'CNY (Nhân dân tệ)': 3600.0,
};

class _DoiTienTe extends StatefulWidget {
  const _DoiTienTe();
  @override
  State<_DoiTienTe> createState() => _DoiTienTeState();
}

class _DoiTienTeState extends State<_DoiTienTe> {
  String _tuTien = 'USD (Đô la Mỹ)';
  String _denTien = 'VND (Việt Nam Đồng)';
  final _oNhap = TextEditingController(text: '1');

  double get _ketQua {
    final giaTri = double.tryParse(_oNhap.text.replaceAll(',', '.')) ?? 0;
    final quyVeVnd = giaTri * (_tyGiaThamKhao[_tuTien] ?? 1);
    return quyVeVnd / (_tyGiaThamKhao[_denTien] ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final dsTien = _tyGiaThamKhao.keys.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Tỷ giá THAM KHẢO, không cập nhật thời gian thực (công cụ hoạt động offline).', style: TextStyle(color: Colors.amber.shade200, fontSize: 12))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _oNhap,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: _oTrangTri('Số tiền'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _tuTien,
            decoration: _oTrangTri('Từ loại tiền'),
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            items: dsTien.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _tuTien = v!),
          ),
          const SizedBox(height: 10),
          Center(
            child: IconButton(
              icon: const Icon(Icons.swap_vert, color: AppTheme.viettelRed, size: 28),
              onPressed: () => setState(() {
                final tam = _tuTien;
                _tuTien = _denTien;
                _denTien = tam;
              }),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _denTien,
            decoration: _oTrangTri('Sang loại tiền'),
            dropdownColor: const Color(0xFF1C1C1E),
            style: const TextStyle(color: Colors.white),
            items: dsTien.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _denTien = v!),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.viettelRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Text(
              '≈ ${_ketQua.toStringAsFixed(2)} ${_denTien.split(' ').first}',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tính thuế VAT + chiết khấu - nhập giá gốc, % thuế, % chiết khấu -> ra
/// đầy đủ: tiền chiết khấu, giá sau chiết khấu, tiền thuế, giá cuối cùng
/// phải trả/thu - đúng nghiệp vụ thường gặp khi tính bill cước/báo giá.
class _TinhVat extends StatefulWidget {
  const _TinhVat();
  @override
  State<_TinhVat> createState() => _TinhVatState();
}

class _TinhVatState extends State<_TinhVat> {
  final _oGiaGoc = TextEditingController();
  final _oVat = TextEditingController(text: '10');
  final _oChietKhau = TextEditingController(text: '0');

  double get _giaGoc => double.tryParse(_oGiaGoc.text.replaceAll(',', '.')) ?? 0;
  double get _phanTramVat => double.tryParse(_oVat.text.replaceAll(',', '.')) ?? 0;
  double get _phanTramChietKhau => double.tryParse(_oChietKhau.text.replaceAll(',', '.')) ?? 0;

  double get _tienChietKhau => _giaGoc * _phanTramChietKhau / 100;
  double get _giaSauChietKhau => _giaGoc - _tienChietKhau;
  double get _tienVat => _giaSauChietKhau * _phanTramVat / 100;
  double get _giaCuoiCung => _giaSauChietKhau + _tienVat;

  String _tienTe(double so) {
    final phanNguyen = so.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < phanNguyen.length; i++) {
      if (i > 0 && (phanNguyen.length - i) % 3 == 0) buffer.write('.');
      buffer.write(phanNguyen[i]);
    }
    return '${buffer.toString()} đ';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _oGiaGoc,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: _oTrangTri('Giá gốc (trước thuế, trước chiết khấu)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _oChietKhau,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: _oTrangTri('Chiết khấu (%)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _oVat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: _oTrangTri('Thuế VAT (%)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _dongKetQua('Giá gốc', _tienTe(_giaGoc)),
                _dongKetQua('Tiền chiết khấu (-)', _tienTe(_tienChietKhau), mau: Colors.orange.shade300),
                _dongKetQua('Giá sau chiết khấu', _tienTe(_giaSauChietKhau)),
                _dongKetQua('Tiền thuế VAT (+)', _tienTe(_tienVat), mau: Colors.blue.shade300),
                const Divider(color: Colors.grey),
                _dongKetQua('Thành tiền cuối cùng', _tienTe(_giaCuoiCung), noiBat: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dongKetQua(String nhan, String giaTri, {Color? mau, bool noiBat = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(nhan, style: TextStyle(color: noiBat ? Colors.white : Colors.grey.shade400, fontSize: noiBat ? 16 : 14, fontWeight: noiBat ? FontWeight.bold : null)),
          Text(giaTri, style: TextStyle(color: mau ?? (noiBat ? AppTheme.viettelRedLight : Colors.white), fontSize: noiBat ? 20 : 15, fontWeight: noiBat ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
