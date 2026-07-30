import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _dangChinhCoChu = false;
  double _coChuHienTai = 15;
  double? _viTriYbatDau;
  final _recorder = AudioRecorder();
  bool _dangGhiAm = false;
  int _giayGhiAm = 0;
  Timer? _timerGhiAm;
  String? _duongDanGhiAm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _khoiTao();
  }

  bool _loiTaiBanDau = false;
  String? _noiDungLoi;

  Future<void> _khoiTao() async {
    setState(() {
      _dangTaiBanDau = true;
      _loiTaiBanDau = false;
      _noiDungLoi = null;
    });
    try {
      final user = await AuthService.getCurrentUser();
      _userIdHienTai = user['id'];
      _laQuanTriChat = await AuthService.isChatAdmin();
      final ds = await ChatService.getMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _tinNhan.clear();
        _tinNhan.addAll(ds);
        _dangTaiBanDau = false;
      });
      _danhDauDaDoc();
      _cuonXuongCuoi();
      // Polling tin nhắn mới mỗi vài giây (đủ dùng cho quy mô nội bộ nhỏ, không
      // cần hạ tầng WebSocket riêng - đơn giản, dễ bảo trì, đúng tinh thần dự án)
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: AppConfig.chatPollSeconds), (_) => _kiemTraTinMoi());
    } catch (e) {
      // QUAN TRỌNG: nếu API lỗi (VD backend chưa cập nhật đủ), KHÔNG được để
      // màn hình xoay vòng mãi mãi - phải báo lỗi rõ ràng + cho thử lại, VÀ
      // hiện NGUYÊN VĂN lỗi thật để người dùng chụp lại gửi đi chẩn đoán được.
      if (!mounted) return;
      setState(() {
        _dangTaiBanDau = false;
        _loiTaiBanDau = true;
        _noiDungLoi = e.toString();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _tinNhanCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    _timerGhiAm?.cancel();
    super.dispose();
  }

  Future<void> _kiemTraTinMoi() async {
    if (_tinNhan.isEmpty) return;
    try {
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
    } catch (e) {
      // Lỗi mạng tạm thời khi polling - bỏ qua, thử lại ở lần polling kế tiếp
      // (KHÔNG được để crash hay dừng hẳn timer chỉ vì 1 lần lỗi thoáng qua).
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

  /// Giữ tay vào nút Gửi (không nhấc lên) rồi kéo lên/xuống để chọn cỡ chữ to/nhỏ
  /// hơn cho CHÍNH tin nhắn sắp gửi - nhả tay ra là gửi luôn với cỡ chữ đã chọn.
  void _batDauGiuNutGui(LongPressStartDetails details) {
    if (_tinNhanCtrl.text.trim().isEmpty) return;
    setState(() {
      _dangChinhCoChu = true;
      _coChuHienTai = 15;
      _viTriYbatDau = details.globalPosition.dy;
    });
  }

  void _keoNutGui(LongPressMoveUpdateDetails details) {
    if (_viTriYbatDau == null) return;
    final chenhLech = _viTriYbatDau! - details.globalPosition.dy; // kéo LÊN = dương = chữ TO hơn
    setState(() => _coChuHienTai = (15 + chenhLech / 4).clamp(10, 40));
  }

  Future<void> _thaNutGui(LongPressEndDetails details) async {
    if (!_dangChinhCoChu) return;
    final coChuGui = _coChuHienTai.round();
    setState(() => _dangChinhCoChu = false);
    if ((_tinNhanCtrl.text.trim().isEmpty)) return;
    setState(() => _dangGui = true);
    final tin = await ChatService.sendMessage(
      conversationId: widget.conversation.id,
      noiDung: _tinNhanCtrl.text,
      replyToMessageId: _dangTraLoi?.id,
      coChu: coChuGui == 15 ? null : coChuGui,
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

  Future<void> _xuLyBinhChon(ChatMessage tin, int optionId) async {
    final ketQua = await ChatService.votePoll(optionId);
    if (ketQua != null && mounted) {
      setState(() => tin.poll?.options = ketQua);
    }
  }

  /// Bắt đầu ghi âm tin nhắn thoại - tự xin quyền micro nếu chưa có
  Future<void> _batDauGhiAm() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần cấp quyền micro để ghi âm.')));
      return;
    }
    final dir = await getTemporaryDirectory();
    _duongDanGhiAm = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _duongDanGhiAm!);
    setState(() {
      _dangGhiAm = true;
      _giayGhiAm = 0;
      _hienEmoji = false;
    });
    _timerGhiAm = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _giayGhiAm++);
      // Tự dừng ở mốc 10 phút (giới hạn cùng phía backend) - tránh ghi âm quá dài
      if (_giayGhiAm >= 600) _guiGhiAm();
    });
  }

  /// Hủy ghi âm - xóa file tạm, không gửi
  Future<void> _huyGhiAm() async {
    _timerGhiAm?.cancel();
    if (await _recorder.isRecording()) await _recorder.stop();
    if (_duongDanGhiAm != null) {
      final f = File(_duongDanGhiAm!);
      if (await f.exists()) await f.delete();
    }
    setState(() {
      _dangGhiAm = false;
      _giayGhiAm = 0;
      _duongDanGhiAm = null;
    });
  }

  /// Dừng ghi âm và gửi luôn
  Future<void> _guiGhiAm() async {
    _timerGhiAm?.cancel();
    final duongDan = await _recorder.stop();
    final thoiLuong = _giayGhiAm;
    setState(() {
      _dangGhiAm = false;
      _giayGhiAm = 0;
    });
    // Ghi âm quá ngắn (dưới 1 giây, thường do bấm nhầm) - hủy luôn, không gửi
    if (duongDan == null || thoiLuong < 1) {
      if (duongDan != null) {
        final f = File(duongDan);
        if (await f.exists()) await f.delete();
      }
      return;
    }
    setState(() => _dangGui = true);
    final tin = await ChatService.sendMessage(
      conversationId: widget.conversation.id,
      filePath: duongDan,
      durationGiay: thoiLuong,
      replyToMessageId: _dangTraLoi?.id,
    );
    if (!mounted) return;
    setState(() {
      _dangGui = false;
      if (tin != null) _tinNhan.add(tin);
      _dangTraLoi = null;
    });
    _cuonXuongCuoi();
  }
  /// ràng nếu người dùng từ chối hoặc tắt GPS (không để treo im lặng).
  Future<void> _chiaSeViTri() async {
    try {
      var quyen = await Geolocator.checkPermission();
      if (quyen == LocationPermission.denied) {
        quyen = await Geolocator.requestPermission();
      }
      if (quyen == LocationPermission.denied || quyen == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần cấp quyền vị trí để dùng tính năng này.')));
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng bật định vị (GPS) trên máy.')));
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang lấy vị trí hiện tại...')));
      final viTri = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final tin = await ChatService.sendLocation(conversationId: widget.conversation.id, lat: viTri.latitude, lng: viTri.longitude);
      if (!mounted) return;
      if (tin != null) {
        setState(() => _tinNhan.add(tin));
        _cuonXuongCuoi();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không gửi được vị trí, thử lại sau.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không lấy được vị trí, kiểm tra lại GPS/mạng.')));
    }
  }

  /// Mở dialog tạo Bình chọn mới - nhập câu hỏi + tối thiểu 2 lựa chọn
  void _moDialogTaoBinhChon() {
    final cauHoiCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];
    bool choPhepChonNhieu = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Tạo bình chọn'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: cauHoiCtrl, decoration: const InputDecoration(labelText: 'Câu hỏi')),
                const SizedBox(height: 12),
                ...optionCtrls.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(controller: e.value, decoration: InputDecoration(labelText: 'Lựa chọn ${e.key + 1}')),
                    )),
                TextButton.icon(
                  onPressed: optionCtrls.length >= 10 ? null : () => setDialogState(() => optionCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm lựa chọn'),
                ),
                Row(
                  children: [
                    Checkbox(value: choPhepChonNhieu, onChanged: (v) => setDialogState(() => choPhepChonNhieu = v ?? false)),
                    const Expanded(child: Text('Cho phép chọn nhiều lựa chọn', style: TextStyle(fontSize: 13))),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final cauHoi = cauHoiCtrl.text.trim();
                final options = optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                if (cauHoi.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Nhập câu hỏi và ít nhất 2 lựa chọn.')));
                  return;
                }
                Navigator.pop(dialogContext);
                final tin = await ChatService.createPoll(conversationId: widget.conversation.id, cauHoi: cauHoi, options: options, choPhepChonNhieu: choPhepChonNhieu);
                if (tin != null && mounted) {
                  setState(() => _tinNhan.add(tin));
                  _cuonXuongCuoi();
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
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
            ListTile(leading: const Icon(Icons.poll, color: AppTheme.viettelRed), title: const Text('Tạo bình chọn'), onTap: () { Navigator.pop(context); _moDialogTaoBinhChon(); }),
            ListTile(leading: const Icon(Icons.location_on, color: AppTheme.viettelRed), title: const Text('Chia sẻ vị trí hiện tại'), onTap: () { Navigator.pop(context); _chiaSeViTri(); }),
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
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: widget.conversation.anhDaiDien != null && widget.conversation.anhDaiDien!.isNotEmpty
                  ? NetworkImage('${AppConfig.baseUrl}${widget.conversation.anhDaiDien}')
                  : null,
              child: (widget.conversation.anhDaiDien == null || widget.conversation.anhDaiDien!.isEmpty)
                  ? Icon(widget.conversation.loai == 'nhom' ? Icons.groups : Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.conversation.ten, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                  if (_dangGoNguoiKhac.isNotEmpty)
                    Text('${_dangGoNguoiKhac.join(", ")} đang nhập...', style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.push_pin_outlined), tooltip: 'Tin nhắn đã ghim', onPressed: _hienTinDaGhim),
          IconButton(icon: const Icon(Icons.search), tooltip: 'Tìm kiếm', onPressed: _moTimKiem),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _dangTaiBanDau
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed))
                    : _loiTaiBanDau
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text('Không tải được tin nhắn.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                  if (_noiDungLoi != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                      child: SelectableText(_noiDungLoi!, style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontFamily: 'monospace')),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  ElevatedButton(onPressed: _khoiTao, child: const Text('Thử lại')),
                                ],
                              ),
                            ),
                          )
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
                                onVotePoll: _xuLyBinhChon,
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
                  child: _dangGhiAm ? _thanhDangGhiAm() : Row(
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
                            setState(() {}); // cập nhật lại hiện nút micro hay nút gửi
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
                          : _tinNhanCtrl.text.trim().isEmpty
                              ? IconButton(icon: const Icon(Icons.mic, color: AppTheme.viettelRed), onPressed: _batDauGhiAm)
                              : GestureDetector(
                                  onLongPressStart: _batDauGiuNutGui,
                                  onLongPressMoveUpdate: _keoNutGui,
                                  onLongPressEnd: _thaNutGui,
                                  child: IconButton(
                                    icon: const Icon(Icons.send, color: AppTheme.viettelRed),
                                    onPressed: () => _guiTinNhan(noiDung: _tinNhanCtrl.text),
                                  ),
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
          // Khung xem trước NỔI, chỉ hiện khi đang giữ-kéo nút Gửi để chỉnh cỡ chữ
          if (_dangChinhCoChu)
            Positioned(
              left: 16, right: 16, bottom: 90,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tinNhanCtrl.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: _coChuHienTai),
                      ),
                      const SizedBox(height: 6),
                      Text('Cỡ chữ: ${_coChuHienTai.round()} · Kéo lên để to hơn, kéo xuống để nhỏ hơn', style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Thanh hiển thị khi đang ghi âm - thay thế thanh soạn tin bình thường
  Widget _thanhDangGhiAm() {
    final phut = _giayGhiAm ~/ 60;
    final giay = _giayGhiAm % 60;
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: _huyGhiAm),
        const SizedBox(width: 4),
        const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
        const SizedBox(width: 8),
        Text('Đang ghi âm... $phut:${giay.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.black54)),
        const Spacer(),
        _dangGui
            ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)))
            : IconButton(
                icon: const CircleAvatar(backgroundColor: AppTheme.viettelRed, child: Icon(Icons.send, color: Colors.white, size: 18)),
                onPressed: _guiGhiAm,
              ),
      ],
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
