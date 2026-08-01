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
      padding: const EdgeInsets.all(16),
      shrinkWrap: !cuonRieng,
      physics: cuonRieng ? null : const NeverScrollableScrollPhysics(),
      // responsive: điện thoại 4 cột, máy tính bảng (>600dp) 6 cột - không vỡ layout
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: .85,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: item.onTap ??
              () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WebViewScreen(url: item.url!, title: item.label)),
                  ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.viettelRed.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: AppTheme.viettelRed, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
