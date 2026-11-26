import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static String normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10) return '91$digits';
    return digits;
  }

  static Future<bool> openDirectChat({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizePhone(phone);
    final encoded = Uri.encodeComponent(message);
    final url = normalized.isNotEmpty
        ? 'https://wa.me/$normalized?text=$encoded'
        : 'https://wa.me/?text=$encoded';
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> callPhone(String rawPhone) async {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return false;
    return launchUrl(Uri.parse('tel:$digits'));
  }

  static Future<void> copyMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
  }

  static Future<void> shareMessage(String message) async {
    await Share.share(message);
  }
}
