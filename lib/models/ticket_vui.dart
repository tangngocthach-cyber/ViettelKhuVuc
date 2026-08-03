/// 1 "ticket" trò chuyện vui - 1 câu hỏi/chủ đề ngắn gọn để mở lời trong Chat
/// nhóm, giúp anh chị em gắn kết, không khô khan chỉ toàn công việc.
class TicketVui {
  final String chuDe;
  final String noiDung;
  const TicketVui(this.chuDe, this.noiDung);
}

/// Tên hiển thị + màu + icon cho từng chủ đề.
class ChuDeTicket {
  final String ma;
  final String ten;
  final String icon;
  final int mauHex;
  const ChuDeTicket(this.ma, this.ten, this.icon, this.mauHex);

  static const List<ChuDeTicket> tatCa = [
    ChuDeTicket('yeu_thuong', 'Yêu thương', '💗', 0xFFE91E63),
    ChuDeTicket('vui_hai_huoc', 'Vui - Hài hước', '😂', 0xFFFFA000),
    ChuDeTicket('buon_tam_su', 'Buồn - Tâm sự', '🌧️', 0xFF5C6BC0),
    ChuDeTicket('gian_doi', 'Giận dỗi (nhẹ nhàng)', '😤', 0xFFE64A19),
    ChuDeTicket('ghet_cay_dang', 'Ghét cay ghét đắng', '🙄', 0xFF6D4C41),
    ChuDeTicket('to_mo', 'Tò mò thú vị', '🔍', 0xFF00897B),
    ChuDeTicket('dong_vien', 'Động viên - Khích lệ', '💪', 0xFF43A047),
    ChuDeTicket('hoai_niem', 'Hoài niệm - Kỷ niệm', '📼', 0xFF8D6E63),
    ChuDeTicket('uoc_mo', 'Ước mơ - Hoài bão', '⭐', 0xFFFBC02D),
    ChuDeTicket('bi_mat', 'Bí mật thú vị', '🤫', 0xFF7B1FA2),
  ];

  static ChuDeTicket tuMa(String ma) => tatCa.firstWhere((c) => c.ma == ma, orElse: () => tatCa.first);
}

