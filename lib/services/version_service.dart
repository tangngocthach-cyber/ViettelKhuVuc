import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../config.dart';
import '../utils/an_toan.dart';

class VersionInfo {
  final bool hasUpdate;
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
  VersionInfo({
    required this.hasUpdate,
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}

/// Kiểm tra & tải bản cập nhật app - APK tự lưu trữ trên chính website (không
/// qua Google Play, đúng theo lựa chọn triển khai đã thống nhất).
class VersionService {
  /// So sánh version_code hiện tại của app với bản mới nhất trên server.
  static Future<VersionInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final res = await http
          .get(Uri.parse('${AppConfig.apiVersionCheck}?current_code=$currentCode'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map || data['success'] != true || data['has_update'] != true) return null;

      final versionCode = int.tryParse('${data['version_code']}') ?? 0;
      // Server báo có bản mới nhưng mã phiên bản KHÔNG lớn hơn bản đang cài
      // (cấu hình nhầm) - bỏ qua, tránh hiện hộp thoại cập nhật lặp vô hạn.
      if (versionCode <= currentCode) return null;

      // BẢO MẬT: CHỈ chấp nhận file cài đặt tải qua https từ ĐÚNG domain hệ
      // thống - không cài file từ link lạ dù máy chủ trả về gì.
      final apkUrl = _chuanHoaUrlApk('${data['apk_url'] ?? ''}');
      if (apkUrl == null) return null;

      return VersionInfo(
        hasUpdate: true,
        versionCode: versionCode,
        versionName: '${data['version_name'] ?? ''}',
        apkUrl: apkUrl,
        releaseNotes: '${data['release_notes'] ?? ''}',
        forceUpdate: data['force_update'] == true || '${data['force_update']}' == '1',
      );
    } catch (e) {
      return null; // Lỗi mạng: bỏ qua, không làm phiền người dùng
    }
  }

  /// Đường dẫn tương đối ("/tai-app/x.apk") được ghép với domain gốc; đường
  /// dẫn tuyệt đối phải là https + đúng domain hệ thống, ngược lại trả null.
  static String? _chuanHoaUrlApk(String url) {
    final u = url.trim();
    if (u.isEmpty) return null;
    var uri = u.startsWith('/') ? Uri.tryParse('${AppConfig.baseUrl}$u') : Uri.tryParse(u);
    // Link http của CHÍNH domain hệ thống -> tự nâng lên https (app chặn http)
    if (uri != null && uri.scheme == 'http' && AnToan.laHostCuaSite(uri.host)) {
      uri = uri.replace(scheme: 'https');
    }
    if (uri == null || !AnToan.laUrlHttpsCuaSite(uri)) return null;
    return uri.toString();
  }

  /// Tải file .apk về thư mục cache riêng của app, trả về đường dẫn file đã tải.
  /// [onProgress] báo tiến độ 0.0 -> 1.0 để hiển thị thanh tải trên UI.
  ///
  /// SỬA LỖI: trước đây KHÔNG kiểm tra kết quả tải - máy chủ trả lỗi 404/500
  /// (trang HTML) vẫn được lưu thành file .apk rồi mở trình cài đặt, Android
  /// báo "Lỗi phân tích cú pháp gói" khó hiểu. Nay kiểm tra mã trả về, đủ
  /// dung lượng và đúng định dạng APK trước khi cài; mất mạng giữa chừng
  /// thì báo lỗi (có giới hạn thời gian chờ) thay vì treo mãi.
  static Future<String> downloadApk(String apkUrl, void Function(double) onProgress) async {
    final uri = Uri.tryParse(apkUrl);
    if (!AnToan.laUrlHttpsCuaSite(uri)) {
      throw Exception('Link cài đặt không hợp lệ.');
    }
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/vinhhung-update.apk';
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', uri!)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw Exception('Máy chủ trả về lỗi ${response.statusCode}.');
      }
      final total = response.contentLength ?? 0;
      int daTai = 0;

      final sink = file.openWrite();
      try {
        // Mỗi phần dữ liệu phải về trong 60 giây, quá thời gian coi như mất mạng
        await for (final chunk in response.stream.timeout(const Duration(seconds: 60))) {
          daTai += chunk.length;
          sink.add(chunk);
          if (total > 0) onProgress(daTai / total);
        }
      } finally {
        await sink.close();
      }

      if (total > 0 && daTai < total) {
        throw Exception('Tải chưa hết file (mất kết nối giữa chừng).');
      }
      if (!await _laFileApkHopLe(file)) {
        throw Exception('File tải về không phải bộ cài đặt hợp lệ.');
      }
      return filePath;
    } catch (e) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  /// File APK thực chất là file ZIP - 2 byte đầu luôn là "PK" và dung lượng
  /// tối thiểu vài trăm KB. Trang lỗi HTML sẽ không qua được bước này.
  static Future<bool> _laFileApkHopLe(File file) async {
    try {
      final doDai = await file.length();
      if (doDai < 500 * 1024) return false;
      final raf = await file.open();
      try {
        final dau = await raf.read(2);
        return dau.length == 2 && dau[0] == 0x50 && dau[1] == 0x4B;
      } finally {
        await raf.close();
      }
    } catch (e) {
      return false;
    }
  }

  /// Mở trình cài đặt Android với file .apk vừa tải (cần quyền
  /// REQUEST_INSTALL_PACKAGES đã khai báo trong AndroidManifest.xml).
  static Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath);
  }
}
