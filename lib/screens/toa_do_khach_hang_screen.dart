import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/khach_hang_toa_do.dart';
import '../models/bill_cuoc_khach_hang.dart';
import '../services/toa_do_service.dart';
import '../services/bill_cuoc_service.dart';
import '../services/auth_service.dart';

/// Màn hình NATIVE thu thập tọa độ khách hàng bằng GPS thật của máy - nhanh
/// hơn thao tác trên bản đồ web (chỉ cần đứng tại nhà khách, bấm 1 nút).
/// Toàn bộ tọa độ thu thập ở đây SẼ HIỆN NGAY trên "Bản đồ số khách hàng"
/// (dùng chung 1 nguồn dữ liệu, khớp theo Số TB).
class ToaDoKhachHangScreen extends StatefulWidget {
  const ToaDoKhachHangScreen({super.key});

  @override
  State<ToaDoKhachHangScreen> createState() => _ToaDoKhachHangScreenState();
}

class _ToaDoKhachHangScreenState extends State<ToaDoKhachHangScreen> {
  List<BillCuocKy> _dsKy = [];
  List<BillCuocTvv> _dsTvv = [];
  List<KhachHangToaDo> _dsKhachHang = [];
  int? _kyIdDangChon;
  String? _tvvDangChon;
  bool _chiHienChuaCoToaDo = true;
  bool _dangTai = false;
  final _oTimKiem = TextEditingController();
  final Set<String> _dangLuu = {}; // so_tb đang trong lúc lấy GPS/lưu - tránh bấm trùng

  // CHỌN NHIỀU - gán CHUNG 1 tọa độ cho nhiều tài khoản cùng lúc (VD 1 khách
  // hàng có nhiều dịch vụ/số TB khác nhau nhưng cùng 1 địa chỉ nhà thật -
  // KHÔNG cần lấy GPS lại từng cái, chỉ cần lấy 1 lần rồi áp dụng cho cả
  // nhóm). Hệ thống KHÔNG hề chặn nhiều Số TB trùng tọa độ ở tầng dữ liệu -
  // đây chỉ là thao tác NHANH để làm việc đó hàng loạt thay vì làm tay từng
  // khách một.
  bool _cheDoChonNhieu = false;
  final Set<String> _soTbDaChon = {};
  bool _dangGanChung = false;
  int _idNguoiDungHienTai = 0; // để biết tọa độ nào do CHÍNH MÌNH tạo - chỉ những cái đó mới được xóa

  @override
  void initState() {
    super.initState();
    _taiKy();
    _taiIdNguoiDung();
  }

  Future<void> _taiIdNguoiDung() async {
    final u = await AuthService.getCurrentUser();
    if (mounted) setState(() => _idNguoiDungHienTai = int.tryParse(u['id'] ?? '0') ?? 0);
  }

  @override
  void dispose() {
    _oTimKiem.dispose();
    super.dispose();
  }

  Future<void> _taiKy() async {
    setState(() => _dangTai = true);
    final ky = await BillCuocService.layDanhSachKy();
    setState(() {
      _dsKy = ky;
      _kyIdDangChon = ky.isNotEmpty ? ky.first.id : null;
    });
    if (_kyIdDangChon != null) await _taiDanhSach();
    setState(() => _dangTai = false);
  }

