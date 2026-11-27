import '../models/business_profile.dart';
import '../models/product_model.dart';

class TemplateEngine {
  static String formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String buildProductListText(List<ProductModel> products,
      {ProductModel? selectedProduct}) {
    final list = selectedProduct != null
        ? [selectedProduct]
        : products.where((p) => p.active).toList();
    if (list.isEmpty) return 'Products will be updated soon.';

    final buffer = StringBuffer();
    int idx = 1;
    for (final product in list) {
      for (final pack in product.packs) {
        final taxText = pack.taxNote.isNotEmpty ? ' *(${pack.taxNote})*' : '';
        final deliveryText = pack.deliveryCharge <= 0
            ? '• *Free Delivery*'
            : '• Delivery Charge: ${formatMoney(pack.deliveryCharge)}';

        buffer.writeln('*$idx. ${product.name} (${pack.label})*');
        buffer.writeln('• Price: ${formatMoney(pack.price)} only$taxText');
        buffer.writeln(deliveryText);
        buffer.writeln();
        idx++;
      }
      if (product.highlights.isNotEmpty) {
        buffer.writeln('✨ *Highlights:*');
        for (final h in product.highlights) {
          buffer.writeln(h);
        }
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  static String render({
    required String templateBody,
    required BusinessProfile profile,
    required List<ProductModel> products,
    ProductModel? selectedProduct,
    double subtotal = 0,
    double deliveryCharge = 0,
    double totalAmount = 0,
    String packSummary = '',
    String trackingId = 'RXXXXXXXXXX',
  }) {
    final activeProd = selectedProduct ??
        (products.isNotEmpty ? products.first : null);
    final deliveryLine =
        deliveryCharge <= 0 ? '*Free Delivery*' : formatMoney(deliveryCharge);

    final replacements = <String, String>{
      '{{brand_name}}': profile.brandName,
      '{{tagline}}': profile.tagline,
      '{{phone}}': profile.phone,
      '{{website}}': profile.website,
      '{{instagram_handle}}': profile.instagramHandle,
      '{{instagram_url}}': profile.instagramUrl,
      '{{review_url}}': profile.reviewUrl,
      '{{courier_name}}': profile.courierName,
      '{{tracking_url}}': profile.trackingUrl,
      '{{payment_bank}}': profile.paymentBankLabel,
      '{{product_name}}': activeProd?.name ?? profile.brandName,
      '{{product_origin}}': activeProd?.origin ?? '',
      '{{product_highlights}}': activeProd?.highlights.join('\n') ?? '',
      '{{product_list}}': buildProductListText(
        products,
        selectedProduct: selectedProduct,
      ),
      '{{subtotal}}': formatMoney(subtotal),
      '{{delivery_charge}}': deliveryLine,
      '{{total_amount}}': formatMoney(totalAmount),
      '{{pack_summary}}': packSummary.isNotEmpty
          ? packSummary
          : (activeProd?.name ?? 'Order'),
      '{{tracking_id}}':
          trackingId.trim().isEmpty ? 'RXXXXXXXXXX' : trackingId.trim(),
    };

    // Inject all dynamic Custom Business Profile fields!
    for (final cf in profile.customFields) {
      if (cf.key.isNotEmpty) {
        replacements['{{${cf.key}}}'] = cf.value;
      }
    }

    var output = templateBody;
    replacements.forEach((key, value) {
      output = output.replaceAll(key, value);
    });
    return output;
  }

  static List<String> allAvailableVariables(BusinessProfile profile) {
    final base = [
      '{{brand_name}}',
      '{{tagline}}',
      '{{product_name}}',
      '{{product_list}}',
      '{{product_origin}}',
      '{{product_highlights}}',
      '{{subtotal}}',
      '{{delivery_charge}}',
      '{{total_amount}}',
      '{{pack_summary}}',
      '{{tracking_id}}',
      '{{tracking_url}}',
      '{{courier_name}}',
      '{{payment_bank}}',
      '{{review_url}}',
      '{{website}}',
      '{{instagram_handle}}',
      '{{instagram_url}}',
    ];
    for (final cf in profile.customFields) {
      if (cf.key.isNotEmpty) {
        base.add('{{${cf.key}}}');
      }
    }
    return base;
  }
}
