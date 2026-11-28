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
  static Future<AndroidNativeVersion?> getNativeVersionInfo() async => null;

  static Future<bool> canRequestPackageInstalls() async => false;

  static Future<bool> openInstallPermissionSettings() async => false;

  static Future<String?> getDownloadedApkPath() async => null;

  static Future<void> clearDownloadedApk() async {}

  static Future<AndroidDownloadResult> installExistingApk() async =>
      const AndroidDownloadResult(errorMessage: 'Not supported on Web');

  static Future<AndroidDownloadResult> downloadAndInstall({
    required String apkUrl,
    required void Function(double progress) onProgress,
  }) async =>
      const AndroidDownloadResult(errorMessage: 'Not supported on Web');
}
