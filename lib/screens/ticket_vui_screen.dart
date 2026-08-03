import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ticket_vui.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme.dart';

/// Màn "100 câu hỏi vui nhộn" - chọn chủ đề, bốc ngẫu nhiên 1 câu để mở lời
/// trong nhóm Chat, giúp anh chị em gắn kết ngoài giờ làm việc.
class TicketVuiScreen extends StatefulWidget {
  const TicketVuiScreen({super.key});

  @override
  State<TicketVuiScreen> createState() => _TicketVuiScreenState();
}

class _TicketVuiScreenState extends State<TicketVuiScreen> {
  String? _chuDeChon;
  TicketVui? _ticketHienTai;
  final _random = Random();
  List<ChatConversation> _dsNhom = [];

  List<TicketVui> get _dsTheoChuDe =>
      _chuDeChon == null ? danhSachTicketVui : danhSachTicketVui.where((t) => t.chuDe == _chuDeChon).toList();

  @override
  void initState() {
    super.initState();
    _bocNgauNhien();
    _taiDanhSachNhom();
  }

  Future<void> _taiDanhSachNhom() async {
    final ds = await ChatService.getConversations();
    if (mounted) setState(() => _dsNhom = ds.where((c) => c.loai == 'nhom').toList());
  }

  void _bocNgauNhien() {
    final ds = _dsTheoChuDe;
    if (ds.isEmpty) {
      setState(() => _ticketHienTai = null);
      return;
    }
    setState(() => _ticketHienTai = ds[_random.nextInt(ds.length)]);
  }

  Future<void> _guiVaoNhom() async {
    if (_ticketHienTai == null) return;
    final nhomChon = await showModalBottomSheet<ChatConversation>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(14), child: Text('Gửi tới nhóm nào?', style: TextStyle(fontWeight: FontWeight.bold))),
            if (_dsNhom.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Bạn chưa tham gia nhóm nào.')),
            ..._dsNhom.map((n) => ListTile(
                  leading: const Icon(Icons.groups, color: AppTheme.viettelRed),
                  title: Text(n.ten),
                  onTap: () => Navigator.pop(context, n),
                )),
          ],
        ),
      ),
    );
    if (nhomChon == null || !mounted) return;
    final chuDe = ChuDeTicket.tuMa(_ticketHienTai!.chuDe);
    final noiDungGui = '${chuDe.icon} [${chuDe.ten}]\n${_ticketHienTai!.noiDung}';
    final thanhCong = await ChatService.sendMessage(conversationId: nhomChon.id, noiDung: noiDungGui);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(thanhCong != null ? 'Đã gửi vào "${nhomChon.ten}"!' : 'Gửi thất bại, thử lại sau.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chuDe = _ticketHienTai != null ? ChuDeTicket.tuMa(_ticketHienTai!.chuDe) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('100 câu hỏi vui nhộn')),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _chuDeChon == null,
                    selectedColor: AppTheme.viettelRed,
                    labelStyle: TextStyle(color: _chuDeChon == null ? Colors.white : Colors.black87),
                    onSelected: (_) { setState(() => _chuDeChon = null); _bocNgauNhien(); },
                  ),
                ),
                ...ChuDeTicket.tatCa.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${c.icon} ${c.ten}'),
                        selected: _chuDeChon == c.ma,
                        selectedColor: Color(c.mauHex),
                        labelStyle: TextStyle(color: _chuDeChon == c.ma ? Colors.white : Colors.black87),
                        onSelected: (_) { setState(() => _chuDeChon = c.ma); _bocNgauNhien(); },
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _ticketHienTai == null
                  ? const Text('Không có câu hỏi nào.')
                  : Padding(
                      padding: const EdgeInsets.all(28),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Color(chuDe!.mauHex).withValues(alpha: .15), Color(chuDe.mauHex).withValues(alpha: .05)]),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Color(chuDe.mauHex).withValues(alpha: .3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(chuDe.icon, style: const TextStyle(fontSize: 40)),
                            const SizedBox(height: 10),
                            Text(chuDe.ten, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(chuDe.mauHex))),
                            const SizedBox(height: 16),
                            Text(_ticketHienTai!.noiDung, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4)),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _bocNgauNhien,
                    icon: const Icon(Icons.casino),
                    label: const Text('Bốc câu khác'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _ticketHienTai == null ? null : _guiVaoNhom,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.viettelRed),
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Gửi vào nhóm', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
