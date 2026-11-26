import '../models/business_profile.dart';
import '../models/product_model.dart';

class TemplateEngine {
  static String formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String buildProductListText(List<ProductModel> products) {
    final activeProducts = products.where((p) => p.active).toList();
    if (activeProducts.isEmpty) return 'Products will be updated soon.';

    final buffer = StringBuffer();
    int idx = 1;
    for (final product in activeProducts) {
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
    double subtotal = 0,
    double deliveryCharge = 0,
    double totalAmount = 0,
    String packSummary = '',
    String trackingId = 'RXXXXXXXXXX',
  }) {
    final deliveryLine = deliveryCharge <= 0
        ? '*Free Delivery*'
        : formatMoney(deliveryCharge);

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
      '{{product_list}}': buildProductListText(products),
      '{{subtotal}}': formatMoney(subtotal),
      '{{delivery_charge}}': deliveryLine,
      '{{total_amount}}': formatMoney(totalAmount),
      '{{pack_summary}}':
          packSummary.isNotEmpty ? packSummary : (products.isNotEmpty ? products.first.name : 'Order'),
      '{{tracking_id}}': trackingId.trim().isEmpty ? 'RXXXXXXXXXX' : trackingId.trim(),
    };

    var output = templateBody;
    replacements.forEach((key, value) {
      output = output.replaceAll(key, value);
    });
    return output;
  }
}
