import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/catalog_service.dart';
import '../../theme.dart';
import 'chat_detail_screen.dart';
import 'tao_nhom_chat_screen.dart';
import '../webview_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatConversation> _dsHoiThoai = [];
  bool _dangTai = true;
  List<dynamic> _dsTinTuc = [];

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
    _taiTinTuc();
  }

  /// Tin tức mới nhất - hiện cố định đầu màn Chat để mọi người luôn thấy
  /// tin mới đăng trên web, không cần chủ động vào mục Tin tức riêng.
  /// Hiện CACHE trước cho nhanh (không chờ mạng), rồi đồng bộ mới nhất ngầm
  /// phía sau và tự cập nhật lại UI khi xong.
  Future<void> _taiTinTuc() async {
    final cache = await CatalogService.getCached('news');
    if (mounted && cache.isNotEmpty) setState(() => _dsTinTuc = cache);
    final moiNhat = await CatalogService.sync('news');
    if (mounted && moiNhat.isNotEmpty) setState(() => _dsTinTuc = moiNhat);
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ds = await ChatService.getConversations();
    if (!mounted) return;
    setState(() {
      _dsHoiThoai = ds;
      _dangTai = false;
    });
  }

  Future<void> _moTaoNhom() async {
    final convId = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const TaoNhomChatScreen()));
    if (convId == null) return;
    await _taiDuLieu();
    if (!mounted) return;
    // Tạo xong -> mở thẳng vào nhóm mới luôn, đỡ phải tự tìm trong danh sách
    final nhomMoiTao = _dsHoiThoai.where((c) => c.id == convId);
    if (nhomMoiTao.isNotEmpty) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: nhomMoiTao.first)));
      _taiDuLieu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat nội bộ')),
      body: Column(
        children: [
          _bangTinTucCoDinh(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _taiDuLieu();
                await _taiTinTuc();
              },
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.viettelRed,
        tooltip: 'Tạo nhóm mới',
        onPressed: _moTaoNhom,
        child: const Icon(Icons.group_add, color: Colors.white),
      ),
    );
  }

  /// Banner tin tức mới nhất - cố định phía trên, KHÔNG cuộn theo danh sách
  /// hội thoại, để mọi người luôn thấy được tin mới đăng trên web.
  Widget _bangTinTucCoDinh() {
    if (_dsTinTuc.isEmpty) return const SizedBox.shrink();
    final tinMoiNhat = _dsTinTuc.first;
    final tieuDe = _layTruongTinTuc(tinMoiNhat, ['title', 'tieu_de', 'ten', 'name']) ?? 'Tin tức mới';
    return Material(
      color: Colors.amber.shade50,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const WebViewScreen(url: AppConfig.urlTinTuc, title: 'Tin tức')));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.amber.shade200))),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tieuDe, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Đọc 1 trường từ dữ liệu tin tức - thử LẦN LƯỢT nhiều tên trường khả dĩ
  /// (server có thể đặt tên khác nhau tùy module) để tránh lỗi khi tên
  /// trường không khớp đúng 100% như dự đoán.
  String? _layTruongTinTuc(dynamic item, List<String> tenTruongKhaDi) {
    if (item is! Map) return null;
    for (final ten in tenTruongKhaDi) {
      final giaTri = item[ten];
      if (giaTri != null && giaTri.toString().trim().isNotEmpty) return giaTri.toString();
    }
    return null;
  }

  String _dinhDangGio(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) return DateFormat('HH:mm').format(t);
    return DateFormat('dd/MM').format(t);
  }
}
