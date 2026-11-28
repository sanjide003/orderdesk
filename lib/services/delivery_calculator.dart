import '../models/delivery_rules.dart';
import '../models/order_model.dart';

class PriceBreakdown {
  final double subtotal;
  final double discountPercent;
  final double discountAmount;
  final double discountedSubtotal;
  final double deliveryCharge;
  final double total;

  const PriceBreakdown({
    required this.subtotal,
    this.discountPercent = 0,
    this.discountAmount = 0,
    double? discountedSubtotal,
    required this.deliveryCharge,
    required this.total,
  }) : discountedSubtotal = discountedSubtotal ?? subtotal;
}

class DeliveryCalculator {
  static double _round2(double v) => (v * 100).round() / 100.0;

  static PriceBreakdown calculate({
    required List<OrderItem> items,
    required DeliveryRules rules,
    double? manualDeliveryOverride,
    double? discountPercent,
    double? discountFlatAmount,
  }) {
    final subtotal =
        _round2(items.fold<double>(0, (sum, item) => sum + item.lineSubtotal));
    if (items.isEmpty) {
      return const PriceBreakdown(
        subtotal: 0,
        discountPercent: 0,
        discountAmount: 0,
        discountedSubtotal: 0,
        deliveryCharge: 0,
        total: 0,
      );
    }

    double resolvedPercent = 0;
    double resolvedDiscount = 0;
    if (discountPercent != null && discountPercent > 0) {
      resolvedPercent = discountPercent.clamp(0.0, 100.0).toDouble();
      resolvedDiscount = _round2(subtotal * resolvedPercent / 100.0);
    } else if (discountFlatAmount != null && discountFlatAmount > 0) {
      resolvedDiscount = _round2(discountFlatAmount.clamp(0.0, subtotal));
    }
    resolvedDiscount = resolvedDiscount.clamp(0.0, subtotal).toDouble();
    final discountedSubtotal =
        _round2((subtotal - resolvedDiscount).clamp(0.0, subtotal));

    if (manualDeliveryOverride != null) {
      final delivery = _round2(manualDeliveryOverride < 0 ? 0 : manualDeliveryOverride);
      return PriceBreakdown(
        subtotal: subtotal,
        discountPercent: resolvedPercent,
        discountAmount: resolvedDiscount,
        discountedSubtotal: discountedSubtotal,
        deliveryCharge: delivery,
        total: _round2(discountedSubtotal + delivery),
      );
    }

    double delivery = 0;
    switch (rules.mode) {
      case DeliveryMode.perPack:
        delivery = items.fold<double>(0, (sum, item) => sum + item.lineDelivery);
        break;
      case DeliveryMode.cartThreshold:
        delivery = discountedSubtotal >= rules.freeThresholdAmount
            ? 0
            : rules.belowThresholdCharge;
        break;
      case DeliveryMode.flatPerOrder:
        delivery = rules.flatCharge;
        break;
    }
    delivery = _round2(delivery < 0 ? 0 : delivery);
    return PriceBreakdown(
      subtotal: subtotal,
      discountPercent: resolvedPercent,
      discountAmount: resolvedDiscount,
      discountedSubtotal: discountedSubtotal,
      deliveryCharge: delivery,
      total: _round2(discountedSubtotal + delivery),
    );
  }
}
