import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';
import '../services/whatsapp_service.dart';
import 'bin_screen.dart';

class OrdersScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final List<OrderModel> orders;
  final AppStrings s;
  final VoidCallback? onOpenBin;

  const OrdersScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.products,
    required this.templates,
    required this.orders,
    required this.s,
    this.onOpenBin,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filterStatus = ''; // '' = All
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openStatusDialog(OrderModel order) async {
    final s = widget.s;
    String selectedStatus = order.status;
    final trackingCtrl = TextEditingController(text: order.trackingId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.t('change_status_title'),
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: OrderModel.statuses.contains(selectedStatus)
                      ? selectedStatus
                      : OrderModel.statuses.first,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: s.t('update_status'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: OrderModel.statuses
                      .map((st) => DropdownMenuItem(value: st, child: Text(st)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedStatus = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: trackingCtrl,
                  decoration: InputDecoration(
                    labelText: s.t('tracking_id'),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('change_status_q'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.t('confirm')),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await widget.service.updateOrderStatus(
          orderId: order.id,
          status: selectedStatus,
          trackingId: trackingCtrl.text.trim(),
        );
        if (mounted) {
          UiHelpers.showFeedback(context, s.t('status_updated'));
        }
      } catch (_) {
        if (mounted) {
          UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
        }
      }
    }
  }

  Future<void> _openEditOrderSheet(OrderModel order) async {
    final s = widget.s;
    final nameCtrl = TextEditingController(text: order.customerName);
    final phoneCtrl = TextEditingController(text: order.phone);
    final addrCtrl = TextEditingController(text: order.address);
    final trackCtrl = TextEditingController(text: order.trackingId);
    final notesCtrl = TextEditingController(text: order.notes);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.t('edit_order'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: s.t('customer_name'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: s.t('whatsapp_number'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addrCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.t('delivery_address'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: trackCtrl,
                decoration: InputDecoration(
                  labelText: s.t('tracking_id'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: s.t('notes'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  final ok = await UiHelpers.confirmDialog(
                    ctx,
                    title: s.t('confirm_save'),
                    message: s.t('save_changes_q'),
                    confirmLabel: s.t('save'),
                    cancelLabel: s.t('cancel'),
                  );
                  if (!ok) return;
                  try {
                    await widget.service.saveOrder(order.copyWith(
                      customerName: nameCtrl.text.trim().isEmpty
                          ? order.customerName
                          : nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      address: addrCtrl.text.trim(),
                      trackingId: trackCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      UiHelpers.showFeedback(context, s.t('order_updated'));
                    }
                  } catch (_) {
                    if (mounted) {
                      UiHelpers.showFeedback(context, s.t('action_failed'),
                          isError: true);
                    }
                  }
                },
                child: Text(s.t('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TemplateModel? _findTemplateForStage(String stage) {
    for (final t in widget.templates) {
      if (t.stage == stage && t.productId.isEmpty) return t;
    }
    for (final t in widget.templates) {
      if (t.stage == stage) return t;
    }
    return widget.templates.isNotEmpty ? widget.templates.first : null;
  }

  Future<void> _openStageWhatsApp(
    OrderModel order,
    String stage, {
    String? trackingIdOverride,
  }) async {
    final s = widget.s;
    if (order.phone.trim().isEmpty) {
      UiHelpers.showFeedback(context, s.t('enter_phone_first'), isError: true);
      return;
    }
    final tpl = _findTemplateForStage(stage);
    final lang = widget.profile.appLanguage;
    final body = tpl != null ? tpl.bodyForLang(lang) : 'Order Update';
    final msg = TemplateEngine.render(
      templateBody: body,
      profile: widget.profile,
      products: widget.products,
      subtotal: order.subtotal,
      deliveryCharge: order.deliveryCharge,
      totalAmount: order.totalAmount,
      packSummary: order.itemsSummary,
      trackingId: trackingIdOverride ?? order.trackingId,
    );
    await WhatsAppService.openDirectChat(phone: order.phone, message: msg);
  }

  Future<void> _quickSendPayment(OrderModel order) async {
    await _openStageWhatsApp(order, 'payment');
  }

  Future<void> _quickMarkPaid(OrderModel order) async {
    final s = widget.s;
    final ok = await UiHelpers.confirmDialog(
      context,
      title: s.t('mark_paid'),
      message: s.t('confirm_mark_paid_q'),
      confirmLabel: s.t('confirm'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;
    try {
      await widget.service.updateOrderStatus(
        orderId: order.id,
        status: 'Paid',
      );
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('status_updated'));
      }
      await _openStageWhatsApp(order, 'paid');
    } catch (_) {
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    }
  }

  Future<void> _quickDispatch(OrderModel order) async {
    final s = widget.s;
    final trackingCtrl = TextEditingController(text: order.trackingId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          s.t('dispatch_order'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: trackingCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.t('tracking_id'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('save_and_whatsapp')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final trackingId = trackingCtrl.text.trim();
    try {
      await widget.service.updateOrderStatus(
        orderId: order.id,
        status: 'Dispatched',
        trackingId: trackingId,
      );
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('status_updated'));
      }
      await _openStageWhatsApp(
        order,
        'dispatched',
        trackingIdOverride: trackingId,
      );
    } catch (_) {
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    }
  }

  Future<void> _quickSendReview(OrderModel order) async {
    final s = widget.s;
    final ok = await UiHelpers.confirmDialog(
      context,
      title: s.t('send_review'),
      message: s.t('confirm_send_review_q'),
      confirmLabel: s.t('confirm'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;
    try {
      await widget.service.updateOrderStatus(
        orderId: order.id,
        status: 'Review Sent',
        reviewSent: true,
      );
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('status_updated'));
      }
      await _openStageWhatsApp(order, 'review');
    } catch (_) {
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final primary = Color(widget.profile.primaryColorHex);

    final filteredOrders = widget.orders.where((o) {
      if (_filterStatus.isNotEmpty && o.status != _filterStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = o.customerName.toLowerCase().contains(q);
        final matchPhone = o.phone.contains(q);
        final matchId = o.id.toLowerCase().contains(q);
        final matchTrack = o.trackingId.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchId && !matchTrack) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: s.t('search_orders_hint'),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.outlined(
                      tooltip: s.t('bin_title'),
                      onPressed: () {
                        if (widget.onOpenBin != null) {
                          widget.onOpenBin!();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BinScreen(service: widget.service),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('', s.t('all')),
                      const SizedBox(width: 6),
                      for (final st in OrderModel.statuses)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _filterChip(st, st),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          s.t('no_orders_found'),
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                    itemCount: filteredOrders.length,
                    itemBuilder: (ctx, i) {
                      final order = filteredOrders[i];
                      Color statusColor = Colors.orange;
                      if (order.status == 'Paid') statusColor = Colors.blue;
                      if (order.status == 'Delivered') {
                        statusColor = Colors.green;
                      }
                      if (order.status == 'Dispatched') {
                        statusColor = Colors.purple;
                      }
                      if (order.status == 'Review Sent') {
                        statusColor = Colors.teal;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          leading: CircleAvatar(
                            backgroundColor: primary.withValues(alpha: 0.12),
                            child: Text(
                              order.customerName.isNotEmpty
                                  ? order.customerName[0].toUpperCase()
                                  : 'C',
                              style: TextStyle(
                                  color: primary, fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(
                            order.customerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            '${order.phone} • ₹${order.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          children: [
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    '${s.t('date')}: ${order.createdAt.toLocal().toString().substring(0, 16)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                if (order.trackingId.isNotEmpty)
                                  Text('Track: ${order.trackingId}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...order.items.map((item) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          '${item.productName} (${item.packLabel}) x${item.quantity}',
                                          style:
                                              const TextStyle(fontSize: 12)),
                                      Text(
                                          '₹${item.lineSubtotal.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                            if (order.address.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Address: ${order.address}',
                                    style: const TextStyle(fontSize: 11.5)),
                              ),
                            ],
                            if (order.notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${s.t('notes')}: ${order.notes}',
                                    style: const TextStyle(fontSize: 11.5)),
                              ),
                            ],
                            const SizedBox(height: 10),
                            if (order.status == 'New Inquiry' ||
                                order.status == 'Address Received' ||
                                order.status == 'Payment Pending') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF0F766E),
                                        side: const BorderSide(
                                            color: Color(0xFF0F766E)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () =>
                                          _quickSendPayment(order),
                                      icon: const Icon(Icons.qr_code_2_rounded,
                                          size: 14),
                                      label: Text(s.t('send_payment'),
                                          style:
                                              const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => _quickMarkPaid(order),
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 14),
                                      label: Text(s.t('mark_paid'),
                                          style:
                                              const TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ] else if (order.status == 'Paid') ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.purple.shade700,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _quickDispatch(order),
                                  icon: const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 15),
                                  label: Text(s.t('dispatch_order'),
                                      style: const TextStyle(fontSize: 11.5)),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ] else if ((order.status == 'Dispatched' ||
                                    order.status == 'Delivered') &&
                                !order.reviewSent) ...[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _quickSendReview(order),
                                  icon: const Icon(Icons.star_outline_rounded,
                                      size: 15),
                                  label: Text(s.t('send_review'),
                                      style: const TextStyle(fontSize: 11.5)),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _openStatusDialog(order),
                                    icon:
                                        const Icon(Icons.swap_horiz, size: 14),
                                    label: Text(s.t('update_status'),
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _openStageWhatsApp(
                                        order,
                                        order.status == 'Paid'
                                            ? 'paid'
                                            : order.status == 'Dispatched'
                                                ? 'dispatched'
                                                : order.status == 'Review Sent'
                                                    ? 'review'
                                                    : 'payment'),
                                    icon: const Icon(Icons.send_rounded,
                                        size: 14),
                                    label: Text(s.t('send_whatsapp'),
                                        style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: s.t('edit'),
                                  onPressed: () => _openEditOrderSheet(order),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 17),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: s.t('delete'),
                                  onPressed: () async {
                                    final confirm =
                                        await UiHelpers.confirmDialog(
                                      context,
                                      title: s.t('confirm_delete'),
                                      message: s.t('delete_order_q'),
                                      confirmLabel: s.t('delete'),
                                      cancelLabel: s.t('cancel'),
                                      isDestructive: true,
                                    );
                                    if (!confirm) return;
                                    try {
                                      await widget.service
                                          .softDeleteOrder(order.id);
                                      if (context.mounted) {
                                        UiHelpers.showFeedback(
                                            context, s.t('order_moved_bin'));
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        UiHelpers.showFeedback(
                                            context, s.t('action_failed'),
                                            isError: true);
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline,
                                      size: 17, color: Colors.red),
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
      ),
    );
  }

  Widget _filterChip(String status, String label) {
    final selected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 11, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: Color(widget.profile.primaryColorHex),
      backgroundColor: Colors.grey.shade200,
      onSelected: (bool val) {
        setState(() => _filterStatus = val ? status : '');
      },
      visualDensity: VisualDensity.compact,
    );
  }
}
