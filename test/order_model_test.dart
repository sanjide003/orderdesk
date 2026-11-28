import 'package:flutter_test/flutter_test.dart';
import 'package:orderdesk/models/order_model.dart';

void main() {
  group('OrderModel separated payment & fulfillment status', () {
    test('migrates legacy Paid status to Confirmed + Paid', () {
      final (status, payStatus, paidAmt) = OrderModel.resolveLegacyStatuses(
        rawStatus: 'Paid',
        totalAmount: 900,
      );
      expect(status, 'Confirmed');
      expect(payStatus, 'Paid');
      expect(paidAmt, 900);
    });

    test('migrates legacy Payment Pending to Address Received + Pending', () {
      final (status, payStatus, paidAmt) = OrderModel.resolveLegacyStatuses(
        rawStatus: 'Payment Pending',
        totalAmount: 900,
      );
      expect(status, 'Address Received');
      expect(payStatus, 'Pending');
      expect(paidAmt, 0);
    });

    test('keeps Dispatched independent when paymentStatus is Pending', () {
      final (status, payStatus, paidAmt) = OrderModel.resolveLegacyStatuses(
        rawStatus: 'Dispatched',
        rawPaymentStatus: 'Pending',
        rawPaidAmount: 0,
        totalAmount: 1200,
      );
      expect(status, 'Dispatched');
      expect(payStatus, 'Pending');
      expect(paidAmt, 0);
    });

    test('computes Partial payment balanceDue and effectivePaidAmount accurately', () {
      final order = OrderModel(
        id: 'ord_1',
        customerName: 'Amina',
        phone: '9876543210',
        items: const [],
        subtotal: 1000,
        deliveryCharge: 0,
        totalAmount: 1000,
        status: 'Dispatched',
        paymentStatus: 'Partial',
        paidAmount: 400,
        createdAt: DateTime(2026, 11, 28),
      );
      expect(order.isPaymentPending, true);
      expect(order.isPartialPaid, true);
      expect(order.effectivePaidAmount, 400);
      expect(order.balanceDue, 600);
    });
  });
}
