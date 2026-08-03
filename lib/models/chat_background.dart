import 'package:flutter/material.dart';

/// 1 mẫu nền chat - dùng gradient màu (không cần ảnh thật, nhẹ và luôn hiển
/// thị đúng, không lo lỗi tải ảnh). Tiêu chí: màu sắc tươi sáng, tương phản
/// tốt để chữ trong bong bóng chat luôn dễ đọc.
class ChatBackground {
  final String id;
  final String ten;
  final List<Color> mauSac;
  final AlignmentGeometry batDau;
  final AlignmentGeometry ketThuc;

  const ChatBackground({
    required this.id,
    required this.ten,
    required this.mauSac,
    this.batDau = Alignment.topLeft,
    this.ketThuc = Alignment.bottomRight,
  });

  BoxDecoration get decoration => BoxDecoration(
        gradient: LinearGradient(colors: mauSac, begin: batDau, end: ketThuc),
      );

  static const macDinh = ChatBackground(id: 'mac_dinh', ten: 'Mặc định', mauSac: [Color(0xFFF5F5F5), Color(0xFFF5F5F5)]);

  static const List<ChatBackground> tatCa = [
    macDinh,
    ChatBackground(id: 'hong_phan', ten: 'Hồng phấn', mauSac: [Color(0xFFFFE0EC), Color(0xFFFFF0F5)]),
    ChatBackground(id: 'xanh_bien', ten: 'Xanh biển', mauSac: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)]),
    ChatBackground(id: 'vang_nang', ten: 'Vàng nắng', mauSac: [Color(0xFFFFF9C4), Color(0xFFFFECB3)]),
    ChatBackground(id: 'tim_mong_mo', ten: 'Tím mộng mơ', mauSac: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)]),
    ChatBackground(id: 'xanh_la_non', ten: 'Xanh lá non', mauSac: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)]),
    ChatBackground(id: 'cam_dao', ten: 'Cam đào', mauSac: [Color(0xFFFFE0B2), Color(0xFFFFCCBC)]),
    ChatBackground(id: 'bien_hoang_hon', ten: 'Biển hoàng hôn', mauSac: [Color(0xFFFFCCBC), Color(0xFFB3E5FC)]),
    ChatBackground(id: 'keo_bong', ten: 'Kẹo bông', mauSac: [Color(0xFFF8BBD0), Color(0xFFD1C4E9)]),
    ChatBackground(id: 'bac_ha', ten: 'Bạc hà', mauSac: [Color(0xFFB2DFDB), Color(0xFFE0F2F1)]),
    ChatBackground(id: 'ho_dao', ten: 'Hồ đào', mauSac: [Color(0xFFB3E5FC), Color(0xFFB2EBF2)]),
    ChatBackground(id: 'dao_tien', ten: 'Đào tiên', mauSac: [Color(0xFFFFCDD2), Color(0xFFF8BBD0)]),
    ChatBackground(id: 'nang_mai', ten: 'Nắng mai', mauSac: [Color(0xFFFFF59D), Color(0xFFFFE082)]),
    ChatBackground(id: 'suong_som', ten: 'Sương sớm', mauSac: [Color(0xFFCFD8DC), Color(0xFFECEFF1)]),
    ChatBackground(id: 'chanh_day', ten: 'Chanh dây', mauSac: [Color(0xFFF0F4C3), Color(0xFFDCEDC8)]),
    ChatBackground(id: 'hoang_hon_tim', ten: 'Hoàng hôn tím', mauSac: [Color(0xFFCE93D8), Color(0xFFF8BBD0)]),
    ChatBackground(id: 'troi_thu', ten: 'Trời thu', mauSac: [Color(0xFFB3E5FC), Color(0xFFE1F5FE)]),
    ChatBackground(id: 'dua_hau', ten: 'Dưa hấu', mauSac: [Color(0xFFEF9A9A), Color(0xFFA5D6A7)]),
    ChatBackground(id: 'ca_phe_sua', ten: 'Cà phê sữa', mauSac: [Color(0xFFD7CCC8), Color(0xFFEFEBE9)]),
    ChatBackground(id: 'ngoc_lam', ten: 'Ngọc lam', mauSac: [Color(0xFF80DEEA), Color(0xFFB2DFDB)]),
    ChatBackground(id: 'anh_dao', ten: 'Anh đào', mauSac: [Color(0xFFFFCDD2), Color(0xFFFFF9C4)]),
  ];

  static ChatBackground tuId(String? id) => tatCa.firstWhere((b) => b.id == id, orElse: () => macDinh);
}
