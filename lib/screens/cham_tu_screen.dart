import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/cham_tu.dart';
import '../services/cham_tu_service.dart';
import '../theme.dart';

/// Màn Chấm tủ - luồng thao tác NGẮN GỌN theo đúng yêu cầu: chọn loại tủ ->
/// chấm vị trí -> chụp ảnh -> Lưu. Mọi thứ còn lại (ID, thời gian, người tạo,
/// địa chỉ...) hệ thống tự xử lý ở phía server, người dùng không cần nhập tay.
///
/// Truyền [chamTuSua] để mở màn ở chế độ SỬA (điền sẵn dữ liệu cũ, ảnh mới
/// không bắt buộc - không chọn ảnh mới thì giữ nguyên ảnh cũ).
class ChamTuScreen extends StatefulWidget {
  final ChamTu? chamTuSua;
  const ChamTuScreen({super.key, this.chamTuSua});

  @override
  State<ChamTuScreen> createState() => _ChamTuScreenState();
}

class _ChamTuScreenState extends State<ChamTuScreen> {
  String? _loaiTuChon;
  double? _lat;
  double? _lng;
  bool _dangLayViTri = false;
  String? _loiViTri;
  File? _anhChon; // ảnh MỚI vừa chụp/chọn (null = chưa đổi ảnh)
  final _ghiChuCtrl = TextEditingController();
  bool _dangLuu = false;

  bool get _dangSua => widget.chamTuSua != null;

  @override
  void initState() {
    super.initState();
    if (_dangSua) {
      // Chế độ SỬA - điền sẵn dữ liệu cũ, KHÔNG tự lấy GPS mới (giữ đúng vị
      // trí đã chấm trước đó, chỉ đổi khi người dùng chủ động bấm lấy lại).
      final g = widget.chamTuSua!;
      _loaiTuChon = g.loaiTu;
      _ghiChuCtrl.text = g.ghiChu;
      _lat = g.latitude;
      _lng = g.longitude;
    } else {
      _layViTri(); // tự động lấy GPS ngay khi mở màn - đỡ phải bấm thêm bước nào
    }
  }

  @override
  void dispose() {
    _ghiChuCtrl.dispose();
    super.dispose();
  }

