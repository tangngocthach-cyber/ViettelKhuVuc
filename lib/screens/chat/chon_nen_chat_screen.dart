import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat_background.dart';
import '../../theme.dart';

/// Màn chọn nền chat - lưới 20 mẫu (gradient màu tươi sáng), lưu lựa chọn
/// RIÊNG cho từng cuộc trò chuyện (SharedPreferences, chỉ trên máy - không
/// đồng bộ lên server, đúng tính chất "tùy chỉnh cá nhân").
class ChonNenChatScreen extends StatefulWidget {
  final int conversationId;
  const ChonNenChatScreen({super.key, required this.conversationId});

  @override
  State<ChonNenChatScreen> createState() => _ChonNenChatScreenState();
}

class _ChonNenChatScreenState extends State<ChonNenChatScreen> {
  String _idDangChon = ChatBackground.macDinh.id;

  String get _khoaLuu => 'nen_chat_${widget.conversationId}';

  @override
  void initState() {
    super.initState();
    _taiLuaChonDaLuu();
  }

  Future<void> _taiLuaChonDaLuu() async {
    final prefs = await SharedPreferences.getInstance();
    final idDaLuu = prefs.getString(_khoaLuu);
    if (idDaLuu != null && mounted) setState(() => _idDangChon = idDaLuu);
  }

  Future<void> _chonNen(ChatBackground nen) async {
    setState(() => _idDangChon = nen.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_khoaLuu, nen.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã đổi nền: ${nen.ten}'), duration: const Duration(seconds: 1)));
      // Trả về true để màn Chat tự áp dụng lại nền ngay, không cần thoát vào lại
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn nền chat')),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
        itemCount: ChatBackground.tatCa.length,
        itemBuilder: (context, i) {
          final nen = ChatBackground.tatCa[i];
          final dangChon = _idDangChon == nen.id;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _chonNen(nen),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dangChon ? AppTheme.viettelRed : Colors.transparent, width: 3),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: LinearGradient(colors: nen.mauSac, begin: nen.batDau, end: nen.ketThuc)),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(20)),
                        child: Text(nen.ten, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  if (dangChon)
                    const Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, color: AppTheme.viettelRed, size: 22)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
