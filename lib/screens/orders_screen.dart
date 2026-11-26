import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/whatsapp_service.dart';

class OrdersScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final List<OrderModel> orders;
  final AppStrings s;

  const OrdersScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.products,
    required this.templates,
    required this.orders,
    required this.s,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'All';
  String _query = '';

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green.shade700;
      case 'Dispatched':
        return Colors.blue.shade700;
      case 'Delivered':
      case 'Review Sent':
        return Colors.teal.shade700;
      case 'Payment Pending':
        return Colors.orange.shade800;
      default:
        return Colors.blueGrey.shade700;
    }
  }

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
    final s = widget.s;
    final ctrl = TextEditingController(text: order.trackingId);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('dispatch_order')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: s.t('tracking_id'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(s.t('save_and_whatsapp')),
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

  Future<void> _confirmDelete(OrderModel order) async {
    final s = widget.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('confirm_delete')),
        content: Text(s.t('delete_order_q')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.service.deleteOrder(order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final q = _query.trim().toLowerCase();
    final filtered = widget.orders.where((o) {
      final matchesFilter = _filter == 'All'
          ? true
          : (_filter == 'Review Due' ? o.isReviewDue : o.status == _filter);
      if (!matchesFilter) return false;
      if (q.isEmpty) return true;
      return o.customerName.toLowerCase().contains(q) ||
          o.phone.toLowerCase().contains(q) ||
          o.trackingId.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: s.t('search_orders'),
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black12),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: ['All', 'Review Due', ...OrderModel.statuses].map((st) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(st, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  selected: _filter == st,
                  onSelected: (_) => setState(() => _filter = st),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(s.t('no_orders_yet'),
                      style: TextStyle(color: Colors.grey.shade600)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final o = filtered[i];
                    final badgeColor = _statusColor(o.status);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${o.customerName} • ${o.phone}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  o.status,
                                  style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (o.itemsSummary.isNotEmpty)
                            Text(o.itemsSummary,
                                style: const TextStyle(fontSize: 12)),
                          Text(
                            '${TemplateEngine.formatMoney(o.totalAmount)}  •  ${DateFormat('dd MMM, hh:mm a').format(o.createdAt)}',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 11),
                          ),
                          if (o.address.isNotEmpty)
                            Text(o.address,
                                style: TextStyle(
                                    color: Colors.grey.shade700, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          if (o.trackingId.isNotEmpty)
                            Text('Tracking: ${o.trackingId}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 11)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _ActionPill(
                                label: s.t('send_payment'),
                                icon: Icons.qr_code_2,
                                onTap: () => _sendStageReply(o, 'payment'),
                              ),
                              _ActionPill(
                                label: s.t('mark_paid'),
                                icon: Icons.check_circle_outline,
                                onTap: () async {
                                  await widget.service.updateOrderStatus(
                                      orderId: o.id, status: 'Paid');
                                  await _sendStageReply(o, 'paid');
                                },
                              ),
                              _ActionPill(
                                label: s.t('dispatch'),
                                icon: Icons.local_shipping_outlined,
                                highlighted: true,
                                onTap: () => _dispatchDialog(o),
                              ),
                              _ActionPill(
                                label: s.t('send_review'),
                                icon: Icons.star_outline,
                                onTap: () async {
                                  await widget.service.updateOrderStatus(
                                    orderId: o.id,
                                    status: 'Review Sent',
                                    reviewSent: true,
                                  );
                                  await _sendStageReply(o, 'review');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.call_outlined, size: 18),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    WhatsAppService.callPhone(o.phone),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmDelete(o),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: highlighted ? cs.primary : const Color(0xFFF1F5F4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14, color: highlighted ? Colors.white : cs.onSurface),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: highlighted ? Colors.white : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
