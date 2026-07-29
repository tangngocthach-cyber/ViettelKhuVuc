import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';

class ChatSearchScreen extends StatefulWidget {
  final int conversationId;
  const ChatSearchScreen({super.key, required this.conversationId});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _ketQua = [];
  bool _dangTim = false;
  bool _daTimLanDau = false;

  void _timKiem(String tuKhoa) {
    _debounce?.cancel();
    if (tuKhoa.trim().length < 2) {
      setState(() {
        _ketQua = [];
        _daTimLanDau = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _dangTim = true);
      final ds = await ChatService.searchMessages(widget.conversationId, tuKhoa.trim());
      if (!mounted) return;
      setState(() {
        _ketQua = ds;
        _dangTim = false;
        _daTimLanDau = true;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Tìm trong cuộc trò chuyện này...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: _timKiem,
        ),
      ),
      body: _dangTim
          ? const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed))
          : !_daTimLanDau
              ? const Center(child: Text('Nhập ít nhất 2 ký tự để tìm kiếm', style: TextStyle(color: Colors.grey)))
              : _ketQua.isEmpty
                  ? const Center(child: Text('Không tìm thấy tin nhắn phù hợp', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      itemCount: _ketQua.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final tin = _ketQua[i];
                        final thoiGian = DateTime.tryParse(tin['created_at'] ?? '');
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: AppTheme.viettelRed, child: Icon(Icons.chat, color: Colors.white, size: 18)),
                          title: Text(tin['sender_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: Text(tin['noi_dung'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: thoiGian != null ? Text(DateFormat('dd/MM HH:mm').format(thoiGian), style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
                        );
                      },
                    ),
    );
  }
}
