class ProductPack {
  final String label;
  final double price;
  final String taxNote;
  final double deliveryCharge;

  const ProductPack({
    required this.label,
    required this.price,
    this.taxNote = '',
    this.deliveryCharge = 0,
  });

  factory ProductPack.fromMap(Map<String, dynamic> map) {
    return ProductPack(
      label: (map['label'] ?? '') as String,
      price: ((map['price'] ?? 0) as num).toDouble(),
      taxNote: (map['taxNote'] ?? '') as String,
      deliveryCharge: ((map['deliveryCharge'] ?? 0) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'price': price,
        'taxNote': taxNote,
        'deliveryCharge': deliveryCharge,
      };
}

class ProductModel {
  final String id;
  final String name;
  final String origin;
  final bool active;
  final List<ProductPack> packs;
  final List<String> highlights;
  final String posterCaptionMl;
  final String posterCaptionEn;
  final String posterCaptionManglish;

  const ProductModel({
    required this.id,
    required this.name,
    this.origin = '',
    this.active = true,
    required this.packs,
    this.highlights = const [],
    this.posterCaptionMl = '',
    this.posterCaptionEn = '',
    this.posterCaptionManglish = '',
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    final rawPacks = (map['packs'] as List<dynamic>? ?? []);
    final rawHighlights = (map['highlights'] as List<dynamic>? ?? []);
    final legacyCaption = (map['posterCaption'] ?? '') as String;
    return ProductModel(
      id: id,
      name: (map['name'] ?? '') as String,
      origin: (map['origin'] ?? '') as String,
      active: (map['active'] ?? true) as bool,
      packs: rawPacks
          .map((e) => ProductPack.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      highlights: rawHighlights.map((e) => e.toString()).toList(),
      posterCaptionMl: (map['posterCaptionMl'] ?? legacyCaption) as String,
      posterCaptionEn: (map['posterCaptionEn'] ?? '') as String,
      posterCaptionManglish: (map['posterCaptionManglish'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'origin': origin,
        'active': active,
        'packs': packs.map((e) => e.toMap()).toList(),
        'highlights': highlights,
        'posterCaptionMl': posterCaptionMl,
        'posterCaptionEn': posterCaptionEn,
        'posterCaptionManglish': posterCaptionManglish,
      };
}