/// 100 ticket - 10 chủ đề x 10 câu mỗi chủ đề.
const List<TicketVui> danhSachTicketVui = [
  // ================= YÊU THƯƠNG =================
  TicketVui('yeu_thuong', 'Kể tên 1 đồng nghiệp mà bạn thấy dễ thương nhất khi đang bận rộn.'),
  TicketVui('yeu_thuong', 'Món quà nhỏ nào từ đồng nghiệp khiến bạn nhớ mãi?'),
  TicketVui('yeu_thuong', 'Ai trong nhóm hay quan tâm hỏi han bạn nhất mỗi khi bạn mệt?'),
  TicketVui('yeu_thuong', 'Câu nói nào của Sếp/đồng nghiệp khiến bạn thấy được trân trọng?'),
  TicketVui('yeu_thuong', 'Nếu được ôm 1 người trong nhóm ngay bây giờ, bạn chọn ai và vì sao?'),
  TicketVui('yeu_thuong', 'Bạn thể hiện tình cảm với đồng nghiệp bằng cách nào - lời nói hay hành động?'),
  TicketVui('yeu_thuong', 'Kỷ niệm nào khiến bạn thấy "đội mình đúng là 1 gia đình"?'),
  TicketVui('yeu_thuong', 'Ai là người luôn khiến bạn an tâm khi gặp khó khăn trong công việc?'),
  TicketVui('yeu_thuong', 'Điều nhỏ nhặt nào bạn làm cho đồng nghiệp mà không ai để ý?'),
  TicketVui('yeu_thuong', 'Nếu viết 1 dòng cảm ơn cho cả nhóm, bạn sẽ viết gì?'),

  // ================= VUI - HÀI HƯỚC =================
  TicketVui('vui_hai_huoc', 'Tình huống "dở khóc dở cười" nhất bạn từng gặp khi đi khảo sát khách hàng?'),
  TicketVui('vui_hai_huoc', 'Câu nói "cửa miệng" nào của đồng nghiệp khiến bạn buồn cười mỗi lần nghe?'),
  TicketVui('vui_hai_huoc', 'Lần gần nhất bạn cười muốn "sái quai hàm" là khi nào?'),
  TicketVui('vui_hai_huoc', 'Nếu cả nhóm là 1 bộ phim, đó sẽ là phim thể loại gì?'),
  TicketVui('vui_hai_huoc', 'Biệt danh vui nào bạn muốn đặt cho chính mình?'),
  TicketVui('vui_hai_huoc', 'Pha "xử lý tình huống" hài hước nhất khi gặp khách hàng khó tính?'),
  TicketVui('vui_hai_huoc', 'Món ăn "kỳ lạ nhất" bạn từng thử mà vẫn khen ngon?'),
  TicketVui('vui_hai_huoc', 'Nếu được chọn 1 bài hát làm "nhạc hiệu" mỗi khi bạn bước vào văn phòng, đó là bài gì?'),
  TicketVui('vui_hai_huoc', 'Sự cố "cười ra nước mắt" nào bạn từng gặp với thiết bị/dụng cụ làm việc?'),
  TicketVui('vui_hai_huoc', 'Ai trong nhóm mà chỉ cần mở miệng là cả nhóm cười?'),

  // ================= BUỒN - TÂM SỰ =================
  TicketVui('buon_tam_su', 'Điều gì khiến bạn thấy mệt mỏi nhất trong công việc dạo gần đây?'),
  TicketVui('buon_tam_su', 'Có khi nào bạn muốn được lắng nghe hơn là được đưa ra lời khuyên?'),
  TicketVui('buon_tam_su', 'Ngày làm việc buồn nhất của bạn trong năm nay là ngày nào?'),
  TicketVui('buon_tam_su', 'Bạn thường làm gì để "hồi máu" tinh thần sau 1 ngày dài mệt mỏi?'),
  TicketVui('buon_tam_su', 'Có điều gì bạn muốn nói ra nhưng chưa từng chia sẻ với ai trong nhóm?'),
  TicketVui('buon_tam_su', 'Áp lực nào trong công việc khiến bạn trăn trở nhất?'),
  TicketVui('buon_tam_su', 'Bạn nghĩ gì khi bị khách hàng hiểu lầm dù mình đã cố gắng hết sức?'),
  TicketVui('buon_tam_su', 'Có ai từng khiến bạn tủi thân mà bạn chưa nói ra?'),
  TicketVui('buon_tam_su', 'Điều gì giúp bạn vực dậy tinh thần khi cảm thấy chán nản?'),
  TicketVui('buon_tam_su', 'Nếu được nghỉ ngơi 1 ngày trọn vẹn không lo nghĩ gì, bạn sẽ làm gì?'),

  // ================= GIẬN DỖI (NHẸ NHÀNG) =================
  TicketVui('gian_doi', 'Điều gì ở đồng nghiệp khiến bạn "khó chịu nhẹ" nhưng chưa bao giờ nói?'),
  TicketVui('gian_doi', 'Thói quen nào của người khác khiến bạn muốn "nhắc khéo" cả trăm lần?'),
  TicketVui('gian_doi', 'Lần gần nhất bạn giận ai đó trong nhóm (mà giờ đã hết giận) là vì chuyện gì?'),
  TicketVui('gian_doi', 'Câu nói nào khiến bạn "cạn lời" nhất khi làm việc với khách hàng?'),
  TicketVui('gian_doi', 'Điều gì khiến bạn ấm ức nhất mà chỉ biết cười trừ cho qua?'),
  TicketVui('gian_doi', 'Bạn "giận mà thương" ai trong nhóm nhất - kiểu vừa bực vừa buồn cười?'),
  TicketVui('gian_doi', 'Có việc gì bạn từng muốn "vặn vẹo" Sếp 1 câu cho hả dạ?'),
  TicketVui('gian_doi', 'Kiểu người nào khiến bạn "mất kiên nhẫn" nhanh nhất?'),
  TicketVui('gian_doi', 'Tình huống nào khiến bạn phải hít thở thật sâu để không nổi nóng?'),
  TicketVui('gian_doi', 'Nếu được "trút giận" 1 câu ngay bây giờ, bạn muốn nói gì?'),

  // ================= GHÉT CAY GHÉT ĐẮNG =================
  TicketVui('ghet_cay_dang', 'Món ăn nào bạn ghét nhất dù mọi người đều khen ngon?'),
  TicketVui('ghet_cay_dang', 'Kiểu thời tiết nào khiến bạn "ghét cay ghét đắng" khi đi công tác?'),
  TicketVui('ghet_cay_dang', 'Thói quen xấu nào của chính mình mà bạn ghét nhất?'),
  TicketVui('ghet_cay_dang', 'Âm thanh nào khiến bạn khó chịu nhất khi đang làm việc?'),
  TicketVui('ghet_cay_dang', 'Kiểu tin nhắn nào bạn ghét nhận nhất (VD: "ok", "seen" không trả lời)?'),
  TicketVui('ghet_cay_dang', 'Việc gì lặp đi lặp lại khiến bạn thấy chán ngán nhất?'),
  TicketVui('ghet_cay_dang', 'Con vật/côn trùng nào khiến bạn "rùng mình" mỗi lần thấy?'),
  TicketVui('ghet_cay_dang', 'Kiểu người nào bạn "ngán" nhất khi phải làm việc chung?'),
  TicketVui('ghet_cay_dang', 'Ứng dụng/tính năng nào trên điện thoại bạn ghét dùng nhất?'),
  TicketVui('ghet_cay_dang', 'Nếu được xóa sổ 1 thứ trên đời, bạn chọn xóa cái gì?'),

  // ================= TÒ MÒ THÚ VỊ =================
  TicketVui('to_mo', 'Nếu không làm nghề này, bạn nghĩ mình sẽ làm nghề gì?'),
  TicketVui('to_mo', 'Ai là người bạn tò mò muốn biết "1 ngày của họ trông như thế nào"?'),
  TicketVui('to_mo', 'Kỹ năng nào bạn luôn muốn học nhưng chưa có thời gian?'),
  TicketVui('to_mo', 'Nếu được đổi vị trí công việc với 1 đồng nghiệp trong 1 ngày, bạn chọn ai?'),
  TicketVui('to_mo', 'Bạn nghĩ mọi người ấn tượng gì về bạn khi mới gặp lần đầu?'),
  TicketVui('to_mo', 'Món đồ nào bạn luôn mang theo bên người mà ít ai để ý?'),
  TicketVui('to_mo', 'Ai trong nhóm bạn nghĩ giỏi giấu cảm xúc nhất?'),
  TicketVui('to_mo', 'Nếu được hỏi 1 câu bất kỳ với Sếp mà không sợ gì cả, bạn sẽ hỏi gì?'),
  TicketVui('to_mo', 'Bạn nghĩ 10 năm nữa mình sẽ đang làm gì?'),
  TicketVui('to_mo', 'Điều gì về bản thân bạn mà ít đồng nghiệp biết?'),

  // ================= ĐỘNG VIÊN - KHÍCH LỆ =================
  TicketVui('dong_vien', 'Gửi 1 lời động viên tới người đang có KPI thấp nhất tháng này.'),
  TicketVui('dong_vien', 'Câu nói nào từng giúp bạn vượt qua giai đoạn khó khăn?'),
  TicketVui('dong_vien', 'Bạn muốn nhắn gì tới chính mình của 1 năm trước?'),
  TicketVui('dong_vien', 'Thành tích nhỏ nào gần đây bạn tự hào nhưng chưa ai khen?'),
  TicketVui('dong_vien', 'Ai trong nhóm đang cần 1 lời khen ngay lúc này - hãy dành tặng họ!'),
  TicketVui('dong_vien', 'Bạn nghĩ điểm mạnh lớn nhất của cả đội mình là gì?'),
  TicketVui('dong_vien', 'Câu "thần chú" nào giúp bạn lấy lại tinh thần mỗi sáng đi làm?'),
  TicketVui('dong_vien', 'Gửi 1 câu chúc may mắn tới người sắp đi khảo sát/thu cước hôm nay.'),
  TicketVui('dong_vien', 'Bạn tin điều gì sẽ tốt đẹp hơn cho cả nhóm trong tháng tới?'),
  TicketVui('dong_vien', 'Nếu cả đội là 1 đội bóng, bạn sẽ hô khẩu hiệu gì trước trận đấu?'),

  // ================= HOÀI NIỆM - KỶ NIỆM =================
  TicketVui('hoai_niem', 'Kỷ niệm đáng nhớ nhất từ ngày đầu vào làm là gì?'),
  TicketVui('hoai_niem', 'Chuyến công tác/khảo sát nào để lại ấn tượng sâu đậm nhất?'),
  TicketVui('hoai_niem', 'Ai là người đầu tiên hướng dẫn bạn khi mới vào nghề?'),
  TicketVui('hoai_niem', 'Khách hàng nào để lại ấn tượng khó quên nhất với bạn?'),
  TicketVui('hoai_niem', 'Chiếc điện thoại/dụng cụ làm việc đầu tiên của bạn trông như thế nào?'),
  TicketVui('hoai_niem', 'Buổi liên hoan/team building nào bạn nhớ nhất?'),
  TicketVui('hoai_niem', 'Câu chuyện nào về đội nhóm mà bạn hay kể lại cho người khác nghe?'),
  TicketVui('hoai_niem', 'Sai lầm đầu đời trong công việc mà giờ nghĩ lại thấy buồn cười?'),
  TicketVui('hoai_niem', 'Bạn nhớ gì về ngày đầu tiên nhận nhiệm vụ ở khu vực này?'),
  TicketVui('hoai_niem', 'Nếu quay lại thời điểm mới vào nghề, bạn muốn nhắn gì cho bản thân lúc đó?'),

  // ================= ƯỚC MƠ - HOÀI BÃO =================
  TicketVui('uoc_mo', 'Nếu có 1 điều ước cho công việc, bạn ước điều gì?'),
  TicketVui('uoc_mo', 'Mục tiêu lớn nhất bạn muốn đạt được trong năm nay là gì?'),
  TicketVui('uoc_mo', 'Bạn mơ ước vị trí công việc nào trong 5 năm tới?'),
  TicketVui('uoc_mo', 'Nếu được đi du lịch bất kỳ đâu ngay bây giờ, bạn chọn nơi nào?'),
  TicketVui('uoc_mo', 'Điều gì bạn muốn cả đội cùng nhau chinh phục trong năm nay?'),
  TicketVui('uoc_mo', 'Nếu trúng số, việc đầu tiên bạn làm cho bản thân là gì?'),
  TicketVui('uoc_mo', 'Bạn muốn học thêm kỹ năng gì để phát triển sự nghiệp?'),
  TicketVui('uoc_mo', 'Hình ảnh "phiên bản tốt nhất" của bạn trong 3 năm tới trông như thế nào?'),
  TicketVui('uoc_mo', 'Nếu được chọn 1 câu làm phương châm sống, bạn chọn câu gì?'),
  TicketVui('uoc_mo', 'Bạn ước cả nhóm mình sẽ đạt được thành tích gì trong quý này?'),

  // ================= BÍ MẬT THÚ VỊ =================
  TicketVui('bi_mat', 'Sở thích "bí mật" nào của bạn ít người biết?'),
  TicketVui('bi_mat', 'Bạn có tài lẻ nào chưa từng khoe với đồng nghiệp?'),
  TicketVui('bi_mat', 'Món ăn nào bạn có thể ăn liên tục mà không chán?'),
  TicketVui('bi_mat', 'Bài hát nào bạn hay nghêu ngao khi không có ai để ý?'),
  TicketVui('bi_mat', 'Bạn có sợ điều gì "vô lý" mà ít ai ngờ tới không?'),
  TicketVui('bi_mat', 'Thói quen kỳ lạ nào bạn chỉ làm khi ở một mình?'),
  TicketVui('bi_mat', 'Nếu có 1 "siêu năng lực", bạn muốn có năng lực gì?'),
  TicketVui('bi_mat', 'Bộ phim/bài hát nào bạn xem/nghe đi nghe lại cả trăm lần?'),
  TicketVui('bi_mat', 'Biệt tài nấu ăn/pha chế nào bạn tự tin nhất?'),
  TicketVui('bi_mat', 'Nếu phải giữ bí mật 1 điều về bản thân mãi mãi, đó sẽ là gì (mà giờ bạn có dám hé lộ 1 chút không)?'),
];
