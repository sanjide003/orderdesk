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
  static const String githubRepo = String.fromEnvironment('GITHUB_REPO');
  static const String fallbackVersionJsonUrl =
      'https://orderdeskwapp.vercel.app/version.json';
  static const String fallbackApkUrl =
      'https://orderdeskwapp.vercel.app/downloads/orderdesk-latest.apk';

  static String get defaultApkUrl => githubRepo.isNotEmpty
      ? 'https://github.com/$githubRepo/releases/latest/download/orderdesk-latest.apk'
      : fallbackApkUrl;

  static Future<InstalledAppVersion> getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? fallbackBuildNumber;
      return InstalledAppVersion(
        version: info.version.isNotEmpty ? info.version : fallbackVersion,
        buildNumber: build > 0 ? build : fallbackBuildNumber,
      );
    } catch (_) {
      return const InstalledAppVersion(
        version: fallbackVersion,
        buildNumber: fallbackBuildNumber,
      );
    }
  }

  static bool isRemoteNewer(
      AppVersionInfo remote, InstalledAppVersion installed) {
    if (remote.buildNumber > installed.buildNumber) return true;
    if (remote.buildNumber < installed.buildNumber) return false;
    final rParts =
        remote.version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final iParts =
        installed.version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = rParts.length > iParts.length ? rParts.length : iParts.length;
    for (int i = 0; i < len; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final cur = i < iParts.length ? iParts[i] : 0;
      if (r > cur) return true;
      if (r < cur) return false;
    }
    return false;
  }

  static Future<AppVersionInfo?> fetchLatest() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final candidates = <Uri>[];

    if (githubRepo.isNotEmpty) {
      candidates.add(Uri.parse(
          'https://github.com/$githubRepo/releases/latest/download/version.json?t=$ts'));
      candidates.add(Uri.parse(
          'https://api.github.com/repos/$githubRepo/releases/latest'));
    }
    if (kIsWeb) {
      candidates.add(Uri.base.resolve('version.json?t=$ts'));
    }
    candidates.add(Uri.parse('$fallbackVersionJsonUrl?t=$ts'));

    for (final uri in candidates) {
      try {
        final resp = await http.get(uri, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 7));
        if (resp.statusCode != 200) continue;
        final trimmed = resp.body.trimLeft();
        if (!trimmed.startsWith('{')) continue;
        final map = jsonDecode(trimmed) as Map<String, dynamic>;

        // Support version.json format
        if (map.containsKey('version') && map.containsKey('buildNumber')) {
          return AppVersionInfo(
            version: (map['version'] ?? fallbackVersion).toString(),
            buildNumber:
                ((map['buildNumber'] ?? fallbackBuildNumber) as num).toInt(),
            apkUrl: (map['apkUrl'] ?? defaultApkUrl).toString(),
            updatedAt: (map['updatedAt'] ?? '').toString(),
          );
        }

        // Support GitHub Releases REST API fallback
        if (map.containsKey('assets')) {
          final assets = (map['assets'] as List<dynamic>? ?? []);
          String? apkDownload;
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final name = (asset['name'] ?? '').toString().toLowerCase();
              if (name.endsWith('.apk')) {
                apkDownload =
                    (asset['browser_download_url'] ?? '').toString();
                break;
              }
            }
          }
          if (apkDownload != null && apkDownload.isNotEmpty) {
            final titleOrTag =
                '${map['name'] ?? ''} ${map['tag_name'] ?? ''}';
            final verMatch =
                RegExp(r'(\d+\.\d+\.\d+)').firstMatch(titleOrTag);
            final buildMatch =
                RegExp(r'Build\s*(\d+)', caseSensitive: false)
                    .firstMatch(titleOrTag);
            return AppVersionInfo(
              version: verMatch?.group(1) ?? fallbackVersion,
              buildNumber:
                  int.tryParse(buildMatch?.group(1) ?? '') ?? fallbackBuildNumber,
              apkUrl: apkDownload,
              updatedAt: (map['published_at'] ?? '').toString(),
            );
          }
        }
      } catch (_) {
        // Try next source
      }
    }
    return null;
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
          await client.send(request).timeout(const Duration(seconds: 25));
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
