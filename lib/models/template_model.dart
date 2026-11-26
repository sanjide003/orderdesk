class TemplateModel {
  final String id;
  final int order;
  final String title;
  final String stage;
  final String body;

  const TemplateModel({
    required this.id,
    required this.order,
    required this.title,
    required this.stage,
    required this.body,
  });

  factory TemplateModel.fromMap(String id, Map<String, dynamic> map) {
    return TemplateModel(
      id: id,
      order: (map['order'] ?? 0) as int,
      title: (map['title'] ?? '') as String,
      stage: (map['stage'] ?? 'general') as String,
      body: (map['body'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order': order,
      'title': title,
      'stage': stage,
      'body': body,
    };
  }
}
