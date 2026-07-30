import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_models.dart';
import 'auth_service.dart';

class ChatService {
  static Future<Map<String, String>> _authHeader() async {
    final token = await AuthService.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  static Future<List<ChatConversation>> getConversations() async {
    final res = await http.get(Uri.parse(AppConfig.apiChatConversations), headers: await _authHeader()).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (data['success'] != true) return [];
    return (data['data'] as List).map((e) => ChatConversation.fromJson(e)).toList();
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
    );
  }

  static Future<void> sendTyping(int conversationId) async {
    await http.post(
      Uri.parse(AppConfig.apiChatTyping),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId}),
    );
  }

  static Future<List<String>> getTypingUsers(int conversationId) async {
    final uri = Uri.parse(AppConfig.apiChatTyping).replace(queryParameters: {'conversation_id': '$conversationId'});
    final res = await http.get(uri, headers: await _authHeader());
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
    );
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return {
      'reaction_cua_toi': data['reaction_cua_toi'],
      'reactions': Map<String, int>.from(data['reactions'] ?? {}),
    };
  }

  /// Thu hồi/xóa tin nhắn - chủ tin nhắn thu hồi của mình, hoặc Quản trị Chat
  /// xóa đơn phương tin của bất kỳ ai.
  static Future<bool> recallMessage(int messageId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatRecall),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId}),
    );
    final data = jsonDecode(res.body);
    return data['success'] == true;
  }

  /// Ghim/Bỏ ghim tin nhắn quan trọng (toggle) - trả về trạng thái ghim mới nhất
  static Future<bool?> togglePin(int messageId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatPin),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId}),
    );
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return data['is_pinned'] as bool;
  }

  /// Lấy danh sách tin nhắn đã ghim trong 1 cuộc trò chuyện
  static Future<List<Map<String, dynamic>>> getPinnedMessages(int conversationId) async {
    final uri = Uri.parse(AppConfig.apiChatPinnedList).replace(queryParameters: {'conversation_id': '$conversationId'});
    final res = await http.get(uri, headers: await _authHeader());
    final data = jsonDecode(res.body);
    if (data['success'] != true) return [];
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
  }

  /// Tìm kiếm trong lịch sử chat của 1 cuộc trò chuyện (chỉ tin nhắn văn bản)
  static Future<List<Map<String, dynamic>>> searchMessages(int conversationId, String tuKhoa) async {
    final uri = Uri.parse(AppConfig.apiChatSearch).replace(queryParameters: {'conversation_id': '$conversationId', 'q': tuKhoa});
    final res = await http.get(uri, headers: await _authHeader());
    final data = jsonDecode(res.body);
    if (data['success'] != true) return [];
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
    );
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
    );
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
    );
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return ChatMessage.fromJson(data['message']);
  }
}
