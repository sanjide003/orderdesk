import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class TemplateEngine {
  static String formatMoney(double amount) {
    if (amount == amount.roundToDouble()) {
      return '₹${amount.toInt()}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String formatDiscount(double discountAmount,
      {double discountPercent = 0}) {
    if (discountAmount <= 0) return '₹0';
    if (discountPercent > 0) {
      final pctText = discountPercent == discountPercent.roundToDouble()
          ? '${discountPercent.toInt()}%'
          : '${discountPercent.toStringAsFixed(1)}%';
      return '-${formatMoney(discountAmount)} ($pctText)';
    }
    return '-${formatMoney(discountAmount)}';
  }

  static String buildOrderItemsText(List<OrderItem> items) {
    if (items.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rate = formatMoney(item.unitPrice);
      final lineTotal = formatMoney(item.lineSubtotal);
      buffer.writeln(
        '${i + 1}. ${item.productName} (${item.packLabel}) — $rate × ${item.quantity} = *$lineTotal*',
      );
    }
    return buffer.toString().trim();
  }

  static String buildOrderBillBlock({
    required List<OrderItem> items,
    required double subtotal,
    double discountAmount = 0,
    double discountPercent = 0,
    required double deliveryCharge,
    required double totalAmount,
    String packSummary = '',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*Order Summary*');
    if (items.isNotEmpty) {
      buffer.writeln(buildOrderItemsText(items));
    } else if (packSummary.trim().isNotEmpty) {
      buffer.writeln('• $packSummary');
    }
    buffer.writeln();
    buffer.writeln('• Product Total: ${formatMoney(subtotal)}');
    buffer.writeln(
      '• Discount: ${formatDiscount(discountAmount, discountPercent: discountPercent)}',
    );
    final deliveryLine =
        deliveryCharge <= 0 ? '*Free Delivery*' : formatMoney(deliveryCharge);
    buffer.writeln('• Delivery Charge: $deliveryLine');
    buffer.writeln('• *Grand Total: ${formatMoney(totalAmount)}*');
    return buffer.toString().trim();
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
    List<OrderItem> orderItems = const [],
    double subtotal = 0,
    double discountAmount = 0,
    double discountPercent = 0,
    double deliveryCharge = 0,
    double totalAmount = 0,
    double paidAmount = 0,
    double balanceDue = 0,
    String customerName = '',
    String customerPhone = '',
    String customerAddress = '',
    String packSummary = '',
    String trackingId = 'RXXXXXXXXXX',
    bool includeOrderBillHeader = false,
  }) {
    final activeProd = selectedProduct ??
        (products.isNotEmpty ? products.first : null);
    final deliveryLine =
        deliveryCharge <= 0 ? '*Free Delivery*' : formatMoney(deliveryCharge);
    final itemsText = orderItems.isNotEmpty
        ? buildOrderItemsText(orderItems)
        : (packSummary.isNotEmpty
            ? '• $packSummary'
            : (activeProd?.name ?? 'Order'));
    final billBlock = buildOrderBillBlock(
      items: orderItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      discountPercent: discountPercent,
      deliveryCharge: deliveryCharge,
      totalAmount: totalAmount,
      packSummary: packSummary,
    );
    final discountLine = formatDiscount(
      discountAmount,
      discountPercent: discountPercent,
    );

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
      '{{customer_name}}':
          customerName.trim().isEmpty ? 'Customer' : customerName.trim(),
      '{{customer_phone}}': customerPhone.trim(),
      '{{customer_address}}': customerAddress.trim(),
      '{{product_name}}': activeProd?.name ?? profile.brandName,
      '{{product_origin}}': activeProd?.origin ?? '',
      '{{product_highlights}}': activeProd?.highlights.join('\n') ?? '',
      '{{product_list}}': buildProductListText(
        products,
        selectedProduct: selectedProduct,
      ),
      '{{order_items}}': itemsText,
      '{{order_bill}}': billBlock,
      '{{discount}}': discountLine,
      '{{subtotal}}': formatMoney(subtotal),
      '{{delivery_charge}}': deliveryLine,
      '{{total_amount}}': formatMoney(totalAmount),
      '{{paid_amount}}': formatMoney(paidAmount),
      '{{balance_due}}': formatMoney(balanceDue),
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

    final hasBillPlaceholder = templateBody.contains('{{order_bill}}') ||
        templateBody.contains('{{order_items}}');

    var output = templateBody;
    replacements.forEach((key, value) {
      output = output.replaceAll(key, value);
    });

    if (includeOrderBillHeader &&
        orderItems.isNotEmpty &&
        !hasBillPlaceholder) {
      output = '$billBlock\n\n$output';
    }
    return output;
  }

  static List<String> allAvailableVariables(BusinessProfile profile) {
    final base = [
      '{{customer_name}}',
      '{{brand_name}}',
      '{{tagline}}',
      '{{product_name}}',
      '{{product_list}}',
      '{{product_origin}}',
      '{{product_highlights}}',
      '{{order_bill}}',
      '{{order_items}}',
      '{{subtotal}}',
      '{{discount}}',
      '{{delivery_charge}}',
      '{{total_amount}}',
      '{{paid_amount}}',
      '{{balance_due}}',
      '{{pack_summary}}',
      '{{tracking_id}}',
      '{{tracking_url}}',
      '{{courier_name}}',
      '{{payment_bank}}',
      '{{review_url}}',
      '{{website}}',
      '{{instagram_handle}}',
      '{{instagram_url}}',
      '{{customer_phone}}',
      '{{customer_address}}',
    ];
    for (final cf in profile.customFields) {
      if (cf.key.isNotEmpty) {
        base.add('{{${cf.key}}}');
      }
    }
    return base;
  }
}
