import 'package:flutter/material.dart';
import '../theme.dart';

/// Thước đo - hiện vạch chia cm/inch NGAY TRÊN MÀN HÌNH, hiệu chỉnh theo mật
/// độ điểm ảnh thật (devicePixelRatio) của từng thiết bị để các vạch đo ra
/// ĐÚNG kích thước thật khi áp vật cần đo lên màn hình (tương tự thước đo có
/// sẵn trên nhiều điện thoại).
class ThuocDoScreen extends StatefulWidget {
  const ThuocDoScreen({super.key});

  @override
  State<ThuocDoScreen> createState() => _ThuocDoScreenState();
}

class _ThuocDoScreenState extends State<ThuocDoScreen> {
  bool _dungCm = true;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Số điểm ảnh LOGIC (dp) tương ứng với 1cm thật - dựa vào devicePixelRatio
    // và mật độ điểm ảnh vật lý chuẩn của Android (160 dpi = 1 inch logic).
    // Công thức: 1 inch vật lý = 2.54cm, số dp/inch xấp xỉ 160 (chuẩn mdpi).
    final soDpMoiCm = 160 / 2.54;
    final soDpMoiInch = 160.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thước đo'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _dungCm = !_dungCm),
            child: Text(_dungCm ? 'cm' : 'inch', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Colors.amber.shade50,
            child: Text(
              '⚠️ Độ chính xác phụ thuộc thông số màn hình từng máy - có thể sai lệch nhẹ, chỉ dùng để ước lượng nhanh, không thay thế thước đo chuyên dụng.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: CustomPaint(
                size: Size(mediaQuery.size.width, double.infinity),
                painter: _ThuocVePainter(soDpMoiDonVi: _dungCm ? soDpMoiCm : soDpMoiInch, dungCm: _dungCm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThuocVePainter extends CustomPainter {
  final double soDpMoiDonVi;
  final bool dungCm;
  _ThuocVePainter({required this.soDpMoiDonVi, required this.dungCm});

  @override
  void paint(Canvas canvas, Size size) {
    final sonNet = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final soDonViToiDa = (size.height / soDpMoiDonVi).floor();
    final soChiaNho = dungCm ? 10 : 8; // cm chia 10 (mm), inch chia 8 (1/8 inch)

    for (int donVi = 0; donVi <= soDonViToiDa; donVi++) {
      final yGoc = donVi * soDpMoiDonVi;

      // Vạch lớn (mỗi đơn vị nguyên) - kéo dài nhất, kèm số
      canvas.drawLine(Offset(0, yGoc), Offset(60, yGoc), sonNet);
      textPainter.text = TextSpan(text: '$donVi', style: const TextStyle(color: Colors.black87, fontSize: 13));
      textPainter.layout();
      textPainter.paint(canvas, Offset(66, yGoc - 7));

      // Vạch chia nhỏ giữa 2 vạch lớn
      if (donVi < soDonViToiDa) {
        for (int chiaNho = 1; chiaNho < soChiaNho; chiaNho++) {
          final yChiaNho = yGoc + (soDpMoiDonVi * chiaNho / soChiaNho);
          // Vạch giữa (nửa đơn vị) dài hơn các vạch chia nhỏ khác
          final doDaiVach = (chiaNho == soChiaNho / 2) ? 40.0 : 24.0;
          canvas.drawLine(Offset(0, yChiaNho), Offset(doDaiVach, yChiaNho), sonNet);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThuocVePainter oldDelegate) => oldDelegate.dungCm != dungCm;
}
