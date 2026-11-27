import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String updatedAt;

  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.updatedAt,
  });
}

class AppVersionService {
  static const String currentVersion = '4.0.0';
  static const int currentBuildNumber = 4;
  static const String versionJsonUrl =
      'https://orderdeskwapp.vercel.app/version.json';
  static const String defaultApkUrl =
      'https://orderdeskwapp.vercel.app/downloads/orderdesk-latest.apk';

  static Future<AppVersionInfo?> fetchLatest() async {
    try {
      final uri = Uri.parse(
          '$versionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      return AppVersionInfo(
        version: (map['version'] ?? currentVersion).toString(),
        buildNumber: ((map['buildNumber'] ?? currentBuildNumber) as num).toInt(),
        apkUrl: (map['apkUrl'] ?? defaultApkUrl).toString(),
        updatedAt: (map['updatedAt'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> downloadApk([String? customUrl]) async {
    final url = (customUrl != null && customUrl.isNotEmpty)
        ? customUrl
        : defaultApkUrl;
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
