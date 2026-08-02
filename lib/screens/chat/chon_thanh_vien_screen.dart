import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';

/// Màn chọn nhiều thành viên từ danh sách nhân viên - dùng chung cho "Tạo
/// nhóm mới" và "Thêm thành viên vào nhóm đã có". Trả về danh sách ID đã
/// chọn qua Navigator.pop, hoặc null nếu người dùng hủy.
class ChonThanhVienScreen extends StatefulWidget {
  final Set<int> idDaCo; // những ID đã ở trong nhóm rồi - ẨN khỏi danh sách chọn
  final String tieuDe;
  const ChonThanhVienScreen({super.key, this.idDaCo = const {}, this.tieuDe = 'Chọn thành viên'});

  @override
  State<ChonThanhVienScreen> createState() => _ChonThanhVienScreenState();
}

class _ChonThanhVienScreenState extends State<ChonThanhVienScreen> {
  List<ChatLienHe> _tatCa = [];
  bool _dangTai = true;
  final Set<int> _daChon = {};
  final _oTimKiemCtrl = TextEditingController();
  String _tuKhoa = '';

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
    _oTimKiemCtrl.addListener(() => setState(() => _tuKhoa = _oTimKiemCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _oTimKiemCtrl.dispose();
    super.dispose();
  }

  Future<void> _taiDanhSach() async {
    final ds = await ChatService.layDanhSachLienHe();
    if (!mounted) return;
    setState(() {
      _tatCa = ds.where((lh) => !widget.idDaCo.contains(lh.id)).toList();
      _dangTai = false;
    });
  }

  List<ChatLienHe> get _dsHienThi {
    if (_tuKhoa.isEmpty) return _tatCa;
    return _tatCa.where((lh) => lh.name.toLowerCase().contains(_tuKhoa) || lh.email.toLowerCase().contains(_tuKhoa)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_daChon.isEmpty ? widget.tieuDe : '${widget.tieuDe} (${_daChon.length})'),
        actions: [
          TextButton(
            onPressed: _daChon.isEmpty
                ? null
                : () => Navigator.pop(context, _tatCa.where((lh) => _daChon.contains(lh.id)).toList()),
            child: Text('Xong', style: TextStyle(color: _daChon.isEmpty ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _oTimKiemCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Expanded(
            child: _dangTai
                ? const Center(child: CircularProgressIndicator())
                : _dsHienThi.isEmpty
                    ? Center(child: Text('Không có ai để chọn.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        itemCount: _dsHienThi.length,
                        itemBuilder: (context, i) {
                          final lh = _dsHienThi[i];
                          final dangChon = _daChon.contains(lh.id);
                          return CheckboxListTile(
                            value: dangChon,
                            onChanged: (_) => setState(() => dangChon ? _daChon.remove(lh.id) : _daChon.add(lh.id)),
                            title: Text(lh.name),
                            subtitle: Text(lh.email, style: const TextStyle(fontSize: 12)),
                            secondary: const CircleAvatar(child: Icon(Icons.person)),
                            activeColor: AppTheme.viettelRed,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
