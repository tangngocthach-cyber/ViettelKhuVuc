import 'package:flutter/material.dart';
import '../../models/sticker.dart';
import '../../theme.dart';

/// Bottom sheet chọn sticker - lọc theo chủ đề (10 chủ đề, 100 sticker),
/// chạm vào 1 sticker để CHỌN NGAY, trả về cho màn Chat tự gửi đi.
class ChonStickerSheet extends StatefulWidget {
  const ChonStickerSheet({super.key});

  @override
  State<ChonStickerSheet> createState() => _ChonStickerSheetState();
}

class _ChonStickerSheetState extends State<ChonStickerSheet> {
  String _chuDeChon = ChuDeSticker.tatCa.first.ma;

  @override
  Widget build(BuildContext context) {
    final dsTheoChuDe = danhSachSticker.where((s) => s.chuDe == _chuDeChon).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: ChuDeSticker.tatCa.map((c) {
                  final dangChon = _chuDeChon == c.ma;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c.ten, style: const TextStyle(fontSize: 12.5)),
                      selected: dangChon,
                      selectedColor: c.mau,
                      labelStyle: TextStyle(color: dangChon ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _chuDeChon = c.ma),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 4, mainAxisSpacing: 4),
                itemCount: dsTheoChuDe.length,
                itemBuilder: (context, i) {
                  final s = dsTheoChuDe[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, s),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 34)),
                        Text(s.chu, style: const TextStyle(fontSize: 9.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Hàm tiện ích mở bottom sheet chọn sticker - dùng ở màn Chat.
Future<Sticker?> moChonSticker(BuildContext context) {
  return showModalBottomSheet<Sticker>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const ChonStickerSheet(),
  );
}
