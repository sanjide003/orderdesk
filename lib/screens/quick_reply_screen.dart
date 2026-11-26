import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/delivery_calculator.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/whatsapp_service.dart';

class QuickReplyScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final DeliveryRules rules;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final AppStrings s;

  const QuickReplyScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.products,
    required this.templates,
    required this.s,
  });

  @override
  State<QuickReplyScreen> createState() => _QuickReplyScreenState();
}

class _QuickReplyScreenState extends State<QuickReplyScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _manualDeliveryCtrl = TextEditingController();
  final _previewCtrl = TextEditingController();

  final Map<String, int> _cartQty = {};
  String? _selectedTemplateId;
  bool _manualPreviewEdited = false;

  List<OrderItem> _buildCartItems() {
    final items = <OrderItem>[];
    for (final product in widget.products.where((p) => p.active)) {
      for (final pack in product.packs) {
        final key = '${product.id}__${pack.label}';
        final qty = _cartQty[key] ?? 0;
        if (qty > 0) {
          items.add(OrderItem(
            productId: product.id,
            productName: product.name,
            packLabel: pack.label,
            unitPrice: pack.price,
            packDeliveryCharge: pack.deliveryCharge,
            quantity: qty,
          ));
        }
      }
    }
    return items;
  }

  void _clearAll() {
    setState(() {
      _phoneCtrl.clear();
      _nameCtrl.clear();
      _addressCtrl.clear();
      _trackingCtrl.clear();
      _manualDeliveryCtrl.clear();
      _cartQty.clear();
      _manualPreviewEdited = false;
    });
  }

  Future<void> _saveAsOrder(PriceBreakdown calc, List<OrderItem> items) async {
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.s.t('enter_phone_first'))),
      );
      return;
    }
    final order = OrderModel(
      id: '',
      customerName: _nameCtrl.text.trim().isEmpty
          ? 'Customer'
          : _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      items: items,
      subtotal: calc.subtotal,
      deliveryCharge: calc.deliveryCharge,
      totalAmount: calc.total,
      status: items.isNotEmpty ? 'Payment Pending' : 'New Inquiry',
      trackingId: _trackingCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await widget.service.createOrder(order);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.s.t('order_saved'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final templates = widget.templates;
    final currentTemplate = templates.firstWhere(
      (t) => t.id == _selectedTemplateId,
      orElse: () => templates.first,
    );

    final items = _buildCartItems();
    final manualDelivery = double.tryParse(_manualDeliveryCtrl.text.trim());
    final calc = DeliveryCalculator.calculate(
      items: items,
      rules: widget.rules,
      manualDeliveryOverride: manualDelivery,
    );

    final packSummary = items
        .map((e) => '${e.productName} (${e.packLabel}) x${e.quantity}')
        .join(', ');

    final autoRendered = TemplateEngine.render(
      templateBody: currentTemplate.body,
      profile: widget.profile,
      products: widget.products,
      subtotal: calc.subtotal,
      deliveryCharge: calc.deliveryCharge,
      totalAmount: calc.total,
      packSummary: packSummary,
      trackingId: _trackingCtrl.text,
    );

    if (!_manualPreviewEdited && _previewCtrl.text != autoRendered) {
      _previewCtrl.text = autoRendered;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        _SectionCard(
          title: s.t('customer_details'),
          trailing: TextButton(
            onPressed: _clearAll,
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            child: Text(s.t('clear'), style: const TextStyle(fontSize: 12)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: s.t('whatsapp_number'),
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: s.t('customer_name'),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _trackingCtrl,
                      onChanged: (_) =>
                          setState(() => _manualPreviewEdited = false),
                      decoration: InputDecoration(
                        labelText: s.t('tracking_id'),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.t('delivery_address'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: s.t('select_items'),
          child: Column(
            children: [
              ...widget.products.where((p) => p.active).expand((product) {
                return product.packs.map((pack) {
                  final key = '${product.id}__${pack.label}';
                  final qty = _cartQty[key] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${product.name} (${pack.label})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              Text(
                                '${TemplateEngine.formatMoney(pack.price)} • ${pack.deliveryCharge <= 0 ? s.t("free_delivery") : "+${TemplateEngine.formatMoney(pack.deliveryCharge)} ${s.t("delivery")}"}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                visualDensity: VisualDensity.compact,
                                onPressed: qty > 0
                                    ? () => setState(() {
                                          _cartQty[key] = qty - 1;
                                          _manualPreviewEdited = false;
                                        })
                                    : null,
                              ),
                              Text('$qty',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() {
                                  _cartQty[key] = qty + 1;
                                  _manualPreviewEdited = false;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                });
              }),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.t("subtotal")}: ${TemplateEngine.formatMoney(calc.subtotal)}  •  ${s.t("delivery")}: ${calc.deliveryCharge <= 0 ? "FREE" : TemplateEngine.formatMoney(calc.deliveryCharge)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.t("total")}: ${TemplateEngine.formatMoney(calc.total)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _manualDeliveryCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) =>
                          setState(() => _manualPreviewEdited = false),
                      decoration: InputDecoration(
                        labelText: s.t('override_delivery'),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _saveAsOrder(calc, items),
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(s.t('save_order')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: s.t('select_template'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: templates.map((t) {
                    final selected = t.id == currentTemplate.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(t.title,
                            style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() {
                          _selectedTemplateId = t.id;
                          _manualPreviewEdited = false;
                        }),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Text(s.t('message_preview'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              TextField(
                controller: _previewCtrl,
                maxLines: 8,
                minLines: 4,
                onChanged: (_) => _manualPreviewEdited = true,
                style: const TextStyle(fontSize: 13, height: 1.4),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFE7FFDB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => WhatsAppService.openDirectChat(
                        phone: _phoneCtrl.text,
                        message: _previewCtrl.text,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(s.t('send_whatsapp'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await WhatsAppService.copyMessage(_previewCtrl.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.t('copied'))),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(s.t('copy')),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    tooltip: s.t('share'),
                    onPressed: () =>
                        WhatsAppService.shareMessage(_previewCtrl.text),
                    icon: const Icon(Icons.share_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
