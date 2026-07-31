import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatConversation> _dsHoiThoai = [];
  bool _dangTai = true;
  String? _userIdHienTai;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final user = await AuthService.getCurrentUser();
    final ds = await ChatService.getConversations();
    if (!mounted) return;
    setState(() {
      _userIdHienTai = user['id'];
      _dsHoiThoai = ds;
      _dangTai = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat nội bộ')),
      body: RefreshIndicator(
        onRefresh: _taiDuLieu,
        color: AppTheme.viettelRed,
        child: _dangTai
            ? const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed))
            : _dsHoiThoai.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey)),
                      SizedBox(height: 12),
                      Center(child: Text('Chưa có cuộc trò chuyện nào.\nLiên hệ Admin để được thêm vào nhóm.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _dsHoiThoai.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, i) {
                      final c = _dsHoiThoai[i];
                      final coTinChuaDoc = c.soTinChuaDoc > 0;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.viettelRed.withValues(alpha: .12),
                          backgroundImage: c.anhDaiDien != null && c.anhDaiDien!.isNotEmpty
                              ? NetworkImage('${AppConfig.baseUrl}${c.anhDaiDien}')
                              : null,
                          child: (c.anhDaiDien == null || c.anhDaiDien!.isEmpty)
                              ? Icon(c.loai == 'nhom' ? Icons.groups : Icons.person, color: AppTheme.viettelRed)
                              : null,
                        ),
                        title: Text(c.ten, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          c.lastMessagePreview != null
                              ? '${c.lastMessageSender != null ? "${c.lastMessageSender}: " : ""}${c.lastMessagePreview}'
                              : 'Chưa có tin nhắn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: coTinChuaDoc ? Colors.black87 : Colors.grey, fontWeight: coTinChuaDoc ? FontWeight.w600 : FontWeight.normal),
                        ),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (c.lastMessageTime != null)
                              Text(_dinhDangGio(c.lastMessageTime!), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                            const SizedBox(height: 6),
                            if (coTinChuaDoc)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: AppTheme.viettelRed, borderRadius: BorderRadius.circular(10)),
                                child: Text('${c.soTinChuaDoc}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: c)));
                          _taiDuLieu(); // Cập nhật lại số tin chưa đọc sau khi quay lại
                        },
                      );
                    },
                  ),
      ),
    );
  }

  String _dinhDangGio(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat('HH:mm').format(t);
    return DateFormat('dd/MM').format(t);
  }
}
