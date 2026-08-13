import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/khach_hang_toa_do.dart';
import '../models/bill_cuoc_khach_hang.dart';
import '../services/toa_do_service.dart';
import '../services/bill_cuoc_service.dart';

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

  @override
  void initState() {
    super.initState();
    _taiKy();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu thập tọa độ khách hàng'),
        backgroundColor: const Color(0xFFEE0033),
        foregroundColor: Colors.white,
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
          if (_dangTai) const LinearProgressIndicator(),
          Expanded(
            child: _dsKhachHang.isEmpty && !_dangTai
                ? const Center(child: Text('Không có khách hàng nào khớp bộ lọc.'))
                : ListView.builder(
                    itemCount: _dsKhachHang.length,
                    itemBuilder: (_, i) {
                      final kh = _dsKhachHang[i];
                      final dangXuLy = _dangLuu.contains(kh.soTb);
                      return ListTile(
                        title: Text(kh.tenKhachHang, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${kh.soTb} · ${kh.tenTvv}${kh.diaChiTbc.isNotEmpty ? '\n${kh.diaChiTbc}' : ''}'),
                        isThreeLine: kh.diaChiTbc.isNotEmpty,
                        leading: CircleAvatar(
                          backgroundColor: kh.coToaDo ? Colors.green.shade100 : Colors.orange.shade100,
                          child: Icon(kh.coToaDo ? Icons.check : Icons.location_off, color: kh.coToaDo ? Colors.green : Colors.orange, size: 18),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (kh.coToaDo)
                              IconButton(icon: const Icon(Icons.directions), tooltip: 'Chỉ đường', onPressed: () => _moChiDuong(kh)),
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
    );
  }
}
