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

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _statusText;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
      _statusText = widget.s.t('downloading_apk');
    });

    final err = await AppVersionService.downloadAndInstallApk(
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
    if (err != null) {
      setState(() {
        _downloading = false;
        _error = err;
      });
    } else {
      Navigator.pop(context, true);
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
              s.t('update_dialog_title'),
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('update_dialog_desc'), style: const TextStyle(fontSize: 13)),
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
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: widget.primaryColor),
          onPressed: _downloading ? null : _startUpdate,
          icon: const Icon(Icons.system_update_rounded, size: 17),
          label: Text(s.t('update_now')),
        ),
      ],
    );
  }
}