  Future<void> _taiDanhSach() async {
    if (_kyIdDangChon == null) return;
    setState(() => _dangTai = true);
    final ketQua = await ToaDoService.layDanhSach(
      kyId: _kyIdDangChon!,
      tvv: _tvvDangChon,
      tuKhoa: _oTimKiem.text.trim(),
      chuaCoToaDo: _chiHienChuaCoToaDo,
    );
    if (!mounted) return;
    setState(() {
      _dsKhachHang = ketQua.khachHang;
      if (ketQua.tvv.isNotEmpty) _dsTvv = ketQua.tvv;
      _dangTai = false;
    });
    if (ketQua.loi != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ketQua.loi!)));
    }
  }

  /// Xin quyền vị trí LÚC CHẠY (giống hệt cách đã áp dụng đúng cho Bluetooth
  /// máy in) rồi lấy GPS thật, lưu ngay cho khách hàng này.
  Future<void> _layGpsVaLuu(KhachHangToaDo kh) async {
    if (_dangLuu.contains(kh.soTb)) return;
    setState(() => _dangLuu.add(kh.soTb));
    try {
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Chưa cấp quyền Vị trí cho app.'),
            action: SnackBarAction(label: 'Mở Cài đặt', onPressed: openAppSettings),
          ));
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng bật định vị (GPS) trên máy.')));
        return;
      }
      final viTri = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final loi = await ToaDoService.luuToaDo(soTb: kh.soTb, lat: viTri.latitude, lng: viTri.longitude);
      if (!mounted) return;
      if (loi == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Đã lưu vị trí cho ${kh.tenKhachHang}.')));
        _taiDanhSach();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $loi')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Không lấy được vị trí: $e')));
    } finally {
      if (mounted) setState(() => _dangLuu.remove(kh.soTb));
    }
  }

  Future<void> _moChiDuong(KhachHangToaDo kh) async {
    if (!kh.coToaDo) return;
    final uri = Uri.parse('https://www.google.com/maps?q=${kh.lat},${kh.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Xóa tọa độ - server đã tự kiểm tra chỉ cho xóa cái CHÍNH MÌNH tạo, nút
  /// này chỉ hiện khi app cũng đoán trước là được phép (kh.nguoiCapNhatId ==
  /// _idNguoiDungHienTai), tránh hiện nút rồi bị từ chối gây khó chịu.
  Future<void> _xoaToaDo(KhachHangToaDo kh) async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa tọa độ?'),
        content: Text('Xóa tọa độ của "${kh.tenKhachHang}"? Không thể hoàn tác (vẫn xem lại được trong lịch sử nếu cần).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    setState(() => _dangLuu.add(kh.soTb));
    final loi = await ToaDoService.xoaToaDo(kh.soTb);
    if (!mounted) return;
    setState(() => _dangLuu.remove(kh.soTb));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi == null ? '✅ Đã xóa tọa độ.' : '❌ $loi')));
    if (loi == null) _taiDanhSach();
  }

  /// Gán CHUNG 1 tọa độ (lat, lng) cho toàn bộ Số TB đang được chọn - dùng
  /// khi 1 khách hàng có nhiều dịch vụ/tài khoản khác nhau nhưng thực tế
  /// chung 1 địa chỉ nhà - lấy GPS 1 lần rồi áp dụng hàng loạt.
  Future<void> _ganChungToaDo(double lat, double lng, String nguon) async {
    setState(() => _dangGanChung = true);
    var thanhCong = 0;
    final loi = <String>[];
    for (final soTb in _soTbDaChon) {
      final ketQua = await ToaDoService.luuToaDo(soTb: soTb, lat: lat, lng: lng, nguon: nguon);
      if (ketQua == null) {
        thanhCong++;
      } else {
        loi.add(soTb);
      }
    }
    if (!mounted) return;
    setState(() {
      _dangGanChung = false;
      _cheDoChonNhieu = false;
      _soTbDaChon.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi.isEmpty
        ? '✅ Đã gán tọa độ cho $thanhCong tài khoản.'
        : '⚠️ Gán được $thanhCong, lỗi ${loi.length} tài khoản (${loi.join(", ")}).')));
    _taiDanhSach();
  }

  /// Hộp thoại chọn NGUỒN tọa độ để gán chung cho nhóm đã chọn - hoặc lấy
  /// GPS ngay lúc này (đứng tại nhà khách), hoặc sao chép lại tọa độ của 1
  /// khách KHÁC đã có sẵn tọa độ (VD 1 trong số các tài khoản của cùng hộ
  /// gia đình đã từng đo trước đó).
  Future<void> _hoiNguonToaDoChoNhom() async {
    if (_soTbDaChon.isEmpty) return;
    final chon = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.my_location, color: Color(0xFFEE0033)),
            title: const Text('Dùng vị trí hiện tại (đứng tại nhà khách)'),
            onTap: () => Navigator.pop(context, 'gps'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_all),
            title: const Text('Sao chép từ 1 khách đã có tọa độ'),
            onTap: () => Navigator.pop(context, 'sao_chep'),
          ),
        ]),
      ),
    );
    if (chon == null || !mounted) return;

    if (chon == 'gps') {
      try {
        var quyen = await Geolocator.checkPermission();
        if (quyen == LocationPermission.denied) quyen = await Geolocator.requestPermission();
        if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa cấp quyền Vị trí cho app.')));
          return;
        }
        final viTri = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
        await _ganChungToaDo(viTri.latitude, viTri.longitude, 'gps_thuc_te');
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Không lấy được vị trí: $e')));
      }
      return;
    }

    // sao_chep - chọn 1 khách nguồn trong số khách ĐÃ CÓ tọa độ
    final dsCoToaDo = _dsKhachHang.where((k) => k.coToaDo).toList();
    if (dsCoToaDo.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có khách nào trong danh sách có sẵn tọa độ để sao chép.')));
      return;
    }
    if (!mounted) return;
    final khNguon = await showDialog<KhachHangToaDo>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Chọn khách để sao chép tọa độ'),
        children: dsCoToaDo.map((kh) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, kh),
          child: Text('${kh.tenKhachHang} (${kh.soTb})'),
        )).toList(),
      ),
    );
    if (khNguon == null || khNguon.lat == null || khNguon.lng == null) return;
    await _ganChungToaDo(khNguon.lat!, khNguon.lng!, 'nhap_tay');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_cheDoChonNhieu ? 'Đã chọn ${_soTbDaChon.length} khách' : 'Thu thập tọa độ khách hàng'),
        backgroundColor: const Color(0xFFEE0033),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_cheDoChonNhieu ? Icons.close : Icons.checklist),
            tooltip: _cheDoChonNhieu ? 'Thoát chế độ chọn nhiều' : 'Chọn nhiều để gán chung tọa độ',
            onPressed: () => setState(() {
              _cheDoChonNhieu = !_cheDoChonNhieu;
              if (!_cheDoChonNhieu) _soTbDaChon.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _kyIdDangChon,
                      decoration: const InputDecoration(labelText: 'Kỳ cước', isDense: true, border: OutlineInputBorder()),
                      items: _dsKy.map((k) => DropdownMenuItem(value: k.id, child: Text(k.tenKy))).toList(),
                      onChanged: (v) { setState(() { _kyIdDangChon = v; _tvvDangChon = null; }); _taiDanhSach(); },
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
                      onChanged: (v) { setState(() => _tvvDangChon = v); _taiDanhSach(); },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _oTimKiem,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên khách hàng, số thuê bao...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _oTimKiem.clear(); _taiDanhSach(); }),
                  ),
                  onSubmitted: (_) => _taiDanhSach(),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Checkbox(
                    value: _chiHienChuaCoToaDo,
                    onChanged: (v) { setState(() => _chiHienChuaCoToaDo = v ?? true); _taiDanhSach(); },
                  ),
                  const Expanded(child: Text('Chỉ hiện khách CHƯA có tọa độ (ưu tiên đi thu thập)', style: TextStyle(fontSize: 12.5))),
                ]),
              ],
            ),
          ),
          if (_dangTai || _dangGanChung) const LinearProgressIndicator(),
          Expanded(
            child: _dsKhachHang.isEmpty && !_dangTai
                ? const Center(child: Text('Không có khách hàng nào khớp bộ lọc.'))
                : ListView.builder(
                    itemCount: _dsKhachHang.length,
                    itemBuilder: (_, i) {
                      final kh = _dsKhachHang[i];
                      final dangXuLy = _dangLuu.contains(kh.soTb);
                      final daChon = _soTbDaChon.contains(kh.soTb);
                      return ListTile(
                        title: Text(kh.tenKhachHang, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${kh.soTb} · ${kh.tenTvv}${kh.diaChiTbc.isNotEmpty ? '\n${kh.diaChiTbc}' : ''}'
                            '${kh.coLyDoChuaThu ? '\nChưa thu - ${kh.tenLyDoChuaThu ?? "lý do khác"}' : ''}'),
                        subtitleTextStyle: kh.coLyDoChuaThu ? const TextStyle(color: Color(0xFFB8860B)) : null,
                        isThreeLine: kh.diaChiTbc.isNotEmpty || kh.coLyDoChuaThu,
                        onTap: _cheDoChonNhieu
                            ? () => setState(() => daChon ? _soTbDaChon.remove(kh.soTb) : _soTbDaChon.add(kh.soTb))
                            : null,
                        leading: _cheDoChonNhieu
                            ? Checkbox(
                                value: daChon,
                                onChanged: (v) => setState(() => (v ?? false) ? _soTbDaChon.add(kh.soTb) : _soTbDaChon.remove(kh.soTb)),
                              )
                            : CircleAvatar(
                                backgroundColor: kh.coToaDo ? Colors.green.shade100 : Colors.orange.shade100,
                                child: Icon(kh.coToaDo ? Icons.check : Icons.location_off, color: kh.coToaDo ? Colors.green : Colors.orange, size: 18),
                              ),
                        trailing: _cheDoChonNhieu
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (kh.coToaDo)
                                    IconButton(icon: const Icon(Icons.directions), tooltip: 'Chỉ đường', onPressed: () => _moChiDuong(kh)),
                                  if (kh.coToaDo && _idNguoiDungHienTai > 0 && kh.nguoiCapNhatId == _idNguoiDungHienTai)
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Xóa tọa độ (do bạn tạo)', onPressed: () => _xoaToaDo(kh)),
                                  dangXuLy
                                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                                      : IconButton(
                                          icon: Icon(Icons.my_location, color: kh.coToaDo ? Colors.grey : const Color(0xFFEE0033)),
                                          tooltip: kh.coToaDo ? 'Cập nhật lại vị trí (đứng tại nhà khách)' : 'Lấy vị trí hiện tại (đứng tại nhà khách)',
                                          onPressed: () => _layGpsVaLuu(kh),
                                        ),
                                ],
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: (_cheDoChonNhieu && _soTbDaChon.isNotEmpty)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFEE0033),
              icon: const Icon(Icons.push_pin),
              label: Text('Gán chung tọa độ cho ${_soTbDaChon.length} khách'),
              onPressed: _dangGanChung ? null : _hoiNguonToaDoChoNhom,
            )
          : null,
    );
  }
}
