enum DeliveryMode {
  perPack,
  cartThreshold,
  flatPerOrder,
}

class DeliveryRules {
  final DeliveryMode mode;
  final double flatCharge;
  final double freeThresholdAmount;
  final double belowThresholdCharge;

  const DeliveryRules({
    this.mode = DeliveryMode.perPack,
    this.flatCharge = 50,
    this.freeThresholdAmount = 1000,
    this.belowThresholdCharge = 50,
  });

  factory DeliveryRules.fromMap(Map<String, dynamic> map) {
    final modeStr = (map['mode'] ?? 'per_pack') as String;
    DeliveryMode parsedMode;
    switch (modeStr) {
      case 'cart_threshold':
        parsedMode = DeliveryMode.cartThreshold;
        break;
      case 'flat_per_order':
        parsedMode = DeliveryMode.flatPerOrder;
        break;
      default:
        parsedMode = DeliveryMode.perPack;
    }
    return DeliveryRules(
      mode: parsedMode,
      flatCharge: ((map['flatCharge'] ?? 50) as num).toDouble(),
      freeThresholdAmount:
          ((map['freeThresholdAmount'] ?? 1000) as num).toDouble(),
      belowThresholdCharge:
          ((map['belowThresholdCharge'] ?? 50) as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    String modeStr;
    switch (mode) {
      case DeliveryMode.cartThreshold:
        modeStr = 'cart_threshold';
        break;
      case DeliveryMode.flatPerOrder:
        modeStr = 'flat_per_order';
        break;
      case DeliveryMode.perPack:
        modeStr = 'per_pack';
        break;
    }
    return {
      'mode': modeStr,
      'flatCharge': flatCharge,
      'freeThresholdAmount': freeThresholdAmount,
      'belowThresholdCharge': belowThresholdCharge,
    };
  }
}
