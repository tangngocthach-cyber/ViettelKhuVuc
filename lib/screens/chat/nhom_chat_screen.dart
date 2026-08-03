import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import 'chon_thanh_vien_screen.dart';

/// Màn Quản lý nhóm - xem danh sách thành viên kèm vai trò, thêm/xóa thành
/// viên, bổ nhiệm/gỡ Phó nhóm, chuyển ngôi Trưởng nhóm, đổi tên/ảnh nhóm, rời
/// nhóm hoặc giải tán nhóm. Trả về `true` qua Navigator.pop nếu có thay đổi
/// (đổi tên/ảnh/rời/giải tán) để màn Chat phía trên tự làm mới lại.
class NhomChatScreen extends StatefulWidget {
  final ChatConversation conversation;
  const NhomChatScreen({super.key, required this.conversation});

  @override
  State<NhomChatScreen> createState() => _NhomChatScreenState();
}

class _NhomChatScreenState extends State<NhomChatScreen> {
  List<ChatGroupMember> _thanhVien = [];
  bool _dangTai = true;
  int _idCuaToi = 0;
  bool _laQuanTriChatToanHeThong = false;
  bool _coThayDoi = false; // đánh dấu để báo lại cho màn Chat phía trên khi pop

  String get _vaiTroCuaToi {
    final toi = _thanhVien.where((m) => m.customerId == _idCuaToi);
    return toi.isEmpty ? 'thanh_vien' : toi.first.vaiTro;
  }

  bool get _toiLaTruongNhom => _vaiTroCuaToi == 'truong_nhom';
  bool get _toiCoQuyenQuanLy => _laQuanTriChatToanHeThong || _vaiTroCuaToi == 'truong_nhom' || _vaiTroCuaToi == 'pho_nhom';

  @override
  void initState() {
    super.initState();
    _khoiTao();
  }

  Future<void> _khoiTao() async {
    final nguoiDung = await AuthService.getCurrentUser();
    _idCuaToi = int.tryParse(nguoiDung['id'] ?? '0') ?? 0;
    _laQuanTriChatToanHeThong = await AuthService.isChatAdmin();
    await _taiThanhVien();
  }

  Future<void> _taiThanhVien() async {
    setState(() => _dangTai = true);
    final ds = await ChatService.layThanhVienNhom(widget.conversation.id);
    if (!mounted) return;
    setState(() {
      _thanhVien = ds;
      _dangTai = false;
    });
  }

