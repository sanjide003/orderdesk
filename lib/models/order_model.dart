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
  final double discountPercent;
  final double discountAmount;
  final double deliveryCharge;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final double paidAmount;
  final DateTime? paidAt;
  final String trackingId;
  final String notes;
  final bool reviewSent;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? dispatchedAt;
  final DateTime? deletedAt;

  static const List<String> statuses = [
    'New Inquiry',
    'Address Received',
    'Confirmed',
    'Dispatched',
    'Delivered',
    'Review Sent',
  ];

  static const List<String> paymentStatuses = [
    'Pending',
    'Paid',
    'Partial',
  ];

  const OrderModel({
    required this.id,
    required this.customerName,
    required this.phone,
    this.address = '',
    required this.items,
    required this.subtotal,
    this.discountPercent = 0,
    this.discountAmount = 0,
    required this.deliveryCharge,
    required this.totalAmount,
    this.status = 'New Inquiry',
    this.paymentStatus = 'Pending',
    this.paidAmount = 0,
    this.paidAt,
    this.trackingId = '',
    this.notes = '',
    this.reviewSent = false,
    this.isDeleted = false,
    required this.createdAt,
    this.dispatchedAt,
    this.deletedAt,
  });

  bool get isReviewDue {
    if (reviewSent || dispatchedAt == null) return false;
    return DateTime.now().difference(dispatchedAt!).inDays >= 4;
  }

  bool get isPaid => paymentStatus == 'Paid';
  bool get isPartialPaid => paymentStatus == 'Partial';
  bool get isPaymentPending => paymentStatus != 'Paid';
  bool get isPaidOrBeyond => paymentStatus == 'Paid';

  double get effectivePaidAmount {
    if (paymentStatus == 'Paid') {
      return paidAmount > 0 ? paidAmount : totalAmount;
    }
    if (paymentStatus == 'Partial') {
      return paidAmount.clamp(0.0, totalAmount);
    }
    return 0.0;
  }

  double get balanceDue =>
      (totalAmount - effectivePaidAmount).clamp(0.0, totalAmount);

  String get itemsSummary =>
      items.map((e) => '${e.productName} (${e.packLabel}) x${e.quantity}').join(', ');

  OrderModel copyWith({
    String? id,
    String? customerName,
    String? phone,
    String? address,
    List<OrderItem>? items,
    double? subtotal,
    double? discountPercent,
    double? discountAmount,
    double? deliveryCharge,
    double? totalAmount,
    String? status,
    String? paymentStatus,
    double? paidAmount,
    DateTime? paidAt,
    String? trackingId,
    String? notes,
    bool? reviewSent,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? dispatchedAt,
    DateTime? deletedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      paidAt: paidAt ?? this.paidAt,
      trackingId: trackingId ?? this.trackingId,
      notes: notes ?? this.notes,
      reviewSent: reviewSent ?? this.reviewSent,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static (String status, String paymentStatus, double paidAmount)
      resolveLegacyStatuses({
    required String rawStatus,
    String? rawPaymentStatus,
    double? rawPaidAmount,
    required double totalAmount,
  }) {
    String resolvedStatus;
    String resolvedPayment;
    double resolvedPaidAmt;

    if (rawPaymentStatus == null || rawPaymentStatus.trim().isEmpty) {
      if (rawStatus == 'Paid') {
        resolvedStatus = 'Confirmed';
        resolvedPayment = 'Paid';
        resolvedPaidAmt = rawPaidAmount ?? totalAmount;
      } else if (rawStatus == 'Payment Pending') {
        resolvedStatus = 'Address Received';
        resolvedPayment = 'Pending';
        resolvedPaidAmt = 0;
      } else if (rawStatus == 'Dispatched' ||
          rawStatus == 'Delivered' ||
          rawStatus == 'Review Sent') {
        resolvedStatus = rawStatus;
        resolvedPayment = 'Paid';
        resolvedPaidAmt = rawPaidAmount ?? totalAmount;
      } else {
        resolvedStatus =
            statuses.contains(rawStatus) ? rawStatus : 'New Inquiry';
        resolvedPayment = 'Pending';
        resolvedPaidAmt = 0;
      }
    } else {
      resolvedPayment = paymentStatuses.contains(rawPaymentStatus)
          ? rawPaymentStatus
          : 'Pending';
      if (rawStatus == 'Paid') {
        resolvedStatus = 'Confirmed';
      } else if (rawStatus == 'Payment Pending') {
        resolvedStatus = 'Address Received';
      } else {
        resolvedStatus =
            statuses.contains(rawStatus) ? rawStatus : 'New Inquiry';
      }
      if (resolvedPayment == 'Paid') {
        resolvedPaidAmt = (rawPaidAmount != null && rawPaidAmount > 0)
            ? rawPaidAmount
            : totalAmount;
      } else if (resolvedPayment == 'Partial') {
        resolvedPaidAmt = (rawPaidAmount ?? 0).clamp(0.0, totalAmount);
      } else {
        resolvedPaidAmt = 0;
      }
    }

    return (resolvedStatus, resolvedPayment, resolvedPaidAmt);
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? []);
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    final total = ((map['totalAmount'] ?? 0) as num).toDouble();
    final rawStatus = (map['status'] ?? 'New Inquiry') as String;
    final rawPaymentStatus = map['paymentStatus'] as String?;
    final rawPaidAmt = map['paidAmount'] != null
        ? (map['paidAmount'] as num).toDouble()
        : null;

    final (resolvedStatus, resolvedPayment, resolvedPaidAmt) =
        resolveLegacyStatuses(
      rawStatus: rawStatus,
      rawPaymentStatus: rawPaymentStatus,
      rawPaidAmount: rawPaidAmt,
      totalAmount: total,
    );

    return OrderModel(
      id: id,
      customerName: (map['customerName'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: ((map['subtotal'] ?? 0) as num).toDouble(),
      discountPercent: ((map['discountPercent'] ?? 0) as num).toDouble(),
      discountAmount: ((map['discountAmount'] ?? 0) as num).toDouble(),
      deliveryCharge: ((map['deliveryCharge'] ?? 0) as num).toDouble(),
      totalAmount: total,
      status: resolvedStatus,
      paymentStatus: resolvedPayment,
      paidAmount: resolvedPaidAmt,
      paidAt: map['paidAt'] != null ? parseDate(map['paidAt']) : null,
      trackingId: (map['trackingId'] ?? '') as String,
      notes: (map['notes'] ?? '') as String,
      reviewSent: (map['reviewSent'] ?? false) as bool,
      isDeleted: (map['isDeleted'] ?? false) as bool,
      createdAt: parseDate(map['createdAt']),
      dispatchedAt:
          map['dispatchedAt'] != null ? parseDate(map['dispatchedAt']) : null,
      deletedAt:
          map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'phone': phone,
        'address': address,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'discountPercent': discountPercent,
        'discountAmount': discountAmount,
        'deliveryCharge': deliveryCharge,
        'totalAmount': totalAmount,
        'status': status,
        'paymentStatus': paymentStatus,
        'paidAmount': paidAmount,
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
        'trackingId': trackingId,
        'notes': notes,
        'reviewSent': reviewSent,
        'isDeleted': isDeleted,
        'createdAt': Timestamp.fromDate(createdAt),
        'dispatchedAt':
            dispatchedAt != null ? Timestamp.fromDate(dispatchedAt!) : null,
        'deletedAt':
            deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      };
}
