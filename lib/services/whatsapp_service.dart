import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firestore_service.dart';

class WhatsAppLogMeta {
  final String recipientName;
  final String orderId;
  final String customerId;
  final String templateId;
  final String templateTitle;
  final String stage;
  final String lang;
  final String mode;

  const WhatsAppLogMeta({
    this.recipientName = '',
    this.orderId = '',
    this.customerId = '',
    this.templateId = '',
    this.templateTitle = '',
    this.stage = '',
    this.lang = '',
    this.mode = 'direct',
  });
}

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
    WhatsAppLogMeta? logMeta,
    bool logWhenEmptyPhone = false,
  }) async {
    final normalized = normalizePhone(phone);
    final encoded = Uri.encodeComponent(message);
    final url = normalized.isNotEmpty
        ? 'https://wa.me/$normalized?text=$encoded'
        : 'https://wa.me/?text=$encoded';
    final launched =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (launched &&
        logMeta != null &&
        (normalized.isNotEmpty || logWhenEmptyPhone)) {
      try {
        await FirestoreService().logMessageSend(
          phone: phone,
          recipientName: logMeta.recipientName,
          orderId: logMeta.orderId,
          customerId: logMeta.customerId,
          templateId: logMeta.templateId,
          templateTitle: logMeta.templateTitle,
          stage: logMeta.stage,
          lang: logMeta.lang,
          messagePreview: message,
          mode: logMeta.mode,
        );
      } catch (_) {
        // Non-fatal: logging failure must never block opening WhatsApp.
      }
    }
    return launched;
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
    await SharePlus.instance.share(ShareParams(text: message));
  }
}