  Future<void> _themThanhVien() async {
    final idDaCo = _thanhVien.map((m) => m.customerId).toSet();
    final chon = await Navigator.push<List<ChatLienHe>>(
      context,
      MaterialPageRoute(builder: (_) => ChonThanhVienScreen(idDaCo: idDaCo, tieuDe: 'Thêm thành viên')),
    );
    if (chon == null || chon.isEmpty) return;
    final loi = await ChatService.themThanhVien(conversationId: widget.conversation.id, thanhVien: chon.map((e) => e.id).toList());
    if (!mounted) return;
    if (loi == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${chon.length} thành viên.')));
      _coThayDoi = true;
      _taiThanhVien();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _xoaThanhVien(ChatGroupMember tv) async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa thành viên'),
        content: Text('Xóa "${tv.name}" khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    final loi = await ChatService.xoaThanhVien(conversationId: widget.conversation.id, customerId: tv.customerId);
    if (!mounted) return;
    if (loi == null) {
      _taiThanhVien();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _doiVaiTro(ChatGroupMember tv, String vaiTroMoi, String moTaXacNhan) async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(moTaXacNhan),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    if (xacNhan != true) return;
    final loi = await ChatService.doiVaiTro(conversationId: widget.conversation.id, customerId: tv.customerId, vaiTroMoi: vaiTroMoi);
    if (!mounted) return;
    if (loi == null) {
      _taiThanhVien();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  void _moTuyChonThanhVien(ChatGroupMember tv) {
    if (tv.customerId == _idCuaToi) return; // không tự thao tác với chính mình qua menu này
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(tv.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tv.tenVaiTro),
            ),
            const Divider(height: 1),
            // Đặt/gỡ Phó nhóm - CHỈ Trưởng nhóm (hoặc Quản trị Chat) mới thấy
            if (_toiLaTruongNhom || _laQuanTriChatToanHeThong) ...[
              if (!tv.laPhoNhom && !tv.laTruongNhom)
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: Colors.blue),
                  title: const Text('Đặt làm Phó nhóm'),
                  onTap: () { Navigator.pop(context); _doiVaiTro(tv, 'pho_nhom', 'Đặt "${tv.name}" làm Phó nhóm?'); },
                ),
              if (tv.laPhoNhom)
                ListTile(
                  leading: const Icon(Icons.remove_moderator_outlined, color: Colors.orange),
                  title: const Text('Gỡ chức Phó nhóm'),
                  onTap: () { Navigator.pop(context); _doiVaiTro(tv, 'thanh_vien', 'Gỡ chức Phó nhóm của "${tv.name}"?'); },
                ),
            ],
            // Chuyển ngôi Trưởng nhóm - CHỈ Trưởng nhóm hiện tại mới thấy
            if (_toiLaTruongNhom && !tv.laTruongNhom)
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined, color: Colors.amber),
                title: const Text('Chuyển ngôi Trưởng nhóm'),
                onTap: () { Navigator.pop(context); _doiVaiTro(tv, 'truong_nhom', 'Chuyển ngôi Trưởng nhóm cho "${tv.name}"? Bạn sẽ trở thành Phó nhóm.'); },
              ),
            if (_toiCoQuyenQuanLy && !tv.laTruongNhom)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
                title: const Text('Xóa khỏi nhóm', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); _xoaThanhVien(tv); },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doiTenNhom() async {
    final ctrl = TextEditingController(text: widget.conversation.ten);
    final tenMoi = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (tenMoi == null || tenMoi.isEmpty || tenMoi == widget.conversation.ten) return;
    final loi = await ChatService.doiThongTinNhom(conversationId: widget.conversation.id, tenNhomMoi: tenMoi);
    if (!mounted) return;
    if (loi == null) {
      _coThayDoi = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi tên nhóm.')));
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _doiAnhNhom() async {
    final picker = ImagePicker();
    final anh = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (anh == null) return;
    final loi = await ChatService.doiThongTinNhom(conversationId: widget.conversation.id, duongDanAnhMoi: anh.path);
    if (!mounted) return;
    if (loi == null) {
      _coThayDoi = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi ảnh nhóm.')));
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _roiNhom() async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rời nhóm'),
        content: Text(
          _toiLaTruongNhom
              ? 'Bạn là Trưởng nhóm - nếu rời, hệ thống sẽ tự động chuyển quyền Trưởng nhóm cho người khác. Tiếp tục?'
              : 'Bạn có chắc muốn rời khỏi nhóm này?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rời nhóm', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    final loi = await ChatService.roiNhom(widget.conversation.id);
    if (!mounted) return;
    if (loi == null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _giaiTanNhom() async {
    final xacNhan = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Giải tán nhóm'),
        content: const Text('Toàn bộ tin nhắn và dữ liệu của nhóm sẽ bị XÓA VĨNH VIỄN. Bạn chắc chắn chứ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Giải tán', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (xacNhan != true) return;
    final loi = await ChatService.giaiTanNhom(widget.conversation.id);
    if (!mounted) return;
    if (loi == null) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _coThayDoi);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Thông tin nhóm')),
        body: SafeArea(
          child: _dangTai
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: widget.conversation.anhDaiDien != null && widget.conversation.anhDaiDien!.isNotEmpty
                                  ? NetworkImage('${AppConfig.baseUrl}${widget.conversation.anhDaiDien}')
                                  : null,
                              child: (widget.conversation.anhDaiDien == null || widget.conversation.anhDaiDien!.isEmpty)
                                  ? const Icon(Icons.groups, size: 40, color: Colors.white)
                                  : null,
                            ),
                            if (_toiCoQuyenQuanLy)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _doiAnhNhom,
                                  child: const CircleAvatar(radius: 14, backgroundColor: AppTheme.viettelRed, child: Icon(Icons.camera_alt, size: 14, color: Colors.white)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _toiCoQuyenQuanLy ? _doiTenNhom : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.conversation.ten, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              if (_toiCoQuyenQuanLy) ...[const SizedBox(width: 6), const Icon(Icons.edit, size: 16, color: Colors.grey)],
                            ],
                          ),
                        ),
                        Text('${_thanhVien.length} thành viên', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Thành viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (_toiCoQuyenQuanLy)
                        TextButton.icon(onPressed: _themThanhVien, icon: const Icon(Icons.person_add, size: 18), label: const Text('Thêm')),
                    ],
                  ),
                  const Divider(),
                  ..._thanhVien.map((tv) => ListTile(
                        leading: Stack(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            if (tv.dangOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                ),
                              ),
                          ],
                        ),
                        title: Text(tv.name + (tv.customerId == _idCuaToi ? ' (Bạn)' : '')),
                        subtitle: Text(
                          tv.dangOnline
                              ? '${tv.tenVaiTro} · 🟢 Đang hoạt động'
                              : '${tv.tenVaiTro} · Vào nhóm ${DateFormat('dd/MM/yyyy').format(tv.joinedAt)}',
                        ),
                        trailing: tv.laTruongNhom
                            ? const Icon(Icons.workspace_premium, color: Colors.amber)
                            : tv.laPhoNhom
                                ? const Icon(Icons.shield, color: Colors.blue)
                                : null,
                        onTap: (_toiCoQuyenQuanLy && tv.customerId != _idCuaToi) ? () => _moTuyChonThanhVien(tv) : null,
                      )),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _roiNhom,
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text('Rời nhóm', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 46)),
                  ),
                  if (_toiLaTruongNhom || _laQuanTriChatToanHeThong) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _giaiTanNhom,
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      label: const Text('Giải tán nhóm'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 46)),
                    ),
                  ],
                ],
              ),
        ),
      ),
    );
  }
}