  Future<void> _layViTri() async {
    setState(() {
      _dangLayViTri = true;
      _loiViTri = null;
    });
    try {
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
        setState(() {
          _dangLayViTri = false;
          _loiViTri = 'Chưa cấp quyền Vị trí cho app. Vào Cài đặt máy để bật.';
        });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _dangLayViTri = false;
          _loiViTri = 'Vui lòng bật định vị (GPS) trên máy.';
        });
        return;
      }
      final viTri = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() {
          _lat = viTri.latitude;
          _lng = viTri.longitude;
          _dangLayViTri = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dangLayViTri = false;
          _loiViTri = 'Không lấy được vị trí, thử lại ở nơi thoáng hơn.';
        });
      }
    }
  }

  Future<void> _chonAnh(ImageSource nguon) async {
    final picker = ImagePicker();
    final anh = await picker.pickImage(source: nguon, imageQuality: 80, maxWidth: 1600);
    if (anh != null) setState(() => _anhChon = File(anh.path));
  }

  void _moChonNguonAnh() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_camera, color: AppTheme.viettelRed), title: const Text('Chụp ảnh'), onTap: () { Navigator.pop(context); _chonAnh(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library, color: AppTheme.viettelRed), title: const Text('Chọn ảnh từ thư viện'), onTap: () { Navigator.pop(context); _chonAnh(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }

  Future<String> _layThongTinThietBi() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;
      return '${android.manufacturer} ${android.model} (Android ${android.version.release})';
    } catch (e) {
      return 'Không xác định';
    }
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (_loaiTuChon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn loại tủ.')));
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có tọa độ GPS - bấm "Lấy lại vị trí" và thử lại.')));
      return;
    }
    // Chế độ TẠO MỚI bắt buộc phải có ảnh - chế độ SỬA thì không bắt buộc
    // (không chọn ảnh mới thì server tự giữ nguyên ảnh cũ).
    if (!_dangSua && _anhChon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chụp hoặc chọn ảnh hiện trạng tủ.')));
      return;
    }

    setState(() => _dangLuu = true);
    String? loi;
    if (_dangSua) {
      loi = await ChamTuService.suaDeXuat(
        id: widget.chamTuSua!.id,
        loaiTu: _loaiTuChon!,
        latitude: _lat!,
        longitude: _lng!,
        anhMoi: _anhChon,
        ghiChu: _ghiChuCtrl.text.trim(),
      );
    } else {
      final thietBi = await _layThongTinThietBi();
      loi = await ChamTuService.taoDeXuat(
        loaiTu: _loaiTuChon!,
        latitude: _lat!,
        longitude: _lng!,
        anh: _anhChon!,
        ghiChu: _ghiChuCtrl.text.trim(),
        thietBi: thietBi,
      );
    }

    if (!mounted) return;
    if (loi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_dangSua ? '✅ Đã cập nhật đề xuất.' : '✅ Đã lưu đề xuất chấm tủ thành công.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _dangLuu = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_dangSua ? 'Sửa đề xuất' : 'Chấm tủ đề xuất')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('1. Chọn loại tủ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _theLoaiTu(LoaiTu.tuCung, Icons.electrical_services)),
                const SizedBox(width: 12),
                Expanded(child: _theLoaiTu(LoaiTu.tu8, Icons.dns)),
              ],
            ),
            const SizedBox(height: 22),
            const Text('2. Vị trí GPS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),
            _theViTri(),
            const SizedBox(height: 22),
            const Text('3. Ảnh hiện trạng', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),
            _theAnh(),
            const SizedBox(height: 22),
            const Text('4. Ghi chú (không bắt buộc)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),
            TextField(
              controller: _ghiChuCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'VD: Tủ cần nâng cấp thêm khay...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _dangLuu ? null : _luu,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.viettelRed),
                child: _dangLuu
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                    : Text(_dangSua ? 'Lưu thay đổi' : 'Lưu đề xuất', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _theLoaiTu(String ma, IconData icon) {
    final dangChon = _loaiTuChon == ma;
    return InkWell(
      onTap: () => setState(() => _loaiTuChon = ma),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: dangChon ? AppTheme.viettelRed : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dangChon ? AppTheme.viettelRed : Colors.grey.shade300, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: dangChon ? Colors.white : Colors.grey.shade700),
            const SizedBox(height: 6),
            Text(LoaiTu.ten(ma), style: TextStyle(color: dangChon ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _theViTri() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_dangLayViTri)
            const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Đang xác định vị trí...')])
          else if (_loiViTri != null)
            Row(children: [const Icon(Icons.error_outline, color: Colors.red, size: 18), const SizedBox(width: 6), Expanded(child: Text(_loiViTri!, style: const TextStyle(color: Colors.red, fontSize: 13)))])
          else if (_lat != null && _lng != null)
            Row(children: [
              const Icon(Icons.my_location, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}', style: const TextStyle(fontSize: 13))),
            ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _dangLayViTri ? null : _layViTri,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Lấy lại vị trí'),
          ),
        ],
      ),
    );
  }

  Widget _theAnh() {
    if (_anhChon == null) {
      // Chế độ SỬA và chưa chọn ảnh mới -> hiện ẢNH CŨ (tải từ server) thay
      // vì khung trống, để người dùng biết ảnh hiện tại đang là ảnh nào.
      if (_dangSua && widget.chamTuSua!.anhUrl.isNotEmpty) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.chamTuSua!.anhUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: double.infinity, height: 200, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: ElevatedButton.icon(
                onPressed: _moChonNguonAnh,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Đổi ảnh'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
              ),
            ),
          ],
        );
      }
      return InkWell(
        onTap: _moChonNguonAnh,
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 36, color: Colors.grey.shade500),
              const SizedBox(height: 8),
              Text('Chụp hoặc chọn ảnh', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_anhChon!, width: double.infinity, height: 200, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => setState(() => _anhChon = null)),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: ElevatedButton.icon(
            onPressed: _moChonNguonAnh,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Đổi ảnh'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
          ),
        ),
      ],
    );
  }
}
