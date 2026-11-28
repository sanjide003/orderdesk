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
  static const String _apkFileName = 'orderdesk-latest.apk';

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

  static Future<String?> getDownloadedApkPath() async {
    if (!Platform.isAndroid) return null;
    try {
      final dir = await _getUpdateCacheDir();
      final file = File('$dir/$_apkFileName');
      if (await file.exists() && await file.length() > 100000) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearDownloadedApk() async {
    if (!Platform.isAndroid) return;
    try {
      final dir = await _getUpdateCacheDir();
      final file = File('$dir/$_apkFileName');
      if (await file.exists()) await file.delete();
      final part = File('$dir/$_apkFileName.part');
      if (await part.exists()) await part.delete();
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

  static Future<AndroidDownloadResult> _launchInstaller(String apkPath) async {
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
      // Try OpenFilex fallback before failing
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

  static Future<AndroidDownloadResult> installExistingApk() async {
    final path = await getDownloadedApkPath();
    if (path == null) {
      return const AndroidDownloadResult(
        errorMessage: 'Downloaded APK not found',
      );
    }
    return _launchInstaller(path);
  }

  static Future<AndroidDownloadResult> downloadAndInstall({
    required String apkUrl,
    required void Function(double progress) onProgress,
  }) async {
    if (!Platform.isAndroid) {
      return const AndroidDownloadResult(
        errorMessage: 'In-app APK install is only supported on Android',
      );
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return AndroidDownloadResult(
          errorMessage: 'Download failed (HTTP ${response.statusCode})',
        );
      }

      final cacheDir = await _getUpdateCacheDir();
      final partFile = File('$cacheDir/$_apkFileName.part');
      final finalFile = File('$cacheDir/$_apkFileName');

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

      return await _launchInstaller(finalFile.path);
    } catch (e) {
      return AndroidDownloadResult(errorMessage: e.toString());
    } finally {
      client.close();
    }
  }
}
