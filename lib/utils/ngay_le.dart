/// Danh sách ngày lễ/Tết Việt Nam - dùng để chú thích trên Lịch.
class NgayLe {
  final int ngay;
  final int thang;
  final String ten;
  final bool amLich; // true = tính theo ngày/tháng ÂM lịch, false = DƯƠNG lịch
  const NgayLe(this.ngay, this.thang, this.ten, {this.amLich = false});

  static const List<NgayLe> danhSach = [
    // ----- Ngày lễ DƯƠNG lịch -----
    NgayLe(1, 1, 'Tết Dương lịch'),
    NgayLe(3, 2, 'Thành lập Đảng CSVN'),
    NgayLe(8, 3, 'Quốc tế Phụ nữ'),
    NgayLe(26, 3, 'Thành lập Đoàn TNCS HCM'),
    NgayLe(30, 4, 'Giải phóng miền Nam'),
    NgayLe(1, 5, 'Quốc tế Lao động'),
    NgayLe(19, 5, 'Sinh nhật Bác Hồ'),
    NgayLe(1, 6, 'Quốc tế Thiếu nhi'),
    NgayLe(27, 7, 'Ngày Thương binh Liệt sĩ'),
    NgayLe(19, 8, 'Cách mạng Tháng Tám'),
    NgayLe(2, 9, 'Quốc khánh'),
    NgayLe(20, 10, 'Phụ nữ Việt Nam'),
    NgayLe(20, 11, 'Nhà giáo Việt Nam'),
    NgayLe(22, 12, 'Thành lập QĐND Việt Nam'),
    NgayLe(24, 12, 'Đêm Giáng sinh'),
    NgayLe(25, 12, 'Giáng sinh'),
    // ----- Ngày lễ ÂM lịch -----
    NgayLe(1, 1, 'Tết Nguyên Đán', amLich: true),
    NgayLe(2, 1, 'Tết Nguyên Đán (mùng 2)', amLich: true),
    NgayLe(3, 1, 'Tết Nguyên Đán (mùng 3)', amLich: true),
    NgayLe(15, 1, 'Rằm tháng Giêng', amLich: true),
    NgayLe(10, 3, 'Giỗ Tổ Hùng Vương', amLich: true),
    NgayLe(15, 4, 'Lễ Phật Đản', amLich: true),
    NgayLe(5, 5, 'Tết Đoan Ngọ', amLich: true),
    NgayLe(15, 7, 'Lễ Vu Lan', amLich: true),
    NgayLe(15, 8, 'Tết Trung Thu', amLich: true),
    NgayLe(23, 12, 'Ông Công Ông Táo', amLich: true),
    NgayLe(30, 12, 'Giao thừa', amLich: true),
  ];

  /// Tìm ngày lễ khớp với 1 ngày cụ thể (ưu tiên kiểm tra cả dương lẫn âm).
  static List<NgayLe> timTheoDuong(int ngay, int thang) {
    return danhSach.where((l) => !l.amLich && l.ngay == ngay && l.thang == thang).toList();
  }

  static List<NgayLe> timTheoAm(int ngayAm, int thangAm) {
    return danhSach.where((l) => l.amLich && l.ngay == ngayAm && l.thang == thangAm).toList();
  }
}
