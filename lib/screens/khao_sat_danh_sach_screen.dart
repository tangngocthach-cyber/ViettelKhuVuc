import 'package:flutter/material.dart';
import '../models/khao_sat.dart';
import '../services/khao_sat_service.dart';
import '../theme.dart';
import 'khao_sat_chi_tiet_screen.dart';

/// Màn hình 1 - danh sách các đợt khảo sát đang mở mà CNKD được cấp quyền
/// tham gia. Bấm vào 1 đợt để xem danh sách khách hàng và bắt đầu khảo sát.
class KhaoSatDanhSachScreen extends StatefulWidget {
  const KhaoSatDanhSachScreen({super.key});

  @override
  State<KhaoSatDanhSachScreen> createState() => _KhaoSatDanhSachScreenState();
}

class _KhaoSatDanhSachScreenState extends State<KhaoSatDanhSachScreen> {
  bool _dangTai = true;
  List<KhaoSatDot> _ds = [];
  String? _loi;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ketQua = await KhaoSatService.layDanhSachDot();
    if (!mounted) return;
    setState(() {
      _ds = ketQua.ds;
      _loi = ketQua.loi;
      _dangTai = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khảo sát lý do khách hàng')),
      body: RefreshIndicator(
        onRefresh: _taiDuLieu,
        child: _dangTai
            ? const Center(child: CircularProgressIndicator())
            : _loi != null
                ? _khungLoi()
                : _ds.isEmpty
                    ? _khungRong()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _ds.length,
                        itemBuilder: (context, i) => _theDot(_ds[i]),
                      ),
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

  Widget _khungRong() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.grey),
        SizedBox(height: 12),
        Center(child: Text('Hiện chưa có đợt khảo sát nào đang mở.', style: TextStyle(color: Colors.grey))),
      ],
    );
  }

  Widget _theDot(KhaoSatDot dot) {
    final tienDo = dot.soKhach > 0 ? dot.soDaKhaoSat / dot.soKhach : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KhaoSatChiTietScreen(dotId: dot.id, tenDot: dot.tenKhaoSat))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dot.tenKhaoSat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              if (dot.moTa.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(dot.moTa, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: tienDo, minHeight: 6, backgroundColor: Colors.grey.shade200, color: AppTheme.viettelRed),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${dot.soDaKhaoSat}/${dot.soKhach}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
