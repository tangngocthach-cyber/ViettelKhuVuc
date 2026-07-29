class ChatConversation {
  final int id;
  final String ten;
  final String loai;
  final String? anhDaiDien;
  final String? lastMessagePreview;
  final String? lastMessageSender;
  final DateTime? lastMessageTime;
  final int soTinChuaDoc;
  final int soThanhVien;

  ChatConversation({
    required this.id,
    required this.ten,
    required this.loai,
    this.anhDaiDien,
    this.lastMessagePreview,
    this.lastMessageSender,
    this.lastMessageTime,
    required this.soTinChuaDoc,
    required this.soThanhVien,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
        id: j['id'],
        ten: j['ten'] ?? '',
        loai: j['loai'] ?? 'nhom',
        anhDaiDien: j['anh_dai_dien'],
        lastMessagePreview: j['last_message_preview'],
        lastMessageSender: j['last_message_sender'],
        lastMessageTime: j['last_message_time'] != null ? DateTime.tryParse(j['last_message_time']) : null,
        soTinChuaDoc: j['so_tin_chua_doc'] ?? 0,
        soThanhVien: j['so_thanh_vien'] ?? 0,
      );
}

/// Tóm tắt tin nhắn được trích dẫn (hiển thị khung nhỏ phía trên bong bóng)
class ReplyPreview {
  final int id;
  final String senderName;
  final String noiDung;
  ReplyPreview({required this.id, required this.senderName, required this.noiDung});

  factory ReplyPreview.fromJson(Map<String, dynamic> j) => ReplyPreview(
        id: j['id'],
        senderName: j['sender_name'] ?? '',
        noiDung: j['noi_dung'] ?? '',
      );
}

/// 5 loại reaction hỗ trợ - đồng bộ ĐÚNG với danh sách phía backend (like.php)
class ChatReactions {
  static const Map<String, String> emojiTheoLoai = {
    'thich': '👍',
    'yeu': '❤️',
    'haha': '😆',
    'wow': '😮',
    'buon': '😢',
  };
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String loai; // text | image | file | voice
  final String? noiDung;
  final String? fileUrl;
  final String? fileTenGoc;
  final int? fileSize;
  final DateTime createdAt;
  final bool daThuHoi;
  final ReplyPreview? replyTo;
  bool isPinned;
  Map<String, int> reactions; // {'thich': 2, 'yeu': 1}
  String? reactionCuaToi; // loại reaction của CHÍNH MÌNH, null nếu chưa bấm

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.loai,
    this.noiDung,
    this.fileUrl,
    this.fileTenGoc,
    this.fileSize,
    required this.createdAt,
    this.daThuHoi = false,
    this.replyTo,
    this.isPinned = false,
    Map<String, int>? reactions,
    this.reactionCuaToi,
  }) : reactions = reactions ?? {};

  /// Tổng số reaction (mọi loại cộng lại) - dùng để hiện số bên bong bóng
  int get tongSoReaction => reactions.values.fold(0, (a, b) => a + b);

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'],
        conversationId: j['conversation_id'],
        senderId: j['sender_id'],
        senderName: j['sender_name'] ?? '',
        loai: j['loai'] ?? 'text',
        noiDung: j['noi_dung'],
        fileUrl: j['file_url'],
        fileTenGoc: j['file_ten_goc'],
        fileSize: j['file_size'],
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        daThuHoi: j['deleted_at'] != null,
        replyTo: j['reply_to'] != null ? ReplyPreview.fromJson(j['reply_to']) : null,
        isPinned: j['is_pinned'] ?? false,
        reactions: j['reactions'] != null ? Map<String, int>.from(j['reactions']) : {},
        reactionCuaToi: j['reaction_cua_toi'],
      );
}
