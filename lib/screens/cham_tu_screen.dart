import 'package:flutter/material.dart';
import '../config.dart';
import '../models/cham_tu.dart';
import '../services/cham_tu_service.dart';
import '../theme.dart';
import 'webview_screen.dart';

/// Màn Sửa đề xuất Chấm tủ - chọn loại tủ, chấm lại vị trí trên bản đồ (nếu
/// cần), ghi chú. KHÔNG còn tính năng ảnh (đã bỏ theo yêu cầu - Chấm tủ giờ
/// chỉ tập trung vào vị trí + loại tủ, không cần bằng chứng hình ảnh).
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
  final _ghiChuCtrl = TextEditingController();
  final _maTuGocCtrl = TextEditingController();
  bool _dangLuu = false;

  bool get _dangSua => widget.chamTuSua != null;
  bool get _laTu8 => _loaiTuChon == LoaiTu.tu8;

  @override
  void initState() {
    super.initState();
    if (_dangSua) {
      final g = widget.chamTuSua!;
      _loaiTuChon = g.loaiTu;
      _ghiChuCtrl.text = g.ghiChu;
      _maTuGocCtrl.text = g.maTuGoc ?? '';
      _lat = g.latitude;
      _lng = g.longitude;
    }
  }

  @override
  void dispose() {
    _ghiChuCtrl.dispose();
    _maTuGocCtrl.dispose();
    super.dispose();
  }

  /// Mở bản đồ cho người dùng CHẠM CHỌN vị trí trực tiếp - không cần đúng vị
  /// trí khảo sát thực tế ngoài hiện trường.
  Future<void> _moBanDoChonViTri() async {
    final ketQua = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const WebViewScreen(url: AppConfig.urlChonViTriDonGian, title: 'Chọn vị trí trên bản đồ')),
    );
    if (ketQua != null && mounted) {
      setState(() {
        _lat = ketQua['lat'] as double;
        _lng = ketQua['lng'] as double;
      });
    }
  }

  Future<void> _luu() async {
    if (_dangLuu) return;
    if (_loaiTuChon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn loại tủ.')));
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chấm vị trí trên bản đồ.')));
      return;
    }

    setState(() => _dangLuu = true);
    // Mã tủ gốc CHỈ có ý nghĩa với Tủ 8 - chọn Tủ cứng thì luôn gửi rỗng dù
    // trước đó lỡ có gõ gì vào ô đó (tránh dữ liệu rác không đúng ngữ cảnh).
    final maTuGoc = _laTu8 ? _maTuGocCtrl.text.trim() : null;

    final loi = await ChamTuService.suaDeXuat(
      id: widget.chamTuSua!.id,
      loaiTu: _loaiTuChon!,
      latitude: _lat!,
      longitude: _lng!,
      ghiChu: _ghiChuCtrl.text.trim(),
      maTuGoc: maTuGoc,
    );

    if (!mounted) return;
    if (loi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Đã cập nhật đề xuất.'), backgroundColor: Colors.green),
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
      appBar: AppBar(title: const Text('Sửa đề xuất')),
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
            if (_laTu8) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _maTuGocCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mã tủ gốc (tủ cứng đấu nối tới)',
                  hintText: 'VD: TC-VH-015',
                  prefixIcon: Icon(Icons.link, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 22),
            const Text('2. Vị trí trên bản đồ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),
            _theViTri(),
            const SizedBox(height: 22),
            const Text('3. Ghi chú (không bắt buộc)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
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
                    : const Text('Lưu thay đổi', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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
          if (_lat != null && _lng != null)
            Row(children: [
              const Icon(Icons.location_on, color: Colors.green, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text('${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}', style: const TextStyle(fontSize: 13))),
            ])
          else
            Row(children: [
              Icon(Icons.location_off_outlined, color: Colors.grey.shade500, size: 18),
              const SizedBox(width: 6),
              Text('Chưa chấm vị trí nào', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _moBanDoChonViTri,
            icon: const Icon(Icons.map, size: 18),
            label: Text(_lat != null ? 'Chọn lại vị trí' : 'Mở bản đồ chấm vị trí'),
          ),
        ],
      ),
    );
  }
}
