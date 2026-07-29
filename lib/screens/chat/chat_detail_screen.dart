import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import '../../config.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/message_bubble.dart';
import 'chat_search_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;
  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  final _tinNhanCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final List<ChatMessage> _tinNhan = [];
  String? _userIdHienTai;
  bool _laQuanTriChat = false;
  Timer? _pollTimer;
  Timer? _typingTimer;
  List<String> _dangGoNguoiKhac = [];
  bool _dangTaiBanDau = true;
  bool _dangGui = false;
  bool _hienEmoji = false;
  ChatMessage? _dangTraLoi; // tin nhắn đang được trả lời trích dẫn (null = không trả lời)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _khoiTao();
  }

  Future<void> _khoiTao() async {
    final user = await AuthService.getCurrentUser();
    _userIdHienTai = user['id'];
    _laQuanTriChat = await AuthService.isChatAdmin();
    final ds = await ChatService.getMessages(widget.conversation.id);
    if (!mounted) return;
    setState(() {
      _tinNhan.addAll(ds);
      _dangTaiBanDau = false;
    });
    _danhDauDaDoc();
    _cuonXuongCuoi();
    // Polling tin nhắn mới mỗi vài giây (đủ dùng cho quy mô nội bộ nhỏ, không
    // cần hạ tầng WebSocket riêng - đơn giản, dễ bảo trì, đúng tinh thần dự án)
    _pollTimer = Timer.periodic(const Duration(seconds: AppConfig.chatPollSeconds), (_) => _kiemTraTinMoi());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _tinNhanCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _kiemTraTinMoi() async {
    if (_tinNhan.isEmpty) return;
    final idCuoi = _tinNhan.last.id;
    final tinMoi = await ChatService.getMessages(widget.conversation.id, afterId: idCuoi);
    final dangGo = await ChatService.getTypingUsers(widget.conversation.id);
    if (!mounted) return;
    setState(() {
      if (tinMoi.isNotEmpty) _tinNhan.addAll(tinMoi);
      _dangGoNguoiKhac = dangGo;
    });
    if (tinMoi.isNotEmpty) {
      _danhDauDaDoc();
      _cuonXuongCuoi();
    }
  }

  void _danhDauDaDoc() {
    if (_tinNhan.isEmpty) return;
    ChatService.markRead(widget.conversation.id, _tinNhan.last.id);
  }

  void _cuonXuongCuoi() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _baoDangGo() {
    ChatService.sendTyping(widget.conversation.id);
  }

  Future<void> _xuLyReaction(ChatMessage tin, String loaiReaction) async {
    // Cập nhật ngay trên giao diện trước (mượt hơn), rồi gọi API phía sau
    final reactionCu = tin.reactionCuaToi;
    setState(() {
      final soCu = tin.reactions[loaiReaction] ?? 0;
      if (reactionCu == loaiReaction) {
        tin.reactions[loaiReaction] = (soCu - 1).clamp(0, 999999);
        tin.reactionCuaToi = null;
      } else {
        if (reactionCu != null) tin.reactions[reactionCu] = ((tin.reactions[reactionCu] ?? 1) - 1).clamp(0, 999999);
        tin.reactions[loaiReaction] = soCu + 1;
        tin.reactionCuaToi = loaiReaction;
      }
    });
    final ketQua = await ChatService.toggleReaction(tin.id, loaiReaction);
    if (ketQua != null && mounted) {
      setState(() {
        tin.reactionCuaToi = ketQua['reaction_cua_toi'];
        tin.reactions = Map<String, int>.from(ketQua['reactions'] ?? {});
      });
    }
  }

  Future<void> _xuLyThuHoi(ChatMessage tin) async {
    final thanhCong = await ChatService.recallMessage(tin.id);
    if (thanhCong && mounted) {
      setState(() {
        final idx = _tinNhan.indexWhere((t) => t.id == tin.id);
        if (idx != -1) {
          _tinNhan[idx] = ChatMessage(
            id: tin.id, conversationId: tin.conversationId, senderId: tin.senderId, senderName: tin.senderName,
            loai: tin.loai, createdAt: tin.createdAt, daThuHoi: true,
          );
        }
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể thu hồi tin nhắn này.')));
    }
  }

  Future<void> _xuLyGhim(ChatMessage tin) async {
    final ketQua = await ChatService.togglePin(tin.id);
    if (ketQua != null && mounted) {
      setState(() => tin.isPinned = ketQua);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ketQua ? 'Đã ghim tin nhắn.' : 'Đã bỏ ghim tin nhắn.')));
    }
  }

  void _batDauTraLoi(ChatMessage tin) {
    setState(() {
      _dangTraLoi = tin;
      _hienEmoji = false;
    });
    _focusNode.requestFocus();
  }

  Future<void> _guiTinNhan({String? noiDung, String? filePath}) async {
    if ((noiDung == null || noiDung.trim().isEmpty) && filePath == null) return;
    setState(() => _dangGui = true);
    final tin = await ChatService.sendMessage(
      conversationId: widget.conversation.id,
      noiDung: noiDung,
      filePath: filePath,
      replyToMessageId: _dangTraLoi?.id,
    );
    if (!mounted) return;
    setState(() {
      _dangGui = false;
      if (tin != null) _tinNhan.add(tin);
      _tinNhanCtrl.clear();
      _dangTraLoi = null;
    });
    _cuonXuongCuoi();
  }

  Future<void> _chonAnh(ImageSource nguon) async {
    final picker = ImagePicker();
    final anh = await picker.pickImage(source: nguon, imageQuality: 80);
    if (anh != null) await _guiTinNhan(filePath: anh.path);
  }

  Future<void> _chonFile() async {
    final ketQua = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip']);
    if (ketQua != null && ketQua.files.single.path != null) {
      await _guiTinNhan(filePath: ketQua.files.single.path);
    }
  }

  void _hienMenuDinhKem() {
    setState(() => _hienEmoji = false);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo_camera, color: AppTheme.viettelRed), title: const Text('Chụp ảnh'), onTap: () { Navigator.pop(context); _chonAnh(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library, color: AppTheme.viettelRed), title: const Text('Chọn ảnh từ thư viện'), onTap: () { Navigator.pop(context); _chonAnh(ImageSource.gallery); }),
            ListTile(leading: const Icon(Icons.attach_file, color: AppTheme.viettelRed), title: const Text('Tệp đính kèm (docx, xlsx, pdf...)'), onTap: () { Navigator.pop(context); _chonFile(); }),
          ],
        ),
      ),
    );
  }

  void _moTimKiem() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatSearchScreen(conversationId: widget.conversation.id)));
  }

  Future<void> _hienTinDaGhim() async {
    final ds = await ChatService.getPinnedMessages(widget.conversation.id);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .5,
        maxChildSize: .85,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(padding: EdgeInsets.all(12), child: Text('Tin nhắn đã ghim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const Divider(height: 1),
            Expanded(
              child: ds.isEmpty
                  ? const Center(child: Text('Chưa có tin nhắn nào được ghim.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: ds.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final tin = ds[i];
                        final thoiGian = DateTime.tryParse(tin['created_at'] ?? '');
                        return ListTile(
                          leading: const Icon(Icons.push_pin, color: AppTheme.viettelRed),
                          title: Text(tin['sender_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: Text(tin['noi_dung'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: thoiGian != null ? Text(DateFormat('dd/MM HH:mm').format(thoiGian), style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.ten, style: const TextStyle(fontSize: 16)),
            if (_dangGoNguoiKhac.isNotEmpty)
              Text('${_dangGoNguoiKhac.join(", ")} đang nhập...', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.push_pin_outlined), tooltip: 'Tin nhắn đã ghim', onPressed: _hienTinDaGhim),
          IconButton(icon: const Icon(Icons.search), tooltip: 'Tìm kiếm', onPressed: _moTimKiem),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _dangTaiBanDau
                ? const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed))
                : _tinNhan.isEmpty
                    ? const Center(child: Text('Chưa có tin nhắn - gửi lời chào đầu tiên!', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: _tinNhan.length,
                        itemBuilder: (context, i) {
                          final tin = _tinNhan[i];
                          final laCuaMinh = '${tin.senderId}' == _userIdHienTai;
                          final tinTruoc = i > 0 ? _tinNhan[i - 1] : null;
                          final hienThiTen = tinTruoc == null || tinTruoc.senderId != tin.senderId;
                          final laTinCuoiCuaMinh = laCuaMinh && i == _tinNhan.length - 1;
                          return MessageBubble(
                            message: tin,
                            laCuaMinh: laCuaMinh,
                            hienThiTen: hienThiTen,
                            daXem: laTinCuoiCuaMinh,
                            laQuanTriChat: _laQuanTriChat,
                            onReaction: _xuLyReaction,
                            onRecall: _xuLyThuHoi,
                            onPin: _xuLyGhim,
                            onTraLoi: _batDauTraLoi,
                          );
                        },
                      ),
          ),
          if (_dangTraLoi != null) _khungDangTraLoi(),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 6, offset: const Offset(0, -2))]),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.viettelRed), onPressed: _hienMenuDinhKem),
                  IconButton(
                    icon: Icon(_hienEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppTheme.viettelRed),
                    onPressed: () {
                      setState(() => _hienEmoji = !_hienEmoji);
                      if (_hienEmoji) { FocusScope.of(context).unfocus(); } else { _focusNode.requestFocus(); }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _tinNhanCtrl,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onTap: () { if (_hienEmoji) setState(() => _hienEmoji = false); },
                      onChanged: (_) {
                        _typingTimer?.cancel();
                        _typingTimer = Timer(const Duration(milliseconds: 400), _baoDangGo);
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: const Color(0xFFF1F1F1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _dangGui
                      ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
                      : IconButton(
                          icon: const Icon(Icons.send, color: AppTheme.viettelRed),
                          onPressed: () => _guiTinNhan(noiDung: _tinNhanCtrl.text),
                        ),
                ],
              ),
            ),
          ),
          Offstage(
            offstage: !_hienEmoji,
            child: SizedBox(
              height: 260,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _tinNhanCtrl.text += emoji.emoji;
                  _tinNhanCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _tinNhanCtrl.text.length));
                },
                config: const Config(
                  emojiViewConfig: EmojiViewConfig(columns: 8, emojiSizeMax: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Khung nhỏ hiện phía trên ô soạn tin khi đang trả lời trích dẫn 1 tin cụ thể
  Widget _khungDangTraLoi() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, border: const Border(top: BorderSide(color: Color(0xFFE0E0E0)))),
      child: Row(
        children: [
          Container(width: 3, height: 32, color: AppTheme.viettelRed),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Trả lời ${_dangTraLoi!.senderName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.viettelRed)),
                Text(
                  _dangTraLoi!.loai == 'image' ? '[Hình ảnh]' : (_dangTraLoi!.loai == 'file' ? '[Tệp đính kèm]' : (_dangTraLoi!.noiDung ?? '')),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _dangTraLoi = null)),
        ],
      ),
    );
  }
}
