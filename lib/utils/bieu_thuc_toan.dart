import 'dart:math' as math;

/// Bộ phân tích cú pháp + tính giá trị biểu thức toán học kiểu
/// "recursive descent parser" - tự viết thuần Dart, KHÔNG dùng thư viện
/// ngoài (tránh rủi ro phụ thuộc). Đảm bảo ĐÚNG thứ tự ưu tiên phép tính
/// chuẩn PEMDAS: Ngoặc () -> Hàm/Lũy thừa (sin, cos, ^, √) -> Nhân/Chia
/// -> Cộng/Trừ, xử lý ĐÚNG cả dấu trừ đứng trước số âm (unary minus).
///
/// Ký hiệu chấp nhận trong biểu thức đầu vào (đã chuẩn hóa từ bàn phím máy
/// tính trước khi gọi): + - × ÷ ^ √ ( ) sin cos tan log ln % và số thập
/// phân dùng dấu CHẤM (người gọi tự đổi dấu phẩy sang chấm trước khi tính).
class BieuThucToanException implements Exception {
  final String thongBao;
  BieuThucToanException(this.thongBao);
  @override
  String toString() => thongBao;
}

class BieuThucToan {
  final String _bieuThuc;
  int _viTri = 0;

  BieuThucToan(this._bieuThuc);

  /// Điểm vào duy nhất - tính giá trị 1 biểu thức, ném lỗi rõ ràng nếu sai
  /// cú pháp (thiếu ngoặc, chia cho 0, biểu thức rỗng...) để giao diện hiện
  /// thông báo "Lỗi cú pháp" thay vì crash hoặc hiện NaN khó hiểu.
  static double tinh(String bieuThuc) {
    final b = bieuThuc.trim();
    if (b.isEmpty) return 0;
    final parser = BieuThucToan(b);
    final ketQua = parser._boPhauThuc();
    parser._boTrangTrong();
    if (parser._viTri < parser._bieuThuc.length) {
      throw BieuThucToanException('Biểu thức không hợp lệ (dư ký tự tại vị trí ${parser._viTri}).');
    }
    if (ketQua.isNaN || ketQua.isInfinite) {
      throw BieuThucToanException('Kết quả không xác định.');
    }
    return ketQua;
  }

  void _boTrangTrong() {
    while (_viTri < _bieuThuc.length && _bieuThuc[_viTri] == ' ') _viTri++;
  }

  bool _khop(String ky) {
    _boTrangTrong();
    if (_viTri < _bieuThuc.length && _bieuThuc[_viTri] == ky) {
      _viTri++;
      return true;
    }
    return false;
  }

  /// Mức 1 (thấp nhất): Cộng, Trừ - trái sang phải
  double _boPhauThuc() {
    var ketQua = _boNhanChia();
    while (true) {
      if (_khop('+')) {
        ketQua += _boNhanChia();
      } else if (_khop('-')) {
        ketQua -= _boNhanChia();
      } else {
        break;
      }
    }
    return ketQua;
  }

  /// Mức 2: Nhân, Chia - trái sang phải, ưu tiên CAO HƠN cộng/trừ
  double _boNhanChia() {
    var ketQua = _boDonVi();
    while (true) {
      if (_khop('×') || _khop('*')) {
        ketQua *= _boDonVi();
      } else if (_khop('÷') || _khop('/')) {
        final b = _boDonVi();
        if (b == 0) throw BieuThucToanException('Không thể chia cho 0.');
        ketQua /= b;
      } else {
        break;
      }
    }
    return ketQua;
  }

  /// Mức 3: Dấu (+/-) đứng TRƯỚC số (unary) - VD -5, -(3+2). Đặt Ở GIỮA
  /// nhân/chia và lũy thừa (KHÔNG đặt dưới lũy thừa) để "-2^2" tính ĐÚNG
  /// chuẩn toán học = -(2^2) = -4 (dấu trừ áp dụng SAU KHI đã tính lũy thừa
  /// của toàn bộ phần còn lại) - khớp hành vi máy tính khoa học thật, và
  /// cũng khớp Python/JavaScript (`-2**2` = -4 ở cả 2 ngôn ngữ này).
  double _boDonVi() {
    if (_khop('-')) return -_boDonVi();
    if (_khop('+')) return _boDonVi();
    return _boLuyThua();
  }

