import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../models/chat_models.dart';
import '../theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool laCuaMinh;
  final bool hienThiTen; // chỉ hiện tên người gửi ở tin đầu tiên của 1 cụm (nhóm chat)
  final bool daXem; // tin nhắn cuối cùng của mình đã được người khác đọc chưa
  final bool laQuanTriChat; // được phép xóa tin của BẤT KỲ AI (xóa đơn phương)
  final Future<void> Function(ChatMessage, String loaiReaction)? onReaction;
  final Future<void> Function(ChatMessage)? onRecall;
  final Future<void> Function(ChatMessage)? onPin;
  final void Function(ChatMessage)? onTraLoi;
  final Future<void> Function(ChatMessage, int optionId)? onVotePoll;
  final void Function(ChatMessage)? onForward;

  const MessageBubble({
    super.key,
    required this.message,
    required this.laCuaMinh,
    this.hienThiTen = false,
    this.daXem = false,
    this.laQuanTriChat = false,
    this.onReaction,
    this.onRecall,
    this.onPin,
    this.onTraLoi,
    this.onVotePoll,
    this.onForward,
  });

  void _hienThanhReactionNhanh(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 10)]),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ChatReactions.emojiTheoLoai.entries.map((e) {
              final dangChon = message.reactionCuaToi == e.key;
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.pop(context);
                  onReaction?.call(message, e.key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: dangChon ? AppTheme.viettelRed.withValues(alpha: .15) : null, shape: BoxShape.circle),
                  child: Text(e.value, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _hienMenuHanhDong(BuildContext context) {
    final coTheXoa = laCuaMinh || laQuanTriChat;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined, color: AppTheme.viettelRed),
              title: const Text('Bày tỏ cảm xúc'),
              onTap: () {
                Navigator.pop(context);
                _hienThanhReactionNhanh(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: AppTheme.viettelRed),
              title: const Text('Trả lời'),
              onTap: () {
                Navigator.pop(context);
                onTraLoi?.call(message);
              },
            ),
            ListTile(
              leading: Icon(message.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppTheme.viettelRed),
              title: Text(message.isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn'),
              onTap: () {
                Navigator.pop(context);
                onPin?.call(message);
              },
            ),
            if (!message.daThuHoi && message.loai != 'voice' && message.loai != 'poll')
              ListTile(
                leading: const Icon(Icons.forward, color: AppTheme.viettelRed),
                title: const Text('Chuyển tiếp'),
                onTap: () {
                  Navigator.pop(context);
                  onForward?.call(message);
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
          if (message.isPinned)
            Padding(
              padding: EdgeInsets.only(left: laCuaMinh ? 0 : 34, bottom: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.push_pin, size: 11, color: Colors.grey),
                SizedBox(width: 3),
                Text('Đã ghim', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
              ]),
            ),
          Row(
            mainAxisAlignment: laCuaMinh ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!laCuaMinh) ...[
                CircleAvatar(radius: 14, backgroundColor: AppTheme.viettelRed.withValues(alpha: .15), child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: AppTheme.viettelRed))),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: message.daThuHoi ? null : () => _hienMenuHanhDong(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: laCuaMinh ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (message.replyTo != null) _khungTrichDan(),
                          _noiDungBongBong(context),
                        ],
                      ),
                      if (message.tongSoReaction > 0) _huyHieuReaction(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: message.tongSoReaction > 0 ? 12 : 6, left: laCuaMinh ? 0 : 34, right: laCuaMinh ? 4 : 0),
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

  /// Khung nhỏ hiện phía trên bong bóng khi tin nhắn này là TRẢ LỜI 1 tin khác
  Widget _khungTrichDan() {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (laCuaMinh ? Colors.white : AppTheme.viettelRed).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: AppTheme.viettelRed, width: 3)),
      ),
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.replyTo!.senderName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.viettelRed)),
          Text(message.replyTo!.noiDung, style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  /// Huy hiệu nhỏ hiện các emoji reaction + tổng số, đặt góc dưới bong bóng
  Widget _huyHieuReaction() {
    final loaiCoNguoiBam = message.reactions.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final toiDa3Loai = loaiCoNguoiBam.take(3);
    return Positioned(
      bottom: -8,
      right: laCuaMinh ? null : -4,
      left: laCuaMinh ? -4 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 2)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ...toiDa3Loai.map((e) => Text(ChatReactions.emojiTheoLoai[e.key] ?? '', style: const TextStyle(fontSize: 11))),
          const SizedBox(width: 2),
          Text('${message.tongSoReaction}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
        ]),
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
                    if (message.fileSize != null) Text(_dinhDangDungLuong(message.fileSize!), style: TextStyle(color: mauChu.withValues(alpha: .7), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.loai == 'voice' && message.fileUrl != null) {
      return _VoicePlayerBubble(fileUrl: message.fileUrl!, durationGiay: message.durationGiay ?? 0, mauNen: mauNen, mauChu: mauChu, bo: bo);
    }

    if (message.loai == 'reminder' && message.reminder != null) {
      return _khungNhacHen(mauNen, mauChu, bo);
    }

    if (message.loai == 'poll' && message.poll != null) {
      return _khungBinhChon(context, mauNen, mauChu, bo);
    }

    if (message.loai == 'location' && message.lat != null && message.lng != null) {
      return _khungViTri(bo);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: mauNen, borderRadius: bo),
      child: Text(message.noiDung ?? '', style: TextStyle(color: mauChu, fontSize: (message.coChu ?? 15).toDouble())),
    );
  }

  Widget _khungBinhChon(BuildContext context, Color mauNen, Color mauChu, BorderRadius bo) {
    final poll = message.poll!;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: mauNen, borderRadius: bo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.poll, size: 16, color: mauChu),
            const SizedBox(width: 6),
            Expanded(child: Text(poll.cauHoi, style: TextStyle(color: mauChu, fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
          const SizedBox(height: 8),
          ...poll.options.map((opt) {
            final tyLe = poll.tongLuotBinhChon == 0 ? 0.0 : opt.soPhieu / poll.tongLuotBinhChon;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onVotePoll?.call(message, opt.id),
                child: Stack(
                  children: [
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: (laCuaMinh ? Colors.white : AppTheme.viettelRed).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: tyLe.clamp(0, 1),
                        child: Container(decoration: BoxDecoration(color: (laCuaMinh ? Colors.white : AppTheme.viettelRed).withValues(alpha: .28), borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Icon(opt.toiDaChon ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: mauChu),
                            const SizedBox(width: 6),
                            Expanded(child: Text(opt.noiDung, style: TextStyle(color: mauChu, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                            Text('${opt.soPhieu}', style: TextStyle(color: mauChu, fontSize: 11.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Text('${poll.tongLuotBinhChon} lượt bình chọn', style: TextStyle(color: mauChu.withValues(alpha: .7), fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _khungNhacHen(Color mauNen, Color mauChu, BorderRadius bo) {
    final r = message.reminder!;
    final daQua = r.thoiGianNhac.isBefore(DateTime.now());
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: mauNen, borderRadius: bo),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.notifications_active, size: 16, color: mauChu),
            const SizedBox(width: 6),
            Expanded(child: Text('Nhắc hẹn', style: TextStyle(color: mauChu, fontWeight: FontWeight.bold, fontSize: 12.5))),
          ]),
          const SizedBox(height: 6),
          Text(r.tieuDe, style: TextStyle(color: mauChu, fontWeight: FontWeight.w600, fontSize: 14.5)),
          if (r.moTa != null && r.moTa!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.moTa!, style: TextStyle(color: mauChu.withValues(alpha: .85), fontSize: 12.5)),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: mauChu.withValues(alpha: .15), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 12, color: mauChu),
              const SizedBox(width: 4),
              Text(
                DateFormat('HH:mm dd/MM/yyyy').format(r.thoiGianNhac) + (daQua ? ' (đã qua)' : ''),
                style: TextStyle(color: mauChu, fontSize: 11),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _khungViTri(BorderRadius bo) {
    return InkWell(
      borderRadius: bo,
      onTap: () => launchUrl(Uri.parse('https://maps.google.com/?q=${message.lat},${message.lng}'), mode: LaunchMode.externalApplication),
      child: Container(
        width: 200,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: bo, border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 90,
              decoration: BoxDecoration(color: const Color(0xFFE8EAED), borderRadius: BorderRadius.vertical(top: bo.topLeft)),
              child: const Center(child: Icon(Icons.location_on, color: AppTheme.viettelRed, size: 36)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined, size: 14, color: AppTheme.viettelRed),
                  const SizedBox(width: 5),
                  const Expanded(child: Text('Xem trên bản đồ', style: TextStyle(fontSize: 12.5, color: AppTheme.viettelRed, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ),
      ),
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

/// Bong bóng tin nhắn thoại - StatefulWidget RIÊNG (khác MessageBubble chính)
/// vì mỗi tin thoại cần 1 AudioPlayer độc lập, tự quản lý trạng thái phát/dừng.
class _VoicePlayerBubble extends StatefulWidget {
  final String fileUrl;
  final int durationGiay;
  final Color mauNen;
  final Color mauChu;
  final BorderRadius bo;
  const _VoicePlayerBubble({required this.fileUrl, required this.durationGiay, required this.mauNen, required this.mauChu, required this.bo});

  @override
  State<_VoicePlayerBubble> createState() => _VoicePlayerBubbleState();
}

class _VoicePlayerBubbleState extends State<_VoicePlayerBubble> {
  final _player = AudioPlayer();
  bool _dangPhat = false;
  Duration _viTriHienTai = Duration.zero;
  Duration _tongThoiLuong = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tongThoiLuong = Duration(seconds: widget.durationGiay);
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _dangPhat = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _viTriHienTai = pos);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _dangPhat = false; _viTriHienTai = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _batTat() async {
    if (_dangPhat) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.fileUrl));
    }
  }

  String _dinhDangGio(Duration d) {
    final phut = d.inMinutes;
    final giay = d.inSeconds % 60;
    return '$phut:${giay.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tienDo = _tongThoiLuong.inMilliseconds == 0 ? 0.0 : _viTriHienTai.inMilliseconds / _tongThoiLuong.inMilliseconds;
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: widget.mauNen, borderRadius: widget.bo),
      child: Row(
        children: [
          InkWell(
            onTap: _batTat,
            child: Icon(_dangPhat ? Icons.pause_circle_filled : Icons.play_circle_fill, color: widget.mauChu, size: 34),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: tienDo.clamp(0, 1), minHeight: 4, backgroundColor: widget.mauChu.withValues(alpha: .25), color: widget.mauChu),
                ),
                const SizedBox(height: 4),
                Text(
                  _dangPhat || _viTriHienTai.inSeconds > 0 ? _dinhDangGio(_viTriHienTai) : _dinhDangGio(_tongThoiLuong),
                  style: TextStyle(color: widget.mauChu.withValues(alpha: .85), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
