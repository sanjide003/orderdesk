import 'package:cloud_firestore/cloud_firestore.dart';

class MessageLogModel {
  final String id;
  final String recipientName;
  final String phone;
  final String normalizedPhone;
  final String orderId;
  final String customerId;
  final String templateId;
  final String templateTitle;
  final String stage;
  final String lang;
  final String messagePreview;
  final String mode; // 'order_stage', 'direct', 'template', 'bulk_queue'
  final DateTime sentAt;

  const MessageLogModel({
    required this.id,
    this.recipientName = '',
    required this.phone,
    this.normalizedPhone = '',
    this.orderId = '',
    this.customerId = '',
    this.templateId = '',
    this.templateTitle = '',
    this.stage = '',
    this.lang = '',
    this.messagePreview = '',
    this.mode = 'direct',
    required this.sentAt,
  });

  factory MessageLogModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return MessageLogModel(
      id: id,
      recipientName: (map['recipientName'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      normalizedPhone: (map['normalizedPhone'] ?? '') as String,
      orderId: (map['orderId'] ?? '') as String,
      customerId: (map['customerId'] ?? '') as String,
      templateId: (map['templateId'] ?? '') as String,
      templateTitle: (map['templateTitle'] ?? '') as String,
      stage: (map['stage'] ?? '') as String,
      lang: (map['lang'] ?? '') as String,
      messagePreview: (map['messagePreview'] ?? '') as String,
      mode: (map['mode'] ?? 'direct') as String,
      sentAt: parseDate(map['sentAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'recipientName': recipientName,
        'phone': phone,
        'normalizedPhone': normalizedPhone,
        'orderId': orderId,
        'customerId': customerId,
        'templateId': templateId,
        'templateTitle': templateTitle,
        'stage': stage,
        'lang': lang,
        'messagePreview': messagePreview,
        'mode': mode,
        'sentAt': Timestamp.fromDate(sentAt),
      };
}
