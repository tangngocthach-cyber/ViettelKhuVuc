import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Theo dõi trạng thái mạng TOÀN APP - dùng instance CHUNG (singleton) để mọi
/// màn hình cùng lắng nghe 1 nguồn duy nhất, không cần mỗi màn hình tự kiểm
/// tra mạng riêng lẻ (tốn pin, dễ lệch trạng thái giữa các màn hình).
class ConnectivityService extends ChangeNotifier {
  bool _dangOnline = true;
  bool get dangOnline => _dangOnline;

  Future<void> khoiTao() async {
    try {
      final ketQuaBanDau = await Connectivity().checkConnectivity();
      _capNhat(ketQuaBanDau);
      Connectivity().onConnectivityChanged.listen(_capNhat);
    } catch (e) {
      // Không đọc được trạng thái mạng (hiếm gặp) - mặc định coi như CÓ mạng,
      // để không hiện banner "ngoại tuyến" sai khi thực ra vẫn có mạng.
    }
  }

  void _capNhat(List<ConnectivityResult> ketQua) {
    final online = !ketQua.every((r) => r == ConnectivityResult.none);
    if (online != _dangOnline) {
      _dangOnline = online;
      notifyListeners();
    }
  }
}

/// Instance DÙNG CHUNG toàn app.
final connectivityService = ConnectivityService();
