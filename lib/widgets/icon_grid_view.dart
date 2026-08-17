import 'package:flutter/material.dart';
import '../screens/webview_screen.dart';
import '../theme.dart';

class GridModuleItem {
  final IconData icon;
  final String label;
  final String? url;
  final VoidCallback? onTap; // Nếu có, dùng hành động này THAY VÌ mở URL qua WebView (VD: mở camera quét QR)
  const GridModuleItem({required this.icon, required this.label, this.url, this.onTap}) : assert(url != null || onTap != null, 'Phải có url hoặc onTap');
}

/// Lưới icon dùng CHUNG cho tab Trang chủ và tab Cộng đồng - bấm vào icon nào
/// sẽ mở đúng trang thật tương ứng trên website qua WebView.
class IconGridView extends StatelessWidget {
  final List<GridModuleItem> items;
  final bool cuonRieng; // true = tự cuộn độc lập (dùng khi là body duy nhất của trang);
  // false = KHÔNG tự cuộn, để trang cha (ListView/SingleChildScrollView) cuộn thay -
  // BẮT BUỘC dùng false khi đặt nhiều IconGridView trong 1 trang cuộn, nếu không sẽ
  // bị lỗi "Vertical viewport was given unbounded height" khiến màn hình trắng trơn
  // (lỗi thật đã gặp trước đây ở tab Trang chủ).
  const IconGridView({super.key, required this.items, this.cuonRieng = true});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      shrinkWrap: !cuonRieng,
      physics: cuonRieng ? null : const NeverScrollableScrollPhysics(),
      // responsive: điện thoại 4 cột, máy tính bảng (>600dp) 6 cột - không vỡ layout
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: .82,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _TheModule(item: items[i]),
    );
  }
}

/// 1 ô module dạng thẻ nổi nhẹ, có hiệu ứng "lún xuống" mượt khi chạm - thay
/// cho icon trần trên nền trong suốt trước đây (nguyên nhân chính khiến giao
/// diện bị chê "sơ sài"). Dùng StatefulWidget CHỈ để xử lý animation nhấn -
/// KHÔNG thêm state nghiệp vụ nào, giữ widget nhẹ, không ảnh hưởng hiệu năng
/// cuộn danh sách dài.
class _TheModule extends StatefulWidget {
  final GridModuleItem item;
  const _TheModule({required this.item});

  @override
  State<_TheModule> createState() => _TheModuleState();
}

class _TheModuleState extends State<_TheModule> {
  bool _dangNhan = false;

  void _moTrang(BuildContext context) {
    widget.item.onTap?.call();
    if (widget.item.onTap == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewScreen(url: widget.item.url!, title: widget.item.label)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toiDangSang = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTapDown: (_) => setState(() => _dangNhan = true),
      onTapCancel: () => setState(() => _dangNhan = false),
      onTapUp: (_) => setState(() => _dangNhan = false),
      onTap: () => _moTrang(context),
      child: AnimatedScale(
        scale: _dangNhan ? .93 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                // Nền RẤT NHẠT (gần trắng) thay vì đỏ đậm như trước - đúng
                // phong cách app chuyên nghiệp tham khảo (nền chỉ ánh hồng rất
                // nhẹ, không lấn át icon).
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: toiDangSang
                      ? [const Color(0xFFFFF3F4), const Color(0xFFFFFAFA)]
                      : [AppTheme.viettelRed.withValues(alpha: .22), AppTheme.viettelRed.withValues(alpha: .10)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: toiDangSang ? const Color(0xFFFFE3E5) : Colors.transparent, width: 1),
              ),
              // Icon NÉT MẢNH (outline) thay vì tô đặc - kiểu tô đặc dày nhìn
              // "thô", icon nét mảnh trông tinh tế/chuyên nghiệp hơn hẳn, đúng
              // góp ý so sánh với app tham khảo.
              child: Icon(widget.item.icon, color: AppTheme.viettelRed, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              widget.item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
