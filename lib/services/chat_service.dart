import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import '../models/chat_models.dart';
import 'auth_service.dart';

class ChatService {
  static Future<Map<String, String>> _authHeader() async {
    final token = await AuthService.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  static Future<File> _fileCacheHoiThoai() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/cache_chat_conversations.json');
  }

  static Future<List<ChatConversation>> getConversations() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.apiChatConversations), headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return await _docCacheHoiThoai();
      final danhSachTho = data['data'] as List;
      // Lưu lại NGUYÊN DỮ LIỆU THÔ (chưa parse) - để lần sau mất mạng vẫn đọc
      // lại được đúng y hệt, không phụ thuộc việc ChatConversation có hàm
      // toJson() hay không (hiện tại chưa có, tránh phải thêm để giảm rủi ro
      // sai sót không cần thiết).
      try {
        await (await _fileCacheHoiThoai()).writeAsString(jsonEncode(danhSachTho));
      } catch (e) {
        // Ghi cache lỗi (VD hết dung lượng máy) không quan trọng, bỏ qua
      }
      return danhSachTho.map((e) => ChatConversation.fromJson(e)).toList();
    } catch (e) {
      // Mất mạng/server lỗi/timeout: thử đọc cache CŨ thay vì trả rỗng luôn -
      // để tab Chat vẫn hiện được danh sách hội thoại gần nhất lúc offline.
      return await _docCacheHoiThoai();
    }
  }

  static Future<List<ChatConversation>> _docCacheHoiThoai() async {
    try {
      final file = await _fileCacheHoiThoai();
      if (!await file.exists()) return [];
      final danhSachTho = jsonDecode(await file.readAsString()) as List;
      return danhSachTho.map((e) => ChatConversation.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// [afterId]: lấy tin MỚI HƠN id này (dùng để polling liên tục).
  /// [beforeId]: lấy tin CŨ HƠN id này (dùng để cuộn lên xem lịch sử).
  static Future<List<ChatMessage>> getMessages(int conversationId, {int afterId = 0, int beforeId = 0}) async {
    final params = {'conversation_id': '$conversationId'};
    if (afterId > 0) params['after_id'] = '$afterId';
    if (beforeId > 0) params['before_id'] = '$beforeId';
    final uri = Uri.parse(AppConfig.apiChatMessages).replace(queryParameters: params);
    final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (e) {
      // Server KHÔNG trả về JSON hợp lệ (thường do PHP in lỗi/cảnh báo ra trước
      // JSON) - ném lỗi kèm NGUYÊN VĂN nội dung thật server trả về (rút gọn
      // 300 ký tự đầu) để hiện thị cho người dùng thấy, thay vì im lặng ẩn đi.
      throw Exception('Server trả về dữ liệu không hợp lệ (mã ${res.statusCode}):\n${res.body.length > 300 ? res.body.substring(0, 300) : res.body}');
    }
    if (data['success'] != true) {
      throw Exception('Lỗi API (mã ${res.statusCode}): ${data['message'] ?? 'không rõ nguyên nhân'}');
    }
    return (data['data'] as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  /// Gửi tin nhắn text. [filePath] khác null thì gửi kèm ảnh/file (dùng
  /// multipart) - 1 API DUY NHẤT xử lý cả 3 loại (đúng thiết kế backend).
  /// [replyToMessageId] khác null -> gửi kèm trả lời trích dẫn 1 tin cụ thể.
  static Future<ChatMessage?> sendMessage({
    required int conversationId,
    String? noiDung,
    String? filePath,
    int? replyToMessageId,
    int? coChu,
    int? durationGiay,
  }) async {
    final token = await AuthService.getToken();
    final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiChatSend));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['conversation_id'] = '$conversationId';
    if (noiDung != null && noiDung.isNotEmpty) request.fields['noi_dung'] = noiDung;
    if (replyToMessageId != null) request.fields['reply_to_message_id'] = '$replyToMessageId';
    if (coChu != null) request.fields['co_chu'] = '$coChu';
    if (durationGiay != null) request.fields['duration_giay'] = '$durationGiay';
    if (filePath != null) request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return ChatMessage.fromJson(data['message']);
  }

  static Future<void> markRead(int conversationId, int messageId) async {
    await http.post(
      Uri.parse(AppConfig.apiChatMarkRead),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'message_id': messageId}),
    ).timeout(const Duration(seconds: 15));
  }

  static Future<void> sendTyping(int conversationId) async {
    await http.post(
      Uri.parse(AppConfig.apiChatTyping),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId}),
    ).timeout(const Duration(seconds: 15));
  }

  static Future<List<String>> getTypingUsers(int conversationId) async {
    final uri = Uri.parse(AppConfig.apiChatTyping).replace(queryParameters: {'conversation_id': '$conversationId'});
    final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return [];
    return List<String>.from(data['dang_nhap'] ?? []);
  }

  /// Bấm 1 trong 5 loại Reaction (thich/yeu/haha/wow/buon) - bấm lại đúng loại
  /// đang có sẽ TỰ BỎ (toggle), bấm loại khác sẽ ĐỔI sang loại đó.
  static Future<Map<String, dynamic>?> toggleReaction(int messageId, String loaiReaction) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatLike),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId, 'loai_reaction': loaiReaction}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return {
      'reaction_cua_toi': data['reaction_cua_toi'],
      'reactions': data['reactions'] is Map ? Map<String, int>.from(data['reactions']) : <String, int>{},
    };
  }

  /// Thu hồi/xóa tin nhắn - chủ tin nhắn thu hồi của mình, hoặc Quản trị Chat
  /// xóa đơn phương tin của bất kỳ ai.
  static Future<bool> recallMessage(int messageId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatRecall),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  /// Ghim/Bỏ ghim tin nhắn quan trọng (toggle) - trả về trạng thái ghim mới nhất
  static Future<bool?> togglePin(int messageId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatPin),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return data['is_pinned'] as bool;
  }

  /// Lấy danh sách tin nhắn đã ghim trong 1 cuộc trò chuyện
  static Future<List<Map<String, dynamic>>> getPinnedMessages(int conversationId) async {
    try {
      final uri = Uri.parse(AppConfig.apiChatPinnedList).replace(queryParameters: {'conversation_id': '$conversationId'});
      final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Tìm kiếm trong lịch sử chat của 1 cuộc trò chuyện (chỉ tin nhắn văn bản)
  static Future<List<Map<String, dynamic>>> searchMessages(int conversationId, String tuKhoa) async {
    try {
      final uri = Uri.parse(AppConfig.apiChatSearch).replace(queryParameters: {'conversation_id': '$conversationId', 'q': tuKhoa});
      final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      // Mất mạng/timeout: trả rỗng, tránh treo màn hình tìm kiếm vĩnh viễn
      return [];
    }
  }

  /// Tạo 1 cuộc Bình chọn mới trong cuộc trò chuyện
  static Future<ChatMessage?> createPoll({
    required int conversationId,
    required String cauHoi,
    required List<String> options,
    bool choPhepChonNhieu = false,
  }) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatPollCreate),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'cau_hoi': cauHoi, 'options': options, 'cho_phep_chon_nhieu': choPhepChonNhieu}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return ChatMessage.fromJson(data['message']);
  }

  /// Bấm chọn/bỏ chọn 1 lựa chọn trong Bình chọn - trả về danh sách lựa chọn mới nhất
  static Future<List<PollOption>?> votePoll(int optionId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatPollVote),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'option_id': optionId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return (data['options'] as List).map((e) => PollOption.fromJson(e)).toList();
  }

  /// Gửi vị trí hiện tại
  static Future<ChatMessage?> sendLocation({required int conversationId, required double lat, required double lng}) async {
    final token = await AuthService.getToken();
    final res = await http.post(
      Uri.parse(AppConfig.apiChatSend),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'conversation_id': '$conversationId', 'lat': '$lat', 'lng': '$lng'},
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return ChatMessage.fromJson(data['message']);
  }

  /// Chuyển tiếp 1 tin nhắn sang cuộc trò chuyện khác
  static Future<bool> forwardMessage({required int messageId, required int targetConversationId}) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatForward),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId, 'target_conversation_id': targetConversationId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  /// Tạo 1 nhắc hẹn mới trong cuộc trò chuyện
  static Future<ChatMessage?> createReminder({
    required int conversationId,
    required String tieuDe,
    String? moTa,
    required DateTime thoiGianNhac,
  }) async {
    final gioChuoi = '${thoiGianNhac.year.toString().padLeft(4, '0')}-${thoiGianNhac.month.toString().padLeft(2, '0')}-${thoiGianNhac.day.toString().padLeft(2, '0')} '
        '${thoiGianNhac.hour.toString().padLeft(2, '0')}:${thoiGianNhac.minute.toString().padLeft(2, '0')}:00';
    final res = await http.post(
      Uri.parse(AppConfig.apiChatReminderCreate),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'tieu_de': tieuDe, 'mo_ta': moTa, 'thoi_gian_nhac': gioChuoi}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return ChatMessage.fromJson(data['message']);
  }

  // ============================================================================
  // QUẢN LÝ NHÓM CHAT - tạo nhóm, thêm/xóa thành viên, bầu Trưởng/Phó nhóm,
  // đổi thông tin nhóm, giải tán nhóm - trước đây CHỈ làm được qua web Admin.
  // ============================================================================

  /// Tạo nhóm chat mới - trả về conversation_id nếu thành công, null nếu lỗi
  /// (kèm lý do trong [loi] nếu truyền vào).
  static Future<int?> taoNhom({required String tenNhom, required List<int> thanhVien}) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatTaoNhom),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'ten_nhom': tenNhom, 'thanh_vien': thanhVien}),
    ).timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return int.tryParse('${data['conversation_id']}');
  }

  static Future<String?> themThanhVien({required int conversationId, required List<int> thanhVien}) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatThemThanhVien),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'thanh_vien': thanhVien}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] == true) return null;
    return data['message']?.toString() ?? 'Thêm thành viên thất bại.';
  }

  static Future<String?> xoaThanhVien({required int conversationId, required int customerId}) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatXoaThanhVien),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'customer_id': customerId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] == true) return null;
    return data['message']?.toString() ?? 'Xóa thành viên thất bại.';
  }

  /// Tự rời khỏi nhóm - nếu là Trưởng nhóm, hệ thống TỰ ĐỘNG chuyển quyền
  /// cho người khác (không cần app xử lý gì thêm).
  static Future<String?> roiNhom(int conversationId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatRoiNhom),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] == true) return null;
    return data['message']?.toString() ?? 'Rời nhóm thất bại.';
  }

  /// Đổi vai trò 1 thành viên - [vaiTroMoi]: 'thanh_vien' | 'pho_nhom' | 'truong_nhom'
  static Future<String?> doiVaiTro({required int conversationId, required int customerId, required String vaiTroMoi}) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatDoiVaiTro),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'customer_id': customerId, 'vai_tro_moi': vaiTroMoi}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] == true) return null;
    return data['message']?.toString() ?? 'Đổi vai trò thất bại.';
  }

  /// Đổi tên và/hoặc ảnh đại diện nhóm - [anhMoi] không bắt buộc.
  static Future<String?> doiThongTinNhom({required int conversationId, String? tenNhomMoi, String? duongDanAnhMoi}) async {
    final token = await AuthService.getToken();
    final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiChatDoiThongTinNhom));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['conversation_id'] = '$conversationId';
    if (tenNhomMoi != null && tenNhomMoi.isNotEmpty) request.fields['ten_nhom'] = tenNhomMoi;
    if (duongDanAnhMoi != null) request.files.add(await http.MultipartFile.fromPath('anh_dai_dien', duongDanAnhMoi));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body);
    if (data['success'] == true) return null;
    return data['message']?.toString() ?? 'Cập nhật thông tin nhóm thất bại.';
  }

  static Future<String?> giaiTanNhom(int conversationId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatGiaiTanNhom),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] == true) return null;
    return data['message']?.toString() ?? 'Giải tán nhóm thất bại.';
  }

  static Future<List<ChatGroupMember>> layThanhVienNhom(int conversationId) async {
    try {
      final uri = Uri.parse(AppConfig.apiChatThanhVien).replace(queryParameters: {'conversation_id': '$conversationId'});
      final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return (data['data'] as List).map((e) => ChatGroupMember.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Danh sách toàn bộ nhân viên - dùng cho màn chọn thành viên khi tạo/thêm vào nhóm.
  static Future<List<ChatLienHe>> layDanhSachLienHe() async {
    try {
      final res = await http.get(Uri.parse(AppConfig.apiChatDanhSachLienHe), headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return (data['data'] as List).map((e) => ChatLienHe.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Ai đã xem 1 tin nhắn (kiểu Zalo) - trả về danh sách {customer_id, name}
  static Future<List<Map<String, dynamic>>> layAiDaXem(int messageId) async {
    try {
      final uri = Uri.parse(AppConfig.apiChatAiDaXem).replace(queryParameters: {'message_id': '$messageId'});
      final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Ai đã thả reaction cho 1 tin nhắn, kèm đúng loại reaction từng người
  static Future<List<Map<String, dynamic>>> layAiDaThich(int messageId) async {
    try {
      final uri = Uri.parse(AppConfig.apiChatAiDaThich).replace(queryParameters: {'message_id': '$messageId'});
      final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// Toàn bộ Ảnh/File đã gửi trong 1 cuộc trò chuyện - phục vụ màn "Xem Ảnh,
  /// File, Link" kiểu Zalo.
  static Future<List<ChatMessage>> layMediaFiles(int conversationId) async {
    try {
      final uri = Uri.parse(AppConfig.apiChatMediaFiles).replace(queryParameters: {'conversation_id': '$conversationId'});
      final res = await http.get(uri, headers: await _authHeader()).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['success'] != true) return [];
      return (data['data'] as List).map((e) => ChatMessage.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
