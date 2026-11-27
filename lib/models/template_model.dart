import 'package:cloud_firestore/cloud_firestore.dart';

class TemplateModel {
  final String id;
  final int order;
  final String title;
  final String stage;
  final String bodyMl;
  final String bodyEn;
  final String bodyManglish;
  final String productId; // empty = global template, non-empty = product-specific
  final bool isDeleted;
  final DateTime? deletedAt;

  const TemplateModel({
    required this.id,
    required this.order,
    required this.title,
    required this.stage,
    required this.bodyMl,
    required this.bodyEn,
    required this.bodyManglish,
    this.productId = '',
    this.isDeleted = false,
    this.deletedAt,
  });

  String bodyForLang(String langCode) {
    switch (langCode) {
      case 'en':
        return bodyEn.isNotEmpty ? bodyEn : bodyMl;
      case 'manglish':
        return bodyManglish.isNotEmpty ? bodyManglish : bodyMl;
      default:
        return bodyMl.isNotEmpty ? bodyMl : bodyEn;
    }
  }

  TemplateModel copyWith({
    String? id,
    int? order,
    String? title,
    String? stage,
    String? bodyMl,
    String? bodyEn,
    String? bodyManglish,
    String? productId,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return TemplateModel(
      id: id ?? this.id,
      order: order ?? this.order,
      title: title ?? this.title,
      stage: stage ?? this.stage,
      bodyMl: bodyMl ?? this.bodyMl,
      bodyEn: bodyEn ?? this.bodyEn,
      bodyManglish: bodyManglish ?? this.bodyManglish,
      productId: productId ?? this.productId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory TemplateModel.fromMap(String id, Map<String, dynamic> map) {
    final fallback = (map['body'] ?? '') as String;
    DateTime? parseOptDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return TemplateModel(
      id: id,
      order: (map['order'] ?? 0) as int,
      title: (map['title'] ?? '') as String,
      stage: (map['stage'] ?? 'general') as String,
      bodyMl: (map['bodyMl'] ?? fallback) as String,
      bodyEn: (map['bodyEn'] ?? fallback) as String,
      bodyManglish: (map['bodyManglish'] ?? fallback) as String,
      productId: (map['productId'] ?? '') as String,
      isDeleted: (map['isDeleted'] ?? false) as bool,
      deletedAt: parseOptDate(map['deletedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'order': order,
        'title': title,
        'stage': stage,
        'bodyMl': bodyMl,
        'bodyEn': bodyEn,
        'bodyManglish': bodyManglish,
        'productId': productId,
        'isDeleted': isDeleted,
        'deletedAt':
            deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      };
}
