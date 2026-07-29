import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../config.dart';

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
      final data = jsonDecode(res.body);
      if (res.statusCode != 200 || data['success'] != true || data['has_update'] != true) return null;

      return VersionInfo(
        hasUpdate: true,
        versionCode: data['version_code'],
        versionName: data['version_name'],
        apkUrl: data['apk_url'],
        releaseNotes: data['release_notes'] ?? '',
        forceUpdate: data['force_update'] ?? false,
      );
    } catch (e) {
      return null; // Lỗi mạng: bỏ qua, không làm phiền người dùng
    }
  }

  /// Tải file .apk về thư mục cache riêng của app, trả về đường dẫn file đã tải.
  /// [onProgress] báo tiến độ 0.0 -> 1.0 để hiển thị thanh tải trên UI.
  static Future<String> downloadApk(String apkUrl, void Function(double) onProgress) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/vinhhung-update.apk';
    final file = File(filePath);

    final request = http.Request('GET', Uri.parse(apkUrl));
    final response = await request.send();
    final total = response.contentLength ?? 0;
    int daTai = 0;

    final sink = file.openWrite();
    await response.stream.listen((chunk) {
      daTai += chunk.length;
      sink.add(chunk);
      if (total > 0) onProgress(daTai / total);
    }).asFuture();
    await sink.close();

    return filePath;
  }

  /// Mở trình cài đặt Android với file .apk vừa tải (cần quyền
  /// REQUEST_INSTALL_PACKAGES đã khai báo trong AndroidManifest.xml).
  static Future<void> installApk(String filePath) async {
    await OpenFilex.open(filePath);
  }
}
