import '../models/delivery_rules.dart';
import '../models/order_model.dart';

class PriceBreakdown {
  final double subtotal;
  final double deliveryCharge;
  final double total;

  const PriceBreakdown({
    required this.subtotal,
    required this.deliveryCharge,
    required this.total,
  });
}

class DeliveryCalculator {
  static PriceBreakdown calculate({
    required List<OrderItem> items,
    required DeliveryRules rules,
    double? manualDeliveryOverride,
  }) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.lineSubtotal);
    if (items.isEmpty) {
      return const PriceBreakdown(subtotal: 0, deliveryCharge: 0, total: 0);
    }
    if (manualDeliveryOverride != null) {
      return PriceBreakdown(
        subtotal: subtotal,
        deliveryCharge: manualDeliveryOverride,
        total: subtotal + manualDeliveryOverride,
      );
    }
    double delivery = 0;
    switch (rules.mode) {
      case DeliveryMode.perPack:
        delivery = items.fold<double>(0, (sum, item) => sum + item.lineDelivery);
        break;
      case DeliveryMode.cartThreshold:
        delivery = subtotal >= rules.freeThresholdAmount
            ? 0
            : rules.belowThresholdCharge;
        break;
      case DeliveryMode.flatPerOrder:
        delivery = rules.flatCharge;
        break;
    }
    return PriceBreakdown(
      subtotal: subtotal,
      deliveryCharge: delivery,
      total: subtotal + delivery,
    );
  }
}
