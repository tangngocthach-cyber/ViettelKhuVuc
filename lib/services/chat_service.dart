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
    final data = jsonDecode(res.body);
    if (data['success'] != true) return [];
    return (data['data'] as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  /// Gửi tin nhắn text. [filePath] khác null thì gửi kèm ảnh/file (dùng
  /// multipart) - 1 API DUY NHẤT xử lý cả 3 loại (đúng thiết kế backend).
  static Future<ChatMessage?> sendMessage({
    required int conversationId,
    String? noiDung,
    String? filePath,
  }) async {
    final token = await AuthService.getToken();
    final request = http.MultipartRequest('POST', Uri.parse(AppConfig.apiChatSend));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['conversation_id'] = '$conversationId';
    if (noiDung != null && noiDung.isNotEmpty) request.fields['noi_dung'] = noiDung;
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

  /// Bấm Like/Bỏ Like (toggle) - trả về {da_thich, so_thich} mới nhất
  static Future<Map<String, dynamic>?> toggleLike(int messageId) async {
    final res = await http.post(
      Uri.parse(AppConfig.apiChatLike),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'message_id': messageId}),
    );
    final data = jsonDecode(res.body);
    if (data['success'] != true) return null;
    return {'da_thich': data['da_thich'], 'so_thich': data['so_thich']};
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
}
