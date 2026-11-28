import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/customer_model.dart';
import '../models/delivery_rules.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/delivery_calculator.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';
import '../services/whatsapp_service.dart';

class NewOrderScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final DeliveryRules rules;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final AppStrings s;
  final CustomerModel? prefilledCustomer;

  const NewOrderScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.products,
    required this.templates,
    required this.s,
    this.prefilledCustomer,
  });

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _manualDeliveryCtrl = TextEditingController();
  final _discountPercentCtrl = TextEditingController();
  final _discountFlatCtrl = TextEditingController();
  final Map<String, int> _cartQty = {};
  String _payLang = 'ml';

  @override
  void initState() {
    super.initState();
    _applyPrefill(widget.prefilledCustomer);
  }

  @override
  void didUpdateWidget(covariant NewOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefilledCustomer != null &&
        widget.prefilledCustomer != oldWidget.prefilledCustomer) {
      _applyPrefill(widget.prefilledCustomer);
    }
  }

  void _applyPrefill(CustomerModel? c) {
    if (c == null) return;
    _phoneCtrl.text = c.phone;
    _nameCtrl.text = c.name;
    _addressCtrl.text = c.address;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _manualDeliveryCtrl.dispose();
    _discountPercentCtrl.dispose();
    _discountFlatCtrl.dispose();
    super.dispose();
  }

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
      _discountPercentCtrl.clear();
      _discountFlatCtrl.clear();
      _cartQty.clear();
    });
  }

  Future<void> _pickSavedCustomer(List<CustomerModel> customers) async {
    final s = widget.s;
    final searchCtrl = TextEditingController();
    String q = '';
    final picked = await showModalBottomSheet<CustomerModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = customers.where((c) {
            if (q.isEmpty) return true;
            final lower = q.toLowerCase();
            return c.name.toLowerCase().contains(lower) ||
                c.phone.contains(q) ||
                c.address.toLowerCase().contains(lower);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.t('pick_customer'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setModalState(() => q = v.trim()),
                  decoration: InputDecoration(
                    labelText: s.t('search_customers_label'),
                    hintText: s.t('search_customers'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: filtered.isEmpty
                      ? Center(child: Text(s.t('no_customers')))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${c.phone}${c.address.isNotEmpty ? " • ${c.address}" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.pop(ctx, c),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked != null) {
      setState(() => _applyPrefill(picked));
    }
  }

  Future<void> _saveOrder(PriceBreakdown calc, List<OrderItem> items,
      {bool sendPayment = false}) async {
    if (_phoneCtrl.text.trim().isEmpty) {
      UiHelpers.showFeedback(context, widget.s.t('enter_phone_first'),
          isError: true);
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
      discountPercent: calc.discountPercent,
      discountAmount: calc.discountAmount,
      deliveryCharge: calc.deliveryCharge,
      totalAmount: calc.total,
      status: items.isNotEmpty ? 'Payment Pending' : 'New Inquiry',
      createdAt: DateTime.now(),
    );
    try {
      await widget.service.createOrder(order);
      if (mounted) {
        UiHelpers.showFeedback(context, widget.s.t('order_saved'));
      }
      if (sendPayment && widget.templates.isNotEmpty) {
        final payTpl = widget.templates.firstWhere(
          (t) => t.stage == 'payment',
          orElse: () => widget.templates.first,
        );
        final msg = TemplateEngine.render(
          templateBody: payTpl.bodyForLang(_payLang),
          profile: widget.profile,
          products: widget.products,
          orderItems: items,
          subtotal: calc.subtotal,
          discountAmount: calc.discountAmount,
          discountPercent: calc.discountPercent,
          deliveryCharge: calc.deliveryCharge,
          totalAmount: calc.total,
          packSummary: order.itemsSummary,
          includeOrderBillHeader: true,
        );
        await WhatsAppService.openDirectChat(phone: order.phone, message: msg);
      }
    } catch (_) {
      if (mounted) {
        UiHelpers.showFeedback(context, widget.s.t('action_failed'),
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final items = _buildCartItems();
    final manualDelivery = double.tryParse(_manualDeliveryCtrl.text.trim());
    final discountPercent = double.tryParse(_discountPercentCtrl.text.trim());
    final discountFlat = double.tryParse(_discountFlatCtrl.text.trim());
    final calc = DeliveryCalculator.calculate(
      items: items,
      rules: widget.rules,
      manualDeliveryOverride: manualDelivery,
      discountPercent: discountPercent,
      discountFlatAmount: discountFlat,
    );

    return StreamBuilder<List<CustomerModel>>(
      stream: widget.service.watchCustomers(),
      builder: (context, custSnap) {
        final customers = custSnap.data ?? [];

        final customerCard = Container(
          padding: const EdgeInsets.all(14),
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
                    child: Text(s.t('customer_details'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  if (customers.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _pickSavedCustomer(customers),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.people_outline, size: 15),
                      label: Text(s.t('pick_customer'),
                          style: const TextStyle(fontSize: 11.5)),
                    ),
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
                onChanged: (val) {
                  final norm = FirestoreService.normalizePhoneKey(val);
                  if (norm.length == 10 && customers.isNotEmpty) {
                    final match = customers.cast<CustomerModel?>().firstWhere(
                          (c) =>
                              c != null &&
                              FirestoreService.normalizePhoneKey(c.phone) ==
                                  norm,
                          orElse: () => null,
                        );
                    if (match != null) {
                      if (_nameCtrl.text.trim().isEmpty) {
                        _nameCtrl.text = match.name;
                      }
                      if (_addressCtrl.text.trim().isEmpty) {
                        _addressCtrl.text = match.address;
                      }
                    }
                  }
                },
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
        );

        final productsCard = Container(
          padding: const EdgeInsets.all(14),
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
                                '${TemplateEngine.formatMoney(pack.price)} · ${pack.deliveryCharge <= 0 ? s.t("free_delivery") : "+${TemplateEngine.formatMoney(pack.deliveryCharge)}"}',
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
                                    ? () => setState(
                                        () => _cartQty[key] = qty - 1)
                                    : null,
                              ),
                              Text('$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  )),
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
            ],
          ),
        );

        final summaryCard = Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, calcBox) {
                  final discountPctField = TextField(
                    controller: _discountPercentCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      if (v.trim().isNotEmpty &&
                          _discountFlatCtrl.text.isNotEmpty) {
                        _discountFlatCtrl.clear();
                      }
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: s.t('discount_percent'),
                      hintText: '0',
                      suffixText: '%',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      floatingLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  final discountFlatField = TextField(
                    controller: _discountFlatCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      if (v.trim().isNotEmpty &&
                          _discountPercentCtrl.text.isNotEmpty) {
                        _discountPercentCtrl.clear();
                      }
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      labelText: s.t('discount_amount'),
                      hintText: '0',
                      prefixText: '₹',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      floatingLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  final deliveryField = TextField(
                    controller: _manualDeliveryCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: s.t('override_delivery'),
                      hintText: '0',
                      prefixText: '₹',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      floatingLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );

                  if (calcBox.maxWidth >= 380) {
                    return Row(
                      children: [
                        Expanded(child: discountPctField),
                        const SizedBox(width: 8),
                        Expanded(child: discountFlatField),
                        const SizedBox(width: 8),
                        Expanded(child: deliveryField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: discountPctField),
                          const SizedBox(width: 8),
                          Expanded(child: discountFlatField),
                        ],
                      ),
                      const SizedBox(height: 10),
                      deliveryField,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s.t("items_total")}: ${TemplateEngine.formatMoney(calc.subtotal)}  ·  ${s.t("delivery")}: ${calc.deliveryCharge <= 0 ? "FREE" : TemplateEngine.formatMoney(calc.deliveryCharge)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (calc.discountAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${s.t("discount")}: ${TemplateEngine.formatDiscount(calc.discountAmount, discountPercent: calc.discountPercent)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F766E),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${s.t("total")}: ${TemplateEngine.formatMoney(calc.total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
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
              const SizedBox(height: 12),
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
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            if (isWide) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            customerCard,
                            const SizedBox(height: 12),
                            productsCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: summaryCard,
                      ),
                    ],
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                customerCard,
                const SizedBox(height: 10),
                productsCard,
                const SizedBox(height: 10),
                summaryCard,
              ],
            );
          },
        );
      },
    );
  }
}