  /// Mức 4: Lũy thừa (^) - PHẢI sang trái (2^3^2 = 2^(3^2) theo chuẩn toán
  /// học), ưu tiên CAO HƠN dấu unary. Vế phải gọi lại _boDonVi() (không
  /// phải _boLuyThua()) để vừa giữ tính kết hợp phải, vừa cho phép số mũ âm
  /// viết tắt không cần ngoặc (VD "2^-2" = 0.25).
  double _boLuyThua() {
    final goc = _boHauTo();
    if (_khop('^')) {
      final soMu = _boDonVi();
      return math.pow(goc, soMu).toDouble();
    }
    return goc;
  }

  /// Mức 5: Hậu tố % (phần trăm) - áp dụng NGAY SAU 1 số/biểu thức con,
  /// nghĩa là "chia cho 100" (VD 50% = 0.5).
  double _boHauTo() {
    var ketQua = _boHam();
    while (_khop('%')) {
      ketQua /= 100;
    }
    return ketQua;
  }

  /// Mức 6: Hàm khoa học (sin, cos, tan, log, ln, sqrt/√) - nhận đúng 1
  /// tham số trong ngoặc theo SAU tên hàm. Góc lượng giác tính theo ĐỘ (°)
  /// cho quen thuộc với người dùng phổ thông (không phải radian).
  double _boHam() {
    for (final ten in ['sin', 'cos', 'tan', 'log', 'ln', 'sqrt']) {
      if (_bieuThuc.startsWith(ten, _viTri)) {
        _viTri += ten.length;
        final thamSo = _boThamSoHam();
        switch (ten) {
          case 'sin':
            return math.sin(thamSo * math.pi / 180);
          case 'cos':
            return math.cos(thamSo * math.pi / 180);
          case 'tan':
            final goc = thamSo % 180;
            if (goc == 90 || goc == -90) throw BieuThucToanException('tan không xác định tại 90°.');
            return math.tan(thamSo * math.pi / 180);
          case 'log':
            if (thamSo <= 0) throw BieuThucToanException('log chỉ tính được với số dương.');
            return math.log(thamSo) / math.ln10;
          case 'ln':
            if (thamSo <= 0) throw BieuThucToanException('ln chỉ tính được với số dương.');
            return math.log(thamSo);
          case 'sqrt':
            if (thamSo < 0) throw BieuThucToanException('Không tính được căn bậc hai của số âm.');
            return math.sqrt(thamSo);
        }
      }
    }
    if (_khop('√')) {
      final thamSo = _boThamSoHam();
      if (thamSo < 0) throw BieuThucToanException('Không tính được căn bậc hai của số âm.');
      return math.sqrt(thamSo);
    }
    // KHÔNG phải tên hàm nào cả -> đây là "lá" thật sự của cây cú pháp (số
    // hoặc biểu thức trong ngoặc) - gọi THẲNG _boSo(), TUYỆT ĐỐI không được
    // gọi lại _boDonVi()/_boHauTo() ở đây vì sẽ tạo VÒNG LẶP VÔ HẠN (các hàm
    // đó gọi ngược lại chính _boHam() này).
    return _boSo();
  }

  /// Tham số của 1 hàm khoa học: chấp nhận CẢ 2 dạng "sin(30)" (có ngoặc,
  /// cho phép biểu thức phức tạp bên trong) LẪN "sin30" hoặc "sin-30" (không
  /// ngoặc, quen thuộc khi bấm liên tiếp trên máy tính điện thoại - chỉ nhận
  /// đúng 1 số đơn, không lồng thêm phép tính, để tránh mơ hồ khi không có
  /// ngoặc phân định rõ ràng).
  double _boThamSoHam() {
    if (_khop('(')) {
      final ketQua = _boPhauThuc();
      if (!_khop(')')) throw BieuThucToanException('Thiếu dấu ngoặc đóng ")".');
      return ketQua;
    }
    if (_khop('-')) return -_boSo();
    return _boSo();
  }

  /// Mức 7 (cao nhất - "lá" của cây cú pháp): Số hoặc biểu thức trong ngoặc.
  double _boSo() {
    if (_khop('(')) {
      final ketQua = _boPhauThuc();
      if (!_khop(')')) throw BieuThucToanException('Thiếu dấu ngoặc đóng ")".');
      return ketQua;
    }
    final batDau = _viTri;
    while (_viTri < _bieuThuc.length && (_soLaChuSo(_bieuThuc[_viTri]) || _bieuThuc[_viTri] == '.')) {
      _viTri++;
    }
    if (_viTri == batDau) {
      throw BieuThucToanException('Biểu thức không hợp lệ tại vị trí $_viTri.');
    }
    return double.parse(_bieuThuc.substring(batDau, _viTri));
  }

  bool _soLaChuSo(String ky) => ky.codeUnitAt(0) >= 48 && ky.codeUnitAt(0) <= 57;
}
