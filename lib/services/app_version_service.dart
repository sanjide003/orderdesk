import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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

class InstalledAppVersion {
  final String version;
  final int buildNumber;

  const InstalledAppVersion({
    required this.version,
    required this.buildNumber,
  });
}

class AppVersionService {
  static const String fallbackVersion = '4.0.0';
  static const int fallbackBuildNumber = 4;
  static const String versionJsonUrl =
      'https://orderdeskwapp.vercel.app/version.json';
  static const String defaultApkUrl =
      'https://orderdeskwapp.vercel.app/downloads/orderdesk-latest.apk';

  static Future<InstalledAppVersion> getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? fallbackBuildNumber;
      return InstalledAppVersion(
        version: info.version.isNotEmpty ? info.version : fallbackVersion,
        buildNumber: build,
      );
    } catch (_) {
      return const InstalledAppVersion(
        version: fallbackVersion,
        buildNumber: fallbackBuildNumber,
      );
    }
  }

  static Future<AppVersionInfo?> fetchLatest() async {
    try {
      final uri = Uri.parse(
          '$versionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      return AppVersionInfo(
        version: (map['version'] ?? fallbackVersion).toString(),
        buildNumber: ((map['buildNumber'] ?? fallbackBuildNumber) as num).toInt(),
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

  /// Downloads APK in-app with live progress and launches Android installer
  static Future<String?> downloadAndInstallApk({
    String? customUrl,
    required void Function(double progress) onProgress,
  }) async {
    final url = (customUrl != null && customUrl.isNotEmpty)
        ? customUrl
        : defaultApkUrl;

    if (kIsWeb) {
      final ok = await downloadApk(url);
      onProgress(1.0);
      return ok ? null : 'Could not open download URL';
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return 'Download failed (HTTP ${response.statusCode})';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/orderdesk-latest.apk');
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      final totalBytes = response.contentLength ?? 0;
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          onProgress((received / totalBytes).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
      await sink.close();
      onProgress(1.0);

      final openRes = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      if (openRes.type != ResultType.done) {
        return openRes.message;
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      client.close();
    }
  }
}
