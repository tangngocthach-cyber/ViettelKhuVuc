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
    // SỬA LỖI HIỂN THỊ: trước đây dùng tỉ lệ cố định (childAspectRatio .78)
    // - trên máy chiều ngang hẹp hoặc khi người dùng phóng to cỡ chữ hệ
    // thống, nhãn 2 dòng bị TRÀN (vạch vàng-đen "overflowed"). Nay tính
    // chiều cao ô theo đúng cỡ chữ thực tế: ô icon 66 + khoảng cách 8 +
    // 2 dòng chữ (13 x 1.25) + dư 6.
    final coChu = MediaQuery.textScalerOf(context).scale(13);
    final chieuCaoO = 66 + 8 + coChu * 1.25 * 2 + 6;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      shrinkWrap: !cuonRieng,
      physics: cuonRieng ? null : const NeverScrollableScrollPhysics(),
      // responsive: điện thoại 3-4 cột, máy tính bảng (>600dp) 6 cột - không vỡ layout
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 118, // tăng nhẹ để chứa ô icon lớn hơn
        mainAxisSpacing: 14,
        crossAxisSpacing: 10,
        mainAxisExtent: chieuCaoO,
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
  DateTime? _lanBamTruoc;

  void _moTrang(BuildContext context) {
    // Chống bấm đúp: chạm nhanh 2 lần trước đây mở CHỒNG 2 màn hình giống
    // nhau (phải bấm Quay lại 2 lần). Bỏ qua lần chạm cách lần trước < 0,8s.
    final bayGio = DateTime.now();
    if (_lanBamTruoc != null && bayGio.difference(_lanBamTruoc!) < const Duration(milliseconds: 800)) return;
    _lanBamTruoc = bayGio;
    widget.item.onTap?.call();
    if (widget.item.onTap == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewScreen(url: widget.item.url!, title: widget.item.label)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final toiDangSang = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      label: widget.item.label,
      excludeSemantics: true,
      child: GestureDetector(
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
              width: 66,
              height: 66,
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
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: toiDangSang ? const Color(0xFFFFE3E5) : Colors.transparent, width: 1),
              ),
              // Icon NÉT MẢNH (outline) - TĂNG KÍCH THƯỚC (24->30) theo góp ý
              // "icon hơi nhỏ và khá mỏng" - icon lớn hơn tự nhiên trông đậm
              // nét hơn, dễ nhìn hơn trên màn hình nhỏ.
              child: Icon(widget.item.icon, color: AppTheme.viettelRed, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Tiêu đề nhóm module (vạch đỏ + tên nhóm) dùng CHUNG cho Trang chủ và
/// Cộng đồng. SỬA LỖI HIỂN THỊ: bản cũ để chữ màu đen cứng (Colors.black87)
/// - ở chế độ Tối chữ đen trên nền đen, KHÔNG nhìn thấy tên nhóm.
class TieuDeNhom extends StatelessWidget {
  final String ten;
  final String? moTa;
  const TieuDeNhom(this.ten, {super.key, this.moTa});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: AppTheme.viettelRed, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            ten,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: context.mauChuChinh, letterSpacing: -.2),
          ),
        ),
        if (moTa != null) Text(moTa!, style: TextStyle(fontSize: 12, color: context.mauChuPhu)),
      ]),
    );
  }
}
