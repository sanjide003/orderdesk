import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'android_updater_bridge_stub.dart'
    if (dart.library.io) 'android_updater_bridge_io.dart';
import 'web_pwa_bridge_stub.dart'
    if (dart.library.js_interop) 'web_pwa_bridge_web.dart';

export 'android_updater_bridge_stub.dart'
    if (dart.library.io) 'android_updater_bridge_io.dart'
    show AndroidDownloadResult, AndroidNativeVersion;

class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String updatedAt;
  final bool isWebManifest;

  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.updatedAt,
    this.isWebManifest = false,
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
  static const int compiledBuildNumber =
      int.fromEnvironment('APP_BUILD_NUMBER', defaultValue: 0);
  static const int compiledWebBuildNumber =
      int.fromEnvironment('WEB_BUILD_NUMBER', defaultValue: 0);
  static const String githubRepo = String.fromEnvironment('GITHUB_REPO');
  static const String fallbackVersionJsonUrl =
      'https://orderdeskwapp.vercel.app/version.json';
  static const String fallbackApkUrl =
      'https://orderdeskwapp.vercel.app/downloads/orderdesk-latest.apk';

  static String get defaultApkUrl => githubRepo.isNotEmpty
      ? 'https://github.com/$githubRepo/releases/latest/download/orderdesk-latest.apk'
      : fallbackApkUrl;

  static Future<InstalledAppVersion> getInstalledVersion() async {
    if (kIsWeb) {
      final build = compiledWebBuildNumber > 0
          ? compiledWebBuildNumber
          : fallbackBuildNumber;
      return InstalledAppVersion(
        version: fallbackVersion,
        buildNumber: build,
      );
    }

    try {
      final native = await AndroidUpdaterBridge.getNativeVersionInfo();
      if (native != null && (native.version.isNotEmpty || native.buildNumber > 0)) {
        return InstalledAppVersion(
          version: native.version.isNotEmpty ? native.version : fallbackVersion,
          buildNumber: native.buildNumber > 0
              ? native.buildNumber
              : (compiledBuildNumber > 0
                  ? compiledBuildNumber
                  : fallbackBuildNumber),
        );
      }
    } catch (_) {}

    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ??
          (compiledBuildNumber > 0 ? compiledBuildNumber : fallbackBuildNumber);
      return InstalledAppVersion(
        version: info.version.isNotEmpty ? info.version : fallbackVersion,
        buildNumber: build > 0 ? build : fallbackBuildNumber,
      );
    } catch (_) {
      return InstalledAppVersion(
        version: fallbackVersion,
        buildNumber:
            compiledBuildNumber > 0 ? compiledBuildNumber : fallbackBuildNumber,
      );
    }
  }

  static bool isRemoteNewer(
      AppVersionInfo remote, InstalledAppVersion installed) {
    if (kIsWeb && compiledWebBuildNumber <= 0 && remote.isWebManifest) {
      // Dev/local preview without injected WEB_BUILD_NUMBER should not nag on web
      return false;
    }
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
    final candidates = <_ManifestCandidate>[];

    if (kIsWeb) {
      candidates.add(_ManifestCandidate(
        uri: Uri.base.resolve('app_version.json?t=$ts'),
        isWebManifest: true,
      ));
      candidates.add(_ManifestCandidate(
        uri: Uri.base.resolve('version.json?t=$ts'),
        isWebManifest: false,
      ));
    }

    if (githubRepo.isNotEmpty) {
      candidates.add(_ManifestCandidate(
        uri: Uri.parse(
            'https://github.com/$githubRepo/releases/latest/download/version.json?t=$ts'),
        isWebManifest: false,
      ));
      candidates.add(_ManifestCandidate(
        uri: Uri.parse(
            'https://api.github.com/repos/$githubRepo/releases/latest'),
        isWebManifest: false,
      ));
    }

    if (!kIsWeb) {
      candidates.add(_ManifestCandidate(
        uri: Uri.parse('$fallbackVersionJsonUrl?t=$ts'),
        isWebManifest: false,
      ));
    }

    for (final candidate in candidates) {
      try {
        final resp = await http.get(candidate.uri, headers: {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) continue;
        final trimmed = resp.body.trimLeft();
        if (!trimmed.startsWith('{')) continue;
        final map = jsonDecode(trimmed) as Map<String, dynamic>;

        if (map.containsKey('version') && map.containsKey('buildNumber')) {
          final rawApkUrl = (map['apkUrl'] ?? '').toString().trim();
          return AppVersionInfo(
            version: (map['version'] ?? fallbackVersion).toString(),
            buildNumber:
                ((map['buildNumber'] ?? fallbackBuildNumber) as num).toInt(),
            apkUrl: rawApkUrl.isNotEmpty ? rawApkUrl : defaultApkUrl,
            updatedAt: (map['updatedAt'] ?? '').toString(),
            isWebManifest: candidate.isWebManifest,
          );
        }

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
              isWebManifest: false,
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
    if (kIsWeb && WebPwaBridge.openExternalUrl(url)) {
      return true;
    }
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  static Future<String?> getDownloadedApkPath() =>
      AndroidUpdaterBridge.getDownloadedApkPath();

  static Future<bool> canRequestPackageInstalls() =>
      AndroidUpdaterBridge.canRequestPackageInstalls();

  static Future<bool> openInstallPermissionSettings() =>
      AndroidUpdaterBridge.openInstallPermissionSettings();

  static Future<AndroidDownloadResult> installExistingApk() =>
      AndroidUpdaterBridge.installExistingApk();

  static Future<AndroidDownloadResult> downloadAndInstallApk({
    String? customUrl,
    required void Function(double progress) onProgress,
  }) async {
    final url = (customUrl != null && customUrl.isNotEmpty)
        ? customUrl
        : defaultApkUrl;

    if (kIsWeb) {
      final ok = await downloadApk(url);
      onProgress(1.0);
      return ok
          ? const AndroidDownloadResult(success: true)
          : const AndroidDownloadResult(
              errorMessage: 'Could not open download URL',
            );
    }

    return AndroidUpdaterBridge.downloadAndInstall(
      apkUrl: url,
      onProgress: onProgress,
    );
  }

  // PWA & Web helpers
  static bool canInstallPwa() => kIsWeb && WebPwaBridge.canInstallPwa();

  static bool isPwaStandalone() => kIsWeb && WebPwaBridge.isStandalone();

  static bool isIosSafari() => kIsWeb && WebPwaBridge.isIosSafari();

  static Future<String> promptPwaInstall() => WebPwaBridge.promptPwaInstall();

  static void reloadWebWithFreshCache() {
    if (kIsWeb) {
      WebPwaBridge.reloadWithFreshCache();
    }
  }
}

class _ManifestCandidate {
  final Uri uri;
  final bool isWebManifest;

  const _ManifestCandidate({
    required this.uri,
    required this.isWebManifest,
  });
}
