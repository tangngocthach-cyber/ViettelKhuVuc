import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';
import 'chon_thanh_vien_screen.dart';

/// Màn tạo nhóm chat mới - đặt tên nhóm, chọn thành viên, tạo. Người tạo tự
/// động trở thành Trưởng nhóm. Trả về conversation_id nếu tạo thành công (để
/// màn danh sách Chat mở thẳng vào nhóm mới tạo).
class TaoNhomChatScreen extends StatefulWidget {
  const TaoNhomChatScreen({super.key});

  @override
  State<TaoNhomChatScreen> createState() => _TaoNhomChatScreenState();
}

class _TaoNhomChatScreenState extends State<TaoNhomChatScreen> {
  final _tenNhomCtrl = TextEditingController();
  final List<ChatLienHe> _thanhVienDaChon = [];
  bool _dangTao = false;

  @override
  void dispose() {
    _tenNhomCtrl.dispose();
    super.dispose();
  }

  Future<void> _chonThanhVien() async {
    final ket = await Navigator.push<List<ChatLienHe>>(
      context,
      MaterialPageRoute(builder: (_) => ChonThanhVienScreen(idDaCo: _thanhVienDaChon.map((e) => e.id).toSet(), tieuDe: 'Chọn thành viên')),
    );
    if (ket == null) return;
    setState(() => _thanhVienDaChon.addAll(ket));
  }

  Future<void> _taoNhom() async {
    if (_dangTao) return;
    final ten = _tenNhomCtrl.text.trim();
    if (ten.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên nhóm.')));
      return;
    }
    if (_thanhVienDaChon.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất 1 thành viên.')));
      return;
    }
    setState(() => _dangTao = true);
    final convId = await ChatService.taoNhom(tenNhom: ten, thanhVien: _thanhVienDaChon.map((e) => e.id).toList());
    if (!mounted) return;
    if (convId != null) {
      Navigator.pop(context, convId);
    } else {
      setState(() => _dangTao = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo nhóm thất bại, vui lòng thử lại.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo nhóm mới')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _tenNhomCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên nhóm', hintText: 'VD: Nhóm CNKD Vĩnh Hưng', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thành viên (${_thanhVienDaChon.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: _chonThanhVien, icon: const Icon(Icons.person_add, size: 18), label: const Text('Chọn')),
            ],
          ),
          const Divider(),
          if (_thanhVienDaChon.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Chưa chọn thành viên nào.', style: TextStyle(color: Colors.grey.shade600))),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _thanhVienDaChon
                  .map((lh) => Chip(
                        label: Text(lh.name),
                        onDeleted: () => setState(() => _thanhVienDaChon.remove(lh)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _dangTao ? null : _taoNhom,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.viettelRed),
              child: _dangTao
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : const Text('Tạo nhóm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
