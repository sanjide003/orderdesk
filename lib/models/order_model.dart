import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String productName;
  final String packLabel;
  final double unitPrice;
  final double packDeliveryCharge;
  final int quantity;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.packLabel,
    required this.unitPrice,
    required this.packDeliveryCharge,
    required this.quantity,
  });

  double get lineSubtotal => unitPrice * quantity;
  double get lineDelivery => packDeliveryCharge * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: (map['productId'] ?? '') as String,
      productName: (map['productName'] ?? '') as String,
      packLabel: (map['packLabel'] ?? '') as String,
      unitPrice: ((map['unitPrice'] ?? 0) as num).toDouble(),
      packDeliveryCharge: ((map['packDeliveryCharge'] ?? 0) as num).toDouble(),
      quantity: (map['quantity'] ?? 1) as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'packLabel': packLabel,
        'unitPrice': unitPrice,
        'packDeliveryCharge': packDeliveryCharge,
        'quantity': quantity,
      };
}

class OrderModel {
  final String id;
  final String customerName;
  final String phone;
  final String address;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double totalAmount;
  final String status;
  final String trackingId;
  final bool reviewSent;
  final DateTime createdAt;
  final DateTime? dispatchedAt;

  static const List<String> statuses = [
    'New Inquiry',
    'Address Received',
    'Payment Pending',
    'Paid',
    'Dispatched',
    'Delivered',
    'Review Sent',
  ];

  const OrderModel({
    required this.id,
    required this.customerName,
    required this.phone,
    this.address = '',
    required this.items,
    required this.subtotal,
    required this.deliveryCharge,
    required this.totalAmount,
    this.status = 'New Inquiry',
    this.trackingId = '',
    this.reviewSent = false,
    required this.createdAt,
    this.dispatchedAt,
  });

  bool get isReviewDue {
    if (reviewSent || dispatchedAt == null) return false;
    return DateTime.now().difference(dispatchedAt!).inDays >= 4;
  }

  bool get isPaidOrBeyond =>
      status == 'Paid' ||
      status == 'Dispatched' ||
      status == 'Delivered' ||
      status == 'Review Sent';

  String get itemsSummary =>
      items.map((e) => '${e.productName} (${e.packLabel}) x${e.quantity}').join(', ');

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? []);
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return OrderModel(
      id: id,
      customerName: (map['customerName'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
      deliveryCharge: ((map['deliveryCharge'] ?? 0) as num).toDouble(),
      totalAmount: ((map['totalAmount'] ?? 0) as num).toDouble(),
      status: (map['status'] ?? 'New Inquiry') as String,
      trackingId: (map['trackingId'] ?? '') as String,
      reviewSent: (map['reviewSent'] ?? false) as bool,
      createdAt: parseDate(map['createdAt']),
      dispatchedAt:
          map['dispatchedAt'] != null ? parseDate(map['dispatchedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'phone': phone,
        'address': address,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'deliveryCharge': deliveryCharge,
        'totalAmount': totalAmount,
        'status': status,
        'trackingId': trackingId,
        'reviewSent': reviewSent,
        'createdAt': Timestamp.fromDate(createdAt),
        'dispatchedAt':
            dispatchedAt != null ? Timestamp.fromDate(dispatchedAt!) : null,
      };
}
