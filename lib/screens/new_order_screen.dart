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

class NewOrderScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final DeliveryRules rules;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final AppStrings s;

  const NewOrderScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.products,
    required this.templates,
    required this.s,
  });

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _manualDeliveryCtrl = TextEditingController();
  final Map<String, int> _cartQty = {};
  String _payLang = 'ml';

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

  void _clear() {
    setState(() {
      _phoneCtrl.clear();
      _nameCtrl.clear();
      _addressCtrl.clear();
      _manualDeliveryCtrl.clear();
      _cartQty.clear();
    });
  }

  Future<void> _saveOrder(PriceBreakdown calc, List<OrderItem> items,
      {bool sendPayment = false}) async {
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
      createdAt: DateTime.now(),
    );
    await widget.service.createOrder(order);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.s.t('order_saved'))),
      );
    }
    if (sendPayment) {
      final payTpl = widget.templates.firstWhere(
        (t) => t.stage == 'payment',
        orElse: () => widget.templates.first,
      );
      final msg = TemplateEngine.render(
        templateBody: payTpl.bodyForLang(_payLang),
        profile: widget.profile,
        products: widget.products,
        subtotal: calc.subtotal,
        deliveryCharge: calc.deliveryCharge,
        totalAmount: calc.total,
        packSummary: order.itemsSummary,
      );
      await WhatsAppService.openDirectChat(phone: order.phone, message: msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final items = _buildCartItems();
    final manualDelivery = double.tryParse(_manualDeliveryCtrl.text.trim());
    final calc = DeliveryCalculator.calculate(
      items: items,
      rules: widget.rules,
      manualDeliveryOverride: manualDelivery,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Container(
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
                  Text(s.t('customer_details'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  TextButton(
                    onPressed: _clear,
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    child:
                        Text(s.t('clear'), style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
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
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: s.t('customer_name'),
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('select_items'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
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
                                '${TemplateEngine.formatMoney(pack.price)} • ${pack.deliveryCharge <= 0 ? s.t("free_delivery") : "+${TemplateEngine.formatMoney(pack.deliveryCharge)}"}',
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
                                    ? () =>
                                        setState(() => _cartQty[key] = qty - 1)
                                    : null,
                              ),
                              Text('$qty',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _cartQty[key] = qty + 1),
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
                        Text(
                          '${s.t("total")}: ${TemplateEngine.formatMoney(calc.total)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _manualDeliveryCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
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
                child: SegmentedButton<String>(
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                        value: 'ml',
                        label: Text(s.t('lang_ml'),
                            style: const TextStyle(fontSize: 11))),
                    ButtonSegment(
                        value: 'en',
                        label: Text(s.t('lang_en'),
                            style: const TextStyle(fontSize: 11))),
                    ButtonSegment(
                        value: 'manglish',
                        label: Text(s.t('lang_manglish'),
                            style: const TextStyle(fontSize: 11))),
                  ],
                  selected: {_payLang},
                  onSelectionChanged: (set) =>
                      setState(() => _payLang = set.first),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveOrder(calc, items),
                      icon: const Icon(Icons.save_outlined, size: 17),
                      label: Text(s.t('save_order'),
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () =>
                          _saveOrder(calc, items, sendPayment: true),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(s.t('save_and_pay_msg'),
                          style: const TextStyle(fontSize: 11)),
                    ),
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
