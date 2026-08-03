import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';

/// Màn "Ảnh, File, Link" của 1 cuộc trò chuyện - kiểu Zalo. Ảnh/File lấy từ
/// API riêng (toàn bộ, không giới hạn theo những gì đã tải trong màn Chat).
/// Link được TỰ LỌC từ nội dung tin nhắn văn bản (không cần API riêng).
class ChatMediaScreen extends StatefulWidget {
  final int conversationId;
  final List<ChatMessage> tinNhanVanBanHienCo; // truyền từ màn Chat để quét link ngay, không cần tải lại
  const ChatMediaScreen({super.key, required this.conversationId, this.tinNhanVanBanHienCo = const []});

  @override
  State<ChatMediaScreen> createState() => _ChatMediaScreenState();
}

class _ChatMediaScreenState extends State<ChatMediaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChatMessage> _dsAnhFile = [];
  bool _dangTai = true;

  // Nhận diện link trong tin nhắn văn bản - bắt cả http/https lẫn không có
  // tiền tố (VD "example.com") để không bỏ sót link người dùng gõ tắt.
  static final _regexLink = RegExp(r'((https?:\/\/)?[\w-]+(\.[\w-]+)+[^\s]*)', caseSensitive: false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _taiDuLieu();
    _quetLinkTuDanhSachTinNhan(widget.tinNhanVanBanHienCo);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    final ds = await ChatService.layMediaFiles(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _dsAnhFile = ds;
      _dangTai = false;
    });
  }

  List<ChatMessage> get _dsAnh => _dsAnhFile.where((m) => m.loai == 'image').toList();
  List<ChatMessage> get _dsFile => _dsAnhFile.where((m) => m.loai == 'file').toList();

  /// Lọc link từ nội dung TOÀN BỘ tin nhắn văn bản đã có trong danh sách
  /// đang tải (danh sách Media/File hiện tại KHÔNG chứa tin văn bản - cần
  /// tải riêng qua API tin nhắn thường để quét link).
  List<Map<String, String>> _dsLinkTuTinNhan = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ảnh, File, Link'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          tabs: [
            Tab(text: 'Ảnh (${_dsAnh.length})'),
            Tab(text: 'File (${_dsFile.length})'),
            const Tab(text: 'Link'),
          ],
        ),
      ),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator(color: AppTheme.viettelRed))
          : TabBarView(
              controller: _tabController,
              children: [_tabAnh(), _tabFile(), _tabLink()],
            ),
    );
  }

  Widget _tabAnh() {
    if (_dsAnh.isEmpty) return _trangThaiRong('Chưa có ảnh nào được gửi.');
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: _dsAnh.length,
      itemBuilder: (context, i) {
        final tin = _dsAnh[i];
        return GestureDetector(
          onTap: () => _xemAnhToanManHinh(tin),
          child: Image.network(
            tin.fileUrl != null ? '${AppConfig.baseUrl}${tin.fileUrl}' : '',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
          ),
        );
      },
    );
  }

  void _xemAnhToanManHinh(ChatMessage tin) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(tin.fileUrl != null ? '${AppConfig.baseUrl}${tin.fileUrl}' : '')),
            ),
            Positioned(
              top: 30,
              right: 10,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabFile() {
    if (_dsFile.isEmpty) return _trangThaiRong('Chưa có file nào được gửi.');
    return ListView.separated(
      itemCount: _dsFile.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final tin = _dsFile[i];
        return ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.description, color: Colors.white)),
          title: Text(tin.fileTenGoc ?? 'File đính kèm', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${tin.senderName} · ${DateFormat('dd/MM/yyyy HH:mm').format(tin.createdAt)}', style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.download, color: AppTheme.viettelRed),
          onTap: () async {
            if (tin.fileUrl == null) return;
            final uri = Uri.parse('${AppConfig.baseUrl}${tin.fileUrl}');
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được file.')));
            }
          },
        );
      },
    );
  }

  Widget _tabLink() {
    if (_dsLinkTuTinNhan.isEmpty) {
      return _trangThaiRong('Chưa quét được link nào.\n(Chỉ hiện link trong các tin nhắn văn bản gần đây nhất trong khung chat)');
    }
    return ListView.separated(
      itemCount: _dsLinkTuTinNhan.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final link = _dsLinkTuTinNhan[i];
        return ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.link, color: Colors.white)),
          title: Text(link['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(link['nguoiGui'] ?? '', style: const TextStyle(fontSize: 12)),
          onTap: () async {
            var urlChuoi = link['url'] ?? '';
            if (!urlChuoi.startsWith('http')) urlChuoi = 'https://$urlChuoi';
            try {
              await launchUrl(Uri.parse(urlChuoi), mode: LaunchMode.externalApplication);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được link.')));
            }
          },
        );
      },
    );
  }

  Widget _trangThaiRong(String chu) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(chu, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// Quét link từ danh sách tin nhắn văn bản truyền vào (đang hiển thị sẵn
  /// trong màn Chat) - tránh phải gọi thêm API riêng chỉ để lấy lại lịch sử
  /// văn bản.
  void _quetLinkTuDanhSachTinNhan(List<ChatMessage> dsTinNhanVanBan) {
    final ketQua = <Map<String, String>>[];
    for (final tin in dsTinNhanVanBan) {
      if (tin.loai != 'text' || tin.noiDung == null || tin.daThuHoi) continue;
      final khop = _regexLink.allMatches(tin.noiDung!);
      for (final m in khop) {
        ketQua.add({'url': m.group(0) ?? '', 'nguoiGui': '${tin.senderName} · ${DateFormat('dd/MM/yyyy').format(tin.createdAt)}'});
      }
    }
    setState(() => _dsLinkTuTinNhan = ketQua);
  }
}
