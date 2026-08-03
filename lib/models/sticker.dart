import 'package:flutter/material.dart';

/// Tiền tố đặc biệt đánh dấu 1 tin nhắn văn bản THỰC RA là sticker - dùng
/// CHUNG API gửi tin nhắn văn bản bình thường (không cần sửa gì backend),
/// message_bubble.dart nhận diện tiền tố này để hiển thị thành thẻ sticker
/// lớn thay vì bong bóng chat chữ thông thường.
const String tienToSticker = '__STICKER__';

/// 1 chủ đề sticker.
class ChuDeSticker {
  final String ma;
  final String ten;
  final Color mau;
  const ChuDeSticker(this.ma, this.ten, this.mau);

  static const List<ChuDeSticker> tatCa = [
    ChuDeSticker('vui_ve', 'Vui vẻ', Color(0xFFFFA000)),
    ChuDeSticker('yeu_thuong', 'Yêu thương', Color(0xFFE91E63)),
    ChuDeSticker('buon', 'Buồn', Color(0xFF5C6BC0)),
    ChuDeSticker('gian', 'Giận', Color(0xFFE64A19)),
    ChuDeSticker('chao_hoi', 'Chào hỏi', Color(0xFF00897B)),
    ChuDeSticker('khen_ngoi', 'Khen ngợi', Color(0xFF43A047)),
    ChuDeSticker('cong_viec', 'Công việc', Color(0xFF3949AB)),
    ChuDeSticker('an_uong', 'Ăn uống', Color(0xFFEF6C00)),
    ChuDeSticker('meo', 'Mèo', Color(0xFF8D6E63)),
    ChuDeSticker('le_tet', 'Lễ Tết', Color(0xFFD32F2F)),
  ];

  static ChuDeSticker tuMa(String ma) => tatCa.firstWhere((c) => c.ma == ma, orElse: () => tatCa.first);
}

/// 1 sticker - emoji lớn + câu ngắn đi kèm.
class Sticker {
  final String chuDe;
  final String emoji;
  final String chu;
  const Sticker(this.chuDe, this.emoji, this.chu);

  /// Mã hóa thành text để gửi qua API tin nhắn văn bản bình thường.
  String get maHoaGui => '$tienToSticker|$emoji|$chu';

  /// Giải mã ngược lại từ nội dung tin nhắn - trả về null nếu không đúng định dạng sticker.
  static Sticker? giaiMa(String? noiDung) {
    if (noiDung == null || !noiDung.startsWith('$tienToSticker|')) return null;
    final phan = noiDung.split('|');
    if (phan.length < 3) return null;
    return Sticker('', phan[1], phan.sublist(2).join('|'));
  }
}

