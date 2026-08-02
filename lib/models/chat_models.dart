/// Đọc số nguyên AN TOÀN từ JSON - PHP đôi khi trả id dạng chuỗi số (VD "5")
/// thay vì số nguyên thật (5) tùy cấu hình DB/driver, ép kiểu thẳng `j['id']`
/// sẽ CRASH ngay khi gặp trường hợp đó - hàm này chấp nhận cả 2 dạng.
int _docInt(dynamic giaTri, {int macDinh = 0}) {
  if (giaTri is int) return giaTri;
  if (giaTri is num) return giaTri.toInt();
  return int.tryParse('$giaTri') ?? macDinh;
}

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
        id: _docInt(j['id']),
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
        id: _docInt(j['id']),
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

/// Đọc "reactions" AN TOÀN từ JSON - server có thể trả về {} (object, có
/// reaction) HOẶC [] (mảng rỗng, do PHP json_encode mảng rỗng luôn ra dạng
/// mảng) - hàm này chấp nhận cả 2 trường hợp, KHÔNG BAO GIỜ crash app dù
/// server có lỡ trả sai định dạng.
Map<String, int> _docReactions(dynamic giaTri) {
  if (giaTri is Map) return Map<String, int>.from(giaTri);
  return {};
}

class PollOption {
  final int id;
  final String noiDung;
  int soPhieu;
  bool toiDaChon;
  PollOption({required this.id, required this.noiDung, required this.soPhieu, required this.toiDaChon});

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
        id: _docInt(j['id']), noiDung: j['noi_dung'] ?? '', soPhieu: j['so_phieu'] ?? 0, toiDaChon: j['toi_da_chon'] ?? false,
      );
}

class PollData {
  final int pollId;
  final String cauHoi;
  final bool choPhepChonNhieu;
  final bool daKetThuc;
  List<PollOption> options;
  PollData({required this.pollId, required this.cauHoi, required this.choPhepChonNhieu, required this.daKetThuc, required this.options});

  int get tongLuotBinhChon => options.fold(0, (a, o) => a + o.soPhieu);

  factory PollData.fromJson(Map<String, dynamic> j) => PollData(
        pollId: _docInt(j['poll_id']),
        cauHoi: j['cau_hoi'] ?? '',
        choPhepChonNhieu: j['cho_phep_chon_nhieu'] ?? false,
        daKetThuc: j['da_ket_thuc'] ?? false,
        options: (j['options'] as List? ?? []).map((e) => PollOption.fromJson(e)).toList(),
      );
}

class ReminderData {
  final String tieuDe;
  final String? moTa;
  final DateTime thoiGianNhac;
  ReminderData({required this.tieuDe, this.moTa, required this.thoiGianNhac});

  factory ReminderData.fromJson(Map<String, dynamic> j) => ReminderData(
        tieuDe: j['tieu_de'] ?? '',
        moTa: j['mo_ta'],
        thoiGianNhac: DateTime.tryParse(j['thoi_gian_nhac'] ?? '') ?? DateTime.now(),
      );
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
  final int? coChu; // cỡ chữ tùy chỉnh (tính năng giữ nút Gửi để phóng to/thu nhỏ)
  final double? lat;
  final double? lng;
  final int? durationGiay; // thời lượng (giây) cho tin nhắn thoại
  final ReminderData? reminder;
  PollData? poll;
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
    this.coChu,
    this.lat,
    this.lng,
    this.durationGiay,
    this.reminder,
    this.poll,
    this.isPinned = false,
    Map<String, int>? reactions,
    this.reactionCuaToi,
  }) : reactions = reactions ?? {};

  /// Tổng số reaction (mọi loại cộng lại) - dùng để hiện số bên bong bóng
  int get tongSoReaction => reactions.values.fold(0, (a, b) => a + b);

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _docInt(j['id']),
        conversationId: _docInt(j['conversation_id']),
        senderId: _docInt(j['sender_id']),
        senderName: j['sender_name'] ?? '',
        loai: j['loai'] ?? 'text',
        noiDung: j['noi_dung'],
        fileUrl: j['file_url'],
        fileTenGoc: j['file_ten_goc'],
        fileSize: j['file_size'],
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        daThuHoi: j['deleted_at'] != null,
        replyTo: j['reply_to'] != null ? ReplyPreview.fromJson(j['reply_to']) : null,
        coChu: j['co_chu'],
        lat: j['lat'] != null ? double.tryParse('${j['lat']}') : null,
        lng: j['lng'] != null ? double.tryParse('${j['lng']}') : null,
        durationGiay: j['duration_giay'],
        reminder: j['reminder'] != null ? ReminderData.fromJson(j['reminder']) : null,
        poll: j['poll'] != null ? PollData.fromJson(j['poll']) : null,
        isPinned: j['is_pinned'] ?? false,
        reactions: _docReactions(j['reactions']),
        reactionCuaToi: j['reaction_cua_toi'],
      );
}

/// 1 thành viên trong nhóm chat, kèm vai trò (Trưởng nhóm/Phó nhóm/Thành viên).
class ChatGroupMember {
  final int customerId;
  final String name;
  final String email;
  final String vaiTro; // 'truong_nhom' | 'pho_nhom' | 'thanh_vien'
  final DateTime joinedAt;

  ChatGroupMember({required this.customerId, required this.name, required this.email, required this.vaiTro, required this.joinedAt});

  bool get laTruongNhom => vaiTro == 'truong_nhom';
  bool get laPhoNhom => vaiTro == 'pho_nhom';

  String get tenVaiTro {
    switch (vaiTro) {
      case 'truong_nhom':
        return 'Trưởng nhóm';
      case 'pho_nhom':
        return 'Phó nhóm';
      default:
        return 'Thành viên';
    }
  }

  factory ChatGroupMember.fromJson(Map<String, dynamic> j) => ChatGroupMember(
        customerId: _docInt(j['customer_id']),
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        vaiTro: j['vai_tro'] ?? 'thanh_vien',
        joinedAt: DateTime.tryParse(j['joined_at'] ?? '') ?? DateTime.now(),
      );
}

/// 1 liên hệ (nhân viên) - dùng cho màn chọn thành viên khi tạo/thêm vào nhóm.
class ChatLienHe {
  final int id;
  final String name;
  final String email;
  ChatLienHe({required this.id, required this.name, required this.email});

  factory ChatLienHe.fromJson(Map<String, dynamic> j) => ChatLienHe(
        id: _docInt(j['id']),
        name: j['name'] ?? '',
        email: j['email'] ?? '',
      );
}
