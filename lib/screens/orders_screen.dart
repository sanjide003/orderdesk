import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/whatsapp_service.dart';

class OrdersScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final List<ProductModel> products;
  final List<TemplateModel> templates;

  const OrdersScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.products,
    required this.templates,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'All';

  TemplateModel? _findTemplate(String stage) {
    try {
      return widget.templates.firstWhere((t) => t.stage == stage);
    } catch (_) {
      return widget.templates.isNotEmpty ? widget.templates.first : null;
    }
  }

  Future<void> _sendStageReply(OrderModel order, String stage,
      {String? trackingOverride}) async {
    final tpl = _findTemplate(stage);
    if (tpl == null) return;
    final msg = TemplateEngine.render(
      templateBody: tpl.body,
      profile: widget.profile,
      products: widget.products,
      subtotal: order.subtotal,
      deliveryCharge: order.deliveryCharge,
      totalAmount: order.totalAmount,
      packSummary: order.itemsSummary,
      trackingId: trackingOverride ?? order.trackingId,
    );
    await WhatsAppService.openDirectChat(phone: order.phone, message: msg);
  }

  Future<void> _dispatchDialog(OrderModel order) async {
    final ctrl = TextEditingController(text: order.trackingId);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispatch Order'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'DTDC / Courier Tracking ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save & WhatsApp'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await widget.service.updateOrderStatus(
        orderId: order.id,
        status: 'Dispatched',
        trackingId: result,
      );
      await _sendStageReply(order, 'dispatched', trackingOverride: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: widget.service.watchOrders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? [];
        final filtered = orders.where((o) {
          if (_filter == 'All') return true;
          if (_filter == 'Review Due') return o.isReviewDue;
          return o.status == _filter;
        }).toList();

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: ['All', 'Review Due', ...OrderModel.statuses]
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: _filter == s,
                            onSelected: (_) => setState(() => _filter = s),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('ഓർഡറുകൾ ഒന്നും ഇല്ല'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final o = filtered[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${o.customerName} (${o.phone})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Chip(
                                      label: Text(o.status,
                                          style: const TextStyle(fontSize: 12)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                if (o.itemsSummary.isNotEmpty)
                                  Text(o.itemsSummary),
                                Text(
                                  'Total: ${TemplateEngine.formatMoney(o.totalAmount)} • ${DateFormat('dd MMM, hh:mm a').format(o.createdAt)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                if (o.trackingId.isNotEmpty)
                                  Text('Tracking: ${o.trackingId}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () async {
                                        await widget.service.updateOrderStatus(
                                            orderId: o.id, status: 'Paid');
                                        await _sendStageReply(o, 'paid');
                                      },
                                      child: const Text('Confirm Paid'),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () => _dispatchDialog(o),
                                      child: const Text('Dispatch'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () async {
                                        await widget.service.updateOrderStatus(
                                          orderId: o.id,
                                          status: 'Review Sent',
                                          reviewSent: true,
                                        );
                                        await _sendStageReply(o, 'review');
                                      },
                                      child: const Text('Send Review'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
