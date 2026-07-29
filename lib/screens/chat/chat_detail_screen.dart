import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../config.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/message_bubble.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatConversation conversation;
  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  final _tinNhanCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _tinNhan = [];
  String? _userIdHienTai;
  Timer? _pollTimer;
  Timer? _typingTimer;
  List<String> _dangGoNguoiKhac = [];
  bool _dangTaiBanDau = true;
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _khoiTao();
  }

  Future<void> _khoiTao() async {
    final user = await AuthService.getCurrentUser();
    _userIdHienTai = user['id'];
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

  Future<void> _guiTinNhan({String? noiDung, String? filePath}) async {
    if ((noiDung == null || noiDung.trim().isEmpty) && filePath == null) return;
    setState(() => _dangGui = true);
    final tin = await ChatService.sendMessage(conversationId: widget.conversation.id, noiDung: noiDung, filePath: filePath);
    if (!mounted) return;
    setState(() {
      _dangGui = false;
      if (tin != null) _tinNhan.add(tin);
      _tinNhanCtrl.clear();
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
                          return MessageBubble(message: tin, laCuaMinh: laCuaMinh, hienThiTen: hienThiTen, daXem: laTinCuoiCuaMinh);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 6, offset: const Offset(0, -2))]),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.viettelRed), onPressed: _hienMenuDinhKem),
                  Expanded(
                    child: TextField(
                      controller: _tinNhanCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
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
        ],
      ),
    );
  }
}
