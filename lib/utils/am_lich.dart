import 'dart:math';

/// Thuật toán chuyển Dương lịch <-> Âm lịch Việt Nam - dựa trên thuật toán
/// thiên văn chuẩn (tính điểm Sóc - New Moon - và kinh độ Mặt Trời), múi giờ
/// Việt Nam UTC+7. Đây là thuật toán CÔNG KHAI, được hầu hết lịch âm Việt Nam
/// sử dụng - KHÔNG cần gọi API, tính toán offline hoàn toàn trên máy.
///
/// Kết quả trả về dạng [ngày, tháng, năm, làThángNhuận(0/1)].
class AmLich {
  static int _jdFromDate(int dd, int mm, int yy) {
    final a = ((14 - mm) / 12).floor();
    final y = yy + 4800 - a;
    final m = mm + 12 * a - 3;
    var jd = dd + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - (y / 100).floor() + (y / 400).floor() - 32045;
    if (jd < 2299161) {
      jd = dd + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - 32083;
    }
    return jd;
  }

  static List<int> _jdToDate(int jd) {
    int a, b, c;
    if (jd > 2299160) {
      a = jd + 32044;
      b = ((4 * a + 3) / 146097).floor();
      c = a - ((b * 146097) / 4).floor();
    } else {
      b = 0;
      c = jd + 32082;
    }
    final d = ((4 * c + 3) / 1461).floor();
    final e = c - ((1461 * d) / 4).floor();
    final m = ((5 * e + 2) / 153).floor();
    final day = e - ((153 * m + 2) / 5).floor() + 1;
    final month = m + 3 - 12 * (m / 10).floor();
    final year = b * 100 + d - 4800 + (m / 10).floor();
    return [day, month, year];
  }

  static double _newMoon(int k) {
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    final dr = pi / 180;
    var jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    final m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    final mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    final f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    var c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * dr * m);
    c1 -= 0.4068 * sin(mpr * dr);
    c1 += 0.0161 * sin(dr * 2 * mpr);
    c1 -= 0.0004 * sin(dr * 3 * mpr);
    c1 += 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (m + mpr));
    c1 -= 0.0074 * sin(dr * (m - mpr));
    c1 += 0.0004 * sin(dr * (2 * f + m));
    c1 -= 0.0004 * sin(dr * (2 * f - m));
    c1 -= 0.0006 * sin(dr * (2 * f + mpr));
    c1 += 0.0010 * sin(dr * (2 * f - mpr)) + 0.0005 * sin(dr * (2 * mpr + m));
    double deltat;
    if (t < -11) {
      deltat = 0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3;
    } else {
      deltat = -0.000278 + 0.000265 * t + 0.000262 * t2;
    }
    return jd1 + c1 - deltat;
  }

  static int _sunLongitude(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    final dr = pi / 180;
    final m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * sin(dr * m);
    dl += (0.019993 - 0.000101 * t) * sin(dr * 2 * m) + 0.000290 * sin(dr * 3 * m);
    var l = l0 + dl;
    l = l * dr;
    l = l - pi * 2 * (l / (pi * 2)).floor();
    return (l / pi * 6).floor();
  }

  static int _getNewMoonDay(int k, double timeZone) {
    return (_newMoon(k) + 0.5 + timeZone / 24).floor();
  }

  static int _getSunLongitude(int dayNumber, double timeZone) {
    return _sunLongitude(dayNumber - 0.5 - timeZone / 24);
  }

  static int _getLunarMonth11(int yy, double timeZone) {
    final off = _jdFromDate(31, 12, yy) - 2415021;
    final k = (off / 29.530588853).floor();
    var nm = _getNewMoonDay(k, timeZone);
    final sunLong = _getSunLongitude(nm, timeZone);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1, timeZone);
    }
    return nm;
  }

  static int _getLeapMonthOffset(int a11, double timeZone) {
    final k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var i = 1;
    var arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
    do {
      last = arc;
      i++;
      arc = _getSunLongitude(_getNewMoonDay(k + i, timeZone), timeZone);
    } while (arc != last && i < 14);
    return i - 1;
  }

  /// Chuyển 1 ngày Dương lịch sang Âm lịch. Trả về [ngàyÂm, thángÂm, nămÂm, nhuận(0/1)].
  static List<int> duongSangAm(int dd, int mm, int yy) {
    const timeZone = 7.0;
    final dayNumber = _jdFromDate(dd, mm, yy);
    final k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = _getNewMoonDay(k + 1, timeZone);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k, timeZone);
    }
    var a11 = _getLunarMonth11(yy, timeZone);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = yy;
      a11 = _getLunarMonth11(yy - 1, timeZone);
      b11 = _getLunarMonth11(yy, timeZone);
    } else {
      lunarYear = yy + 1;
      b11 = _getLunarMonth11(yy + 1, timeZone);
    }
    final lunarDay = dayNumber - monthStart + 1;
    // ĐÚNG theo mã nguồn gốc đã kiểm chứng (Hồ Ngọc Đức) - KHÔNG cộng +0.5 ở
    // đây. Bản trước đây lỡ cộng +0.5 (làm tròn thay vì lấy phần nguyên) -
    // tuy không phải nguyên nhân chính của lỗi lệch ngày vừa phát hiện,
    // nhưng vẫn là 1 sai lệch so với thuật toán gốc, có thể gây sai THÁNG ở
    // các ngày giáp ranh hiếm gặp nếu không sửa cùng lúc.
    final diff = ((monthStart - a11) / 29).floor();
    var lunarLeap = 0;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthOff = _getLeapMonthOffset(a11, timeZone);
      if (diff >= leapMonthOff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthOff) lunarLeap = 1;
      }
    }
    if (lunarMonth > 12) lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;
    return [lunarDay, lunarMonth, lunarYear, lunarLeap];
  }

  /// Tên ngày trong Can Chi (dùng cho hiển thị thêm nếu cần) - có thể mở
  /// rộng sau, hiện tại chưa dùng tới trong giao diện.
  static const List<String> canList = ['Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý'];
  static const List<String> chiList = ['Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi'];

  static String namCanChi(int lunarYear) {
    final can = canList[(lunarYear + 6) % 10];
    final chi = chiList[(lunarYear + 8) % 12];
    return '$can $chi';
  }
}
