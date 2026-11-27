class TemplateModel {
  final String id;
  final int order;
  final String title;
  final String stage;
  final String bodyMl;
  final String bodyEn;
  final String bodyManglish;
  final String productId; // empty = global template, non-empty = product-specific

  const TemplateModel({
    required this.id,
    required this.order,
    required this.title,
    required this.stage,
    required this.bodyMl,
    required this.bodyEn,
    required this.bodyManglish,
    this.productId = '',
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

  factory TemplateModel.fromMap(String id, Map<String, dynamic> map) {
    final fallback = (map['body'] ?? '') as String;
    return TemplateModel(
      id: id,
      order: (map['order'] ?? 0) as int,
      title: (map['title'] ?? '') as String,
      stage: (map['stage'] ?? 'general') as String,
      bodyMl: (map['bodyMl'] ?? fallback) as String,
      bodyEn: (map['bodyEn'] ?? fallback) as String,
      bodyManglish: (map['bodyManglish'] ?? fallback) as String,
      productId: (map['productId'] ?? '') as String,
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
      };
}
