import 'package:flutter/material.dart';
import '../services/version_service.dart';
import '../theme.dart';

/// Dialog thông báo cập nhật - nếu [info.forceUpdate] = true thì KHÔNG CHO
/// đóng dialog (bắt buộc cập nhật mới dùng tiếp được app).
class UpdateDialog extends StatefulWidget {
  final VersionInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _dangTai = false;
  double _tienDo = 0;
  String? _loi;

  Future<void> _taiVaCai() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final filePath = await VersionService.downloadApk(widget.info.apkUrl, (p) {
        if (mounted) setState(() => _tienDo = p);
      });
      await VersionService.installApk(filePath);
    } catch (e) {
      // Hiện đúng lý do (link sai, máy chủ lỗi, file hỏng...) thay vì luôn
      // báo chung chung "kiểm tra mạng" như trước.
      final chiTiet = '$e'.replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() => _loi = chiTiet.isEmpty || chiTiet.contains('SocketException') || chiTiet.contains('TimeoutException')
            ? 'Tải bản cập nhật thất bại, kiểm tra lại mạng Internet rồi thử lại.'
            : 'Tải bản cập nhật thất bại: $chiTiet');
      }
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.forceUpdate,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppTheme.viettelRed),
            const SizedBox(width: 8),
            Expanded(child: Text('Phiên bản mới ${widget.info.versionName}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.info.forceUpdate)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Bạn cần cập nhật để tiếp tục sử dụng app.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            if (widget.info.releaseNotes.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(child: Text(widget.info.releaseNotes)),
              ),
            if (_dangTai) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _tienDo, color: AppTheme.viettelRed),
              const SizedBox(height: 8),
              Text('Đang tải... ${(_tienDo * 100).toStringAsFixed(0)}%'),
            ],
            if (_loi != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_loi!, style: const TextStyle(color: Colors.red))),
          ],
        ),
        actions: [
          if (!widget.info.forceUpdate && !_dangTai) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Để sau')),
          ElevatedButton(onPressed: _dangTai ? null : _taiVaCai, child: Text(_dangTai ? 'Đang tải...' : 'Tải & Cài đặt')),
        ],
      ),
    );
  }
}
