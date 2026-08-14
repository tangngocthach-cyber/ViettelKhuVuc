import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Màn vẽ tay TOÀN MÀN HÌNH - không cần thư viện ngoài, dùng thẳng
/// CustomPainter + GestureDetector có sẵn trong Flutter (đủ mượt cho ghi
/// chú nhanh, không cần độ chính xác như app vẽ chuyên nghiệp). Trả về
/// Uint8List (dữ liệu ảnh PNG) khi bấm "Xong", hoặc null nếu hủy/không vẽ
/// gì cả.
class VeTayScreen extends StatefulWidget {
  final Uint8List? anhBanDauNenVe; // vẽ tiếp lên ảnh cũ nếu đang sửa ghi chú đã có nét vẽ
  const VeTayScreen({super.key, this.anhBanDauNenVe});

  @override
  State<VeTayScreen> createState() => _VeTayScreenState();
}

class _NetVe {
  final List<Offset> diem = [];
  final Color mau;
  final double doDay;
  _NetVe({required this.mau, required this.doDay});
}

class _VeTayScreenState extends State<VeTayScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<_NetVe> _cacNet = [];
  Color _mauDangChon = Colors.black;
  double _doDayDangChon = 3.5;
  ui.Image? _anhNen;

  static const _bangMau = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange];

  @override
  void initState() {
    super.initState();
    _taiAnhNen();
  }

  Future<void> _taiAnhNen() async {
    if (widget.anhBanDauNenVe == null) return;
    final codec = await ui.instantiateImageCodec(widget.anhBanDauNenVe!);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _anhNen = frame.image);
  }

  void _batDauNet(DragStartDetails d) {
    setState(() {
      final net = _NetVe(mau: _mauDangChon, doDay: _doDayDangChon);
      net.diem.add(d.localPosition);
      _cacNet.add(net);
    });
  }

  void _tiepTucNet(DragUpdateDetails d) {
    setState(() => _cacNet.last.diem.add(d.localPosition));
  }

  void _xoaHet() {
    setState(() {
      _cacNet.clear();
      _anhNen = null;
    });
  }

  void _hoanTacNetCuoi() {
    if (_cacNet.isEmpty) return;
    setState(() => _cacNet.removeLast());
  }

  Future<void> _xongVaLuu() async {
    if (_cacNet.isEmpty && _anhNen == null) {
      if (mounted) Navigator.pop(context, null);
      return;
    }
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) Navigator.pop(context, byteData!.buffer.asUint8List());
    } catch (e) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viết tay'),
        backgroundColor: const Color(0xFFEE0033),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.undo), tooltip: 'Hoàn tác nét gần nhất', onPressed: _hoanTacNetCuoi),
          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Xóa hết', onPressed: _xoaHet),
          TextButton(
            onPressed: _xongVaLuu,
            child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                ..._bangMau.map((mau) => GestureDetector(
                      onTap: () => setState(() => _mauDangChon = mau),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: mau, shape: BoxShape.circle,
                          border: Border.all(color: _mauDangChon == mau ? Colors.grey.shade700 : Colors.transparent, width: 3),
                        ),
                      ),
                    )),
                const Spacer(),
                const Icon(Icons.line_weight, size: 18, color: Colors.grey),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _doDayDangChon, min: 1, max: 10,
                    onChanged: (v) => setState(() => _doDayDangChon = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RepaintBoundary(
              key: _repaintKey,
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: GestureDetector(
                  onPanStart: _batDauNet,
                  onPanUpdate: _tiepTucNet,
                  child: CustomPaint(
                    painter: _BangVePainter(cacNet: _cacNet, anhNen: _anhNen),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BangVePainter extends CustomPainter {
  final List<_NetVe> cacNet;
  final ui.Image? anhNen;
  _BangVePainter({required this.cacNet, this.anhNen});

  @override
  void paint(Canvas canvas, Size size) {
    if (anhNen != null) {
      canvas.drawImageRect(
        anhNen!,
        Rect.fromLTWH(0, 0, anhNen!.width.toDouble(), anhNen!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
    }
    for (final net in cacNet) {
      final paint = Paint()
        ..color = net.mau
        ..strokeWidth = net.doDay
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (int i = 0; i < net.diem.length - 1; i++) {
        canvas.drawLine(net.diem[i], net.diem[i + 1], paint);
      }
      if (net.diem.length == 1) {
        canvas.drawCircle(net.diem[0], net.doDay / 2, paint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(_BangVePainter oldDelegate) => true;
}
