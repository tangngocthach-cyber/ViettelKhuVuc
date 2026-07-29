import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/chat_models.dart';
import '../theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool laCuaMinh;
  final bool hienThiTen; // chỉ hiện tên người gửi ở tin đầu tiên của 1 cụm (nhóm chat)
  final bool daXem; // tin nhắn cuối cùng của mình đã được người khác đọc chưa
  final bool laQuanTriChat; // được phép xóa tin của BẤT KỲ AI (xóa đơn phương)
  final Future<void> Function(ChatMessage)? onToggleLike;
  final Future<void> Function(ChatMessage)? onRecall;

  const MessageBubble({
    super.key,
    required this.message,
    required this.laCuaMinh,
    this.hienThiTen = false,
    this.daXem = false,
    this.laQuanTriChat = false,
    this.onToggleLike,
    this.onRecall,
  });

  void _hienMenuHanhDong(BuildContext context) {
    final coTheXoa = laCuaMinh || laQuanTriChat;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(message.daThich ? Icons.thumb_up : Icons.thumb_up_outlined, color: AppTheme.viettelRed),
              title: Text(message.daThich ? 'Bỏ thích' : 'Thích'),
              onTap: () {
                Navigator.pop(context);
                onToggleLike?.call(message);
              },
            ),
            if (coTheXoa && !message.daThuHoi)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(laCuaMinh ? 'Thu hồi tin nhắn' : 'Xóa tin nhắn này (Quản trị)'),
                onTap: () async {
                  Navigator.pop(context);
                  final xacNhan = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Xác nhận'),
                      content: Text(laCuaMinh ? 'Thu hồi tin nhắn này? Mọi người sẽ không xem được nội dung nữa.' : 'Xóa tin nhắn này của người khác? Đây là quyền Quản trị Chat.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (xacNhan == true) onRecall?.call(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: laCuaMinh ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (hienThiTen && !laCuaMinh)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(message.senderName, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
          Row(
            mainAxisAlignment: laCuaMinh ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!laCuaMinh) ...[
                CircleAvatar(radius: 14, backgroundColor: AppTheme.viettelRed.withOpacity(.15), child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: AppTheme.viettelRed))),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: message.daThuHoi ? null : () => _hienMenuHanhDong(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _noiDungBongBong(context),
                      if (message.soThich > 0)
                        Positioned(
                          bottom: -6,
                          right: laCuaMinh ? null : -4,
                          left: laCuaMinh ? -4 : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 2)]),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.thumb_up, size: 10, color: AppTheme.viettelRed),
                              const SizedBox(width: 2),
                              Text('${message.soThich}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 6, left: laCuaMinh ? 0 : 34, right: laCuaMinh ? 4 : 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('HH:mm').format(message.createdAt), style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                if (laCuaMinh) ...[
                  const SizedBox(width: 4),
                  Icon(daXem ? Icons.done_all : Icons.done, size: 13, color: daXem ? AppTheme.viettelRed : Colors.grey),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noiDungBongBong(BuildContext context) {
    final bo = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(laCuaMinh ? 16 : 4),
      bottomRight: Radius.circular(laCuaMinh ? 4 : 16),
    );

    // Tin đã thu hồi/bị xóa - hiện placeholder xám, không còn nội dung thật
    if (message.daThuHoi) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: bo),
        child: const Text('Tin nhắn đã được thu hồi', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13.5)),
      );
    }

    final mauNen = laCuaMinh ? AppTheme.viettelRed : Colors.white;
    final mauChu = laCuaMinh ? Colors.white : Colors.black87;

    if (message.loai == 'image' && message.fileUrl != null) {
      return ClipRRect(
        borderRadius: bo,
        child: GestureDetector(
          onTap: () => showDialog(context: context, builder: (_) => Dialog(child: CachedNetworkImage(imageUrl: message.fileUrl!))),
          child: CachedNetworkImage(
            imageUrl: message.fileUrl!,
            width: 190,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: 190, height: 140, color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (_, __, ___) => Container(width: 190, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
          ),
        ),
      );
    }

    if (message.loai == 'file' && message.fileUrl != null) {
      return InkWell(
        borderRadius: bo,
        onTap: () => _moFile(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: mauNen, borderRadius: bo),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, color: mauChu),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message.fileTenGoc ?? 'Tệp đính kèm', style: TextStyle(color: mauChu, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (message.fileSize != null) Text(_dinhDangDungLuong(message.fileSize!), style: TextStyle(color: mauChu.withOpacity(.7), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: mauNen, borderRadius: bo),
      child: Text(message.noiDung ?? '', style: TextStyle(color: mauChu, fontSize: 15)),
    );
  }

  Future<void> _moFile(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${message.fileTenGoc}';
      final res = await http.get(Uri.parse(message.fileUrl!));
      final file = File(path);
      await file.writeAsBytes(res.bodyBytes);
      await OpenFilex.open(path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được file, thử lại sau.')));
      }
    }
  }

  String _dinhDangDungLuong(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