/// 100 sticker - 10 chủ đề x 10 sticker mỗi chủ đề.
const List<Sticker> danhSachSticker = [
  // ================= VUI VẺ =================
  Sticker('vui_ve', '😂', 'Cười xỉu'),
  Sticker('vui_ve', '🤣', 'Hài vãi'),
  Sticker('vui_ve', '😆', 'Vui quá trời'),
  Sticker('vui_ve', '🥳', 'Quẩy thôi'),
  Sticker('vui_ve', '😎', 'Ngầu xỉu'),
  Sticker('vui_ve', '🤩', 'Wow đỉnh'),
  Sticker('vui_ve', '😜', 'Tinh nghịch'),
  Sticker('vui_ve', '🙃', 'Đời vui mà'),
  Sticker('vui_ve', '✨', 'Lấp lánh'),
  Sticker('vui_ve', '🎉', 'Xịn xò'),

  // ================= YÊU THƯƠNG =================
  Sticker('yeu_thuong', '❤️', 'Yêu quá đi'),
  Sticker('yeu_thuong', '🥰', 'Iu bạn'),
  Sticker('yeu_thuong', '😘', 'Chụt cái'),
  Sticker('yeu_thuong', '🤗', 'Ôm phát'),
  Sticker('yeu_thuong', '💕', 'Thương lắm'),
  Sticker('yeu_thuong', '🫶', 'Trái tim'),
  Sticker('yeu_thuong', '💖', 'Yêu mãi'),
  Sticker('yeu_thuong', '🌹', 'Tặng bạn'),
  Sticker('yeu_thuong', '🥹', 'Cảm động'),
  Sticker('yeu_thuong', '💝', 'Món quà'),

  // ================= BUỒN =================
  Sticker('buon', '😢', 'Buồn quá'),
  Sticker('buon', '😭', 'Khóc thét'),
  Sticker('buon', '🥺', 'Tội ghê'),
  Sticker('buon', '😔', 'Chán ghê'),
  Sticker('buon', '😞', 'Thất vọng'),
  Sticker('buon', '💔', 'Vỡ tim'),
  Sticker('buon', '😪', 'Mệt mỏi'),
  Sticker('buon', '🙁', 'Hơi buồn'),
  Sticker('buon', '😥', 'Chạnh lòng'),
  Sticker('buon', '🌧️', 'Mưa buồn'),

  // ================= GIẬN =================
  Sticker('gian', '😤', 'Hừm!'),
  Sticker('gian', '😡', 'Tức ghê'),
  Sticker('gian', '🤬', 'Điên tiết'),
  Sticker('gian', '😠', 'Bực mình'),
  Sticker('gian', '👿', 'Nổi giận'),
  Sticker('gian', '🙄', 'Thôi khỏi nói'),
  Sticker('gian', '😑', 'Mệt với bạn'),
  Sticker('gian', '💢', 'Nóng máu'),
  Sticker('gian', '😒', 'Chán bạn ghê'),
  Sticker('gian', '🚫', 'Thôi dừng lại'),

  // ================= CHÀO HỎI =================
  Sticker('chao_hoi', '👋', 'Chào bạn'),
  Sticker('chao_hoi', '🙋', 'Có mặt'),
  Sticker('chao_hoi', '🌞', 'Chào buổi sáng'),
  Sticker('chao_hoi', '🌙', 'Ngủ ngon nha'),
  Sticker('chao_hoi', '☕', 'Cà phê chưa'),
  Sticker('chao_hoi', '🫡', 'Rõ ạ'),
  Sticker('chao_hoi', '👀', 'Ai gọi đó'),
  Sticker('chao_hoi', '🤝', 'Bắt tay nào'),
  Sticker('chao_hoi', '📣', 'Chú ý nha'),
  Sticker('chao_hoi', '🔔', 'Có tin mới'),

  // ================= KHEN NGỢI =================
  Sticker('khen_ngoi', '👍', 'Tuyệt vời'),
  Sticker('khen_ngoi', '👏', 'Vỗ tay'),
  Sticker('khen_ngoi', '🔥', 'Quá đỉnh'),
  Sticker('khen_ngoi', '💯', 'Trăm điểm'),
  Sticker('khen_ngoi', '🏆', 'Số 1'),
  Sticker('khen_ngoi', '🎯', 'Chuẩn luôn'),
  Sticker('khen_ngoi', '⭐', 'Xuất sắc'),
  Sticker('khen_ngoi', '💪', 'Cố lên'),
  Sticker('khen_ngoi', '🙌', 'Làm tốt lắm'),
  Sticker('khen_ngoi', '🚀', 'Bứt phá'),

  // ================= CÔNG VIỆC =================
  Sticker('cong_viec', '💼', 'Đi làm thôi'),
  Sticker('cong_viec', '📊', 'Báo cáo đây'),
  Sticker('cong_viec', '✅', 'Xong việc'),
  Sticker('cong_viec', '⏰', 'Đến giờ rồi'),
  Sticker('cong_viec', '📝', 'Ghi chú lại'),
  Sticker('cong_viec', '💻', 'Đang code'),
  Sticker('cong_viec', '📞', 'Gọi cho khách'),
  Sticker('cong_viec', '🎯', 'Đạt chỉ tiêu'),
  Sticker('cong_viec', '😅', 'Việc dồn quá'),
  Sticker('cong_viec', '🏃', 'Chạy deadline'),

  // ================= ĂN UỐNG =================
  Sticker('an_uong', '🍜', 'Ăn cơm chưa'),
  Sticker('an_uong', '☕', 'Làm ly cà phê'),
  Sticker('an_uong', '🍚', 'Đói bụng'),
  Sticker('an_uong', '🍕', 'Thèm pizza'),
  Sticker('an_uong', '🧋', 'Trà sữa đi'),
  Sticker('an_uong', '🍺', 'Lai rai nào'),
  Sticker('an_uong', '🍰', 'Ăn bánh không'),
  Sticker('an_uong', '🥤', 'Mát lạnh'),
  Sticker('an_uong', '🍗', 'Ngon quá trời'),
  Sticker('an_uong', '🍉', 'Giải nhiệt'),

  // ================= MÈO =================
  Sticker('meo', '😺', 'Meo meo'),
  Sticker('meo', '😹', 'Cười mèo'),
  Sticker('meo', '😻', 'Yêu mèo'),
  Sticker('meo', '🙀', 'Hết hồn'),
  Sticker('meo', '😼', 'Xảo quyệt'),
  Sticker('meo', '😽', 'Thơm cái'),
  Sticker('meo', '🐱', 'Mèo con'),
  Sticker('meo', '😾', 'Hừ mèo'),
  Sticker('meo', '🐾', 'Dấu chân'),
  Sticker('meo', '😴', 'Mèo ngủ'),

  // ================= LỄ TẾT =================
  Sticker('le_tet', '🎊', 'Chúc mừng'),
  Sticker('le_tet', '🧧', 'Lì xì đây'),
  Sticker('le_tet', '🎆', 'Pháo hoa'),
  Sticker('le_tet', '🎄', 'Giáng sinh vui'),
  Sticker('le_tet', '🎂', 'Sinh nhật vui'),
  Sticker('le_tet', '🎁', 'Quà đây'),
  Sticker('le_tet', '🥂', 'Cạn ly'),
  Sticker('le_tet', '🌸', 'Mùa xuân về'),
  Sticker('le_tet', '🐉', 'Rồng vàng'),
  Sticker('le_tet', '🎇', 'Rực rỡ'),
];
