import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../services/app_version_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppStrings s;
  final InstalledAppVersion installed;
  final AppVersionInfo? latest;
  final Color primaryColor;

  const UpdateDialog({
    super.key,
    required this.s,
    required this.installed,
    required this.latest,
    required this.primaryColor,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> with WidgetsBindingObserver {
  bool _downloading = false;
  bool _permissionRequired = false;
  bool _hasDownloadedApk = false;
  double _progress = 0;
  String? _statusText;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCachedApk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _permissionRequired && !kIsWeb) {
      _checkPermissionAfterReturn();
    }
  }

  Future<void> _checkCachedApk() async {
    if (kIsWeb) return;
    final path = await AppVersionService.getDownloadedApkPath();
    final canInstall = await AppVersionService.canRequestPackageInstalls();
    if (!mounted) return;
    setState(() {
      _hasDownloadedApk = path != null;
      _permissionRequired = path != null && !canInstall;
    });
  }

  Future<void> _checkPermissionAfterReturn() async {
    final allowed = await AppVersionService.canRequestPackageInstalls();
    if (!mounted) return;
    if (allowed) {
      setState(() => _permissionRequired = false);
      await _installExisting();
    }
  }

  Future<void> _installExisting() async {
    setState(() {
      _downloading = true;
      _progress = 1.0;
      _error = null;
      _statusText = widget.s.t('opening_installer');
    });

    final res = await AppVersionService.installExistingApk();
    if (!mounted) return;
    if (res.permissionRequired) {
      setState(() {
        _downloading = false;
        _hasDownloadedApk = true;
        _permissionRequired = true;
      });
    } else if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _downloading = false;
        _error = res.errorMessage ?? 'Install failed';
      });
    }
  }

  Future<void> _startUpdate() async {
    if (kIsWeb && widget.latest?.isWebManifest == true) {
      AppVersionService.reloadWebWithFreshCache();
      return;
    }

    if (!kIsWeb && _hasDownloadedApk) {
      await _installExisting();
      return;
    }

    setState(() {
      _downloading = true;
      _permissionRequired = false;
      _progress = 0;
      _error = null;
      _statusText = widget.s.t('downloading_apk');
    });

    final res = await AppVersionService.downloadAndInstallApk(
      customUrl: widget.latest?.apkUrl,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          if (p >= 1.0 && !kIsWeb) {
            _statusText = widget.s.t('opening_installer');
          }
        });
      },
    );

    if (!mounted) return;
    if (res.permissionRequired) {
      setState(() {
        _downloading = false;
        _hasDownloadedApk = true;
        _permissionRequired = true;
      });
    } else if (res.success) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _downloading = false;
        _error = res.errorMessage ?? 'Update failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final latestVer = widget.latest != null
        ? 'v${widget.latest!.version} (Build ${widget.latest!.buildNumber})'
        : 'Latest APK';
    final currentVer =
        'v${widget.installed.version} (Build ${widget.installed.buildNumber})';
    final isWebUpdate = kIsWeb && widget.latest?.isWebManifest == true;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _permissionRequired
                  ? s.t('install_permission_title')
                  : s.t('update_dialog_title'),
              style:
                  const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _permissionRequired
                ? s.t('install_permission_desc')
                : s.t('update_dialog_desc'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7F6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.t("current_ver")}: $currentVer',
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
                const SizedBox(height: 2),
                Text('${s.t("update_available")}: $latestVer',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: widget.primaryColor)),
              ],
            ),
          ),
          if (_downloading) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 6),
            Text(
              '${_statusText ?? s.t('downloading_apk')} ${(_progress * 100).toInt()}%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.primaryColor),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('later')),
          ),
        if (_permissionRequired && !_downloading) ...[
          OutlinedButton.icon(
            onPressed: () => AppVersionService.openInstallPermissionSettings(),
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: Text(s.t('open_install_settings')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: widget.primaryColor),
            onPressed: _installExisting,
            icon: const Icon(Icons.install_mobile_rounded, size: 17),
            label: Text(s.t('install_downloaded_apk')),
          ),
        ] else ...[
          if (isWebUpdate)
            OutlinedButton.icon(
              onPressed: () =>
                  AppVersionService.downloadApk(widget.latest?.apkUrl),
              icon: const Icon(Icons.android_rounded, size: 16),
              label: Text(s.t('download_apk')),
            ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: widget.primaryColor),
            onPressed: _downloading ? null : _startUpdate,
            icon: Icon(
              isWebUpdate
                  ? Icons.refresh_rounded
                  : _hasDownloadedApk
                      ? Icons.install_mobile_rounded
                      : Icons.system_update_rounded,
              size: 17,
            ),
            label: Text(
              isWebUpdate
                  ? s.t('reload_web_update')
                  : _hasDownloadedApk
                      ? s.t('install_downloaded_apk')
                      : s.t('update_now'),
            ),
          ),
        ],
      ],
    );
  }
}
