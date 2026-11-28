import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AndroidNativeVersion {
  final String version;
  final int buildNumber;

  const AndroidNativeVersion({
    required this.version,
    required this.buildNumber,
  });
}

class AndroidDownloadResult {
  final bool success;
  final bool permissionRequired;
  final String? apkPath;
  final String? errorMessage;

  const AndroidDownloadResult({
    this.success = false,
    this.permissionRequired = false,
    this.apkPath,
    this.errorMessage,
  });
}

class AndroidUpdaterBridge {
  static const MethodChannel _channel =
      MethodChannel('com.wapp.orderdesk/app_updater');
  static const String _legacyApkFileName = 'orderdesk-latest.apk';

  static String _apkFileNameForBuild(int? buildNumber) {
    if (buildNumber != null && buildNumber > 0) {
      return 'orderdesk-build-$buildNumber.apk';
    }
    return _legacyApkFileName;
  }

  static Future<AndroidNativeVersion?> getNativeVersionInfo() async {
    if (!Platform.isAndroid) return null;
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('getAppVersionInfo');
      if (res == null) return null;
      final version = (res['version'] ?? '').toString();
      final build = (res['buildNumber'] as num?)?.toInt() ?? 0;
      if (version.isEmpty && build <= 0) return null;
      return AndroidNativeVersion(version: version, buildNumber: build);
    } catch (_) {
      return null;
    }
  }

  static Future<AndroidNativeVersion?> getApkVersionInfo(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'getApkVersionInfo',
        {'path': path},
      );
      if (res == null) return null;
      final version = (res['version'] ?? '').toString();
      final build = (res['buildNumber'] as num?)?.toInt() ?? 0;
      if (build <= 0 && version.isEmpty) return null;
      return AndroidNativeVersion(version: version, buildNumber: build);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _getUpdateCacheDir() async {
    try {
      final path = await _channel.invokeMethod<String>('getUpdateCacheDir');
      if (path != null && path.isNotEmpty) {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return path;
      }
    } catch (_) {}
    final temp = await getTemporaryDirectory();
    final updates = Directory('${temp.path}/updates');
    if (!await updates.exists()) {
      await updates.create(recursive: true);
    }
    return updates.path;
  }

  /// Removes legacy `orderdesk-latest.apk`, stale `.part` fragments, and any
  /// cached build-stamped APKs whose buildNumber <= [installedBuildNumber].
  static Future<void> cleanupStaleApks({int? installedBuildNumber}) async {
    if (!Platform.isAndroid) return;
    try {
      final dirPath = await _getUpdateCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      final buildRe = RegExp(r'^orderdesk-build-(\d+)\.apk$');
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (name == _legacyApkFileName || name.endsWith('.part')) {
          await entity.delete();
          continue;
        }
        final m = buildRe.firstMatch(name);
        if (m != null && installedBuildNumber != null) {
          final fileBuild = int.tryParse(m.group(1) ?? '') ?? 0;
          if (fileBuild <= installedBuildNumber) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }

  static Future<String?> getDownloadedApkPath({
    int? expectedBuildNumber,
    int? installedBuildNumber,
  }) async {
    if (!Platform.isAndroid) return null;
    // Never reuse an unversioned cached APK when no target build is known
    if (expectedBuildNumber == null || expectedBuildNumber <= 0) {
      return null;
    }
    try {
      await cleanupStaleApks(installedBuildNumber: installedBuildNumber);
      final dir = await _getUpdateCacheDir();
      final file = File('$dir/${_apkFileNameForBuild(expectedBuildNumber)}');
      if (!await file.exists() || await file.length() <= 100000) {
        return null;
      }
      final apkInfo = await getApkVersionInfo(file.path);
      if (apkInfo != null && apkInfo.buildNumber > 0) {
        if (apkInfo.buildNumber < expectedBuildNumber ||
            (installedBuildNumber != null &&
                apkInfo.buildNumber <= installedBuildNumber)) {
          await file.delete();
          return null;
        }
      }
      return file.path;
    } catch (_) {}
    return null;
  }

  static Future<void> clearDownloadedApk() async {
    if (!Platform.isAndroid) return;
    try {
      final dirPath = await _getUpdateCacheDir();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      final allowed =
          await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final opened =
          await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<AndroidDownloadResult> _launchInstaller(
    String apkPath, {
    int? expectedBuildNumber,
    int? installedBuildNumber,
  }) async {
    final apkFile = File(apkPath);
    if (!await apkFile.exists() || await apkFile.length() <= 100000) {
      return const AndroidDownloadResult(
        errorMessage: 'Downloaded APK file is incomplete or missing',
      );
    }

    // Verify embedded Android versionCode before launching the installer
    final apkInfo = await getApkVersionInfo(apkPath);
    if (apkInfo != null && apkInfo.buildNumber > 0) {
      if (installedBuildNumber != null &&
          apkInfo.buildNumber <= installedBuildNumber) {
        try {
          await apkFile.delete();
        } catch (_) {}
        return AndroidDownloadResult(
          errorMessage:
              'Downloaded APK (Build ${apkInfo.buildNumber}) is not newer than installed Build $installedBuildNumber. Please tap Update again shortly.',
        );
      }
      if (expectedBuildNumber != null &&
          expectedBuildNumber > 0 &&
          apkInfo.buildNumber < expectedBuildNumber) {
        try {
          await apkFile.delete();
        } catch (_) {}
        return AndroidDownloadResult(
          errorMessage:
              'Downloaded APK (Build ${apkInfo.buildNumber}) is older than expected Build $expectedBuildNumber. Please retry.',
        );
      }
    }

    final allowed = await canRequestPackageInstalls();
    if (!allowed) {
      return AndroidDownloadResult(
        permissionRequired: true,
        apkPath: apkPath,
      );
    }

    try {
      final ok = await _channel.invokeMethod<bool>('installApk', {
        'path': apkPath,
      });
      if (ok == true) {
        return AndroidDownloadResult(success: true, apkPath: apkPath);
      }
    } on MissingPluginException {
      // Fallback to open_filex if native channel isn't attached
    } catch (e) {
      final openRes = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      if (openRes.type == ResultType.done) {
        return AndroidDownloadResult(success: true, apkPath: apkPath);
      }
      return AndroidDownloadResult(
        apkPath: apkPath,
        errorMessage: e.toString(),
      );
    }

    final openRes = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    if (openRes.type == ResultType.done) {
      return AndroidDownloadResult(success: true, apkPath: apkPath);
    }
    return AndroidDownloadResult(
      apkPath: apkPath,
      errorMessage: openRes.message,
    );
  }

  static Future<AndroidDownloadResult> installExistingApk({
    int? expectedBuildNumber,
    int? installedBuildNumber,
  }) async {
    final path = await getDownloadedApkPath(
      expectedBuildNumber: expectedBuildNumber,
      installedBuildNumber: installedBuildNumber,
    );
    if (path == null) {
      return const AndroidDownloadResult(
        errorMessage: 'Downloaded APK not found',
      );
    }
    return _launchInstaller(
      path,
      expectedBuildNumber: expectedBuildNumber,
      installedBuildNumber: installedBuildNumber,
    );
  }

  static Future<AndroidDownloadResult> downloadAndInstall({
    required String apkUrl,
    int? expectedBuildNumber,
    int? installedBuildNumber,
    required void Function(double progress) onProgress,
  }) async {
    if (!Platform.isAndroid) {
      return const AndroidDownloadResult(
        errorMessage: 'In-app APK install is only supported on Android',
      );
    }

    final client = http.Client();
    try {
      await clearDownloadedApk();

      final parsed = Uri.parse(apkUrl);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final requestUri = parsed.queryParameters.isEmpty
          ? parsed.replace(queryParameters: {
              if (expectedBuildNumber != null && expectedBuildNumber > 0)
                'b': '$expectedBuildNumber',
              't': '$ts',
            })
          : parsed;

      final request = http.Request('GET', requestUri);
      request.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
      request.headers['Pragma'] = 'no-cache';

      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return AndroidDownloadResult(
          errorMessage: 'Download failed (HTTP ${response.statusCode})',
        );
      }

      final cacheDir = await _getUpdateCacheDir();
      final targetName = _apkFileNameForBuild(expectedBuildNumber);
      final partFile = File('$cacheDir/$targetName.part');
      final finalFile = File('$cacheDir/$targetName');

      if (await partFile.exists()) await partFile.delete();
      if (await finalFile.exists()) await finalFile.delete();

      final sink = partFile.openWrite();
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

      await partFile.rename(finalFile.path);
      onProgress(1.0);

      return await _launchInstaller(
        finalFile.path,
        expectedBuildNumber: expectedBuildNumber,
        installedBuildNumber: installedBuildNumber,
      );
    } catch (e) {
      return AndroidDownloadResult(errorMessage: e.toString());
    } finally {
      client.close();
    }
  }
}
