import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
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

  const QuickReplyScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.products,
    required this.templates,
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

  final Map<String, int> _cartQty = {};
  TemplateModel? _selectedTemplate;

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

  Future<void> _saveAsOrder(PriceBreakdown calc, List<OrderItem> items) async {
    if (_phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ദയവായി കസ്റ്റമറുടെ ഫോൺ നമ്പർ നൽകുക')),
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
        const SnackBar(content: Text('ഓർഡർ CRM-ൽ സേവ് ചെയ്തു ✅')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = widget.templates;
    _selectedTemplate ??= templates.isNotEmpty ? templates.first : null;
    final currentTemplate = templates.firstWhere(
      (t) => t.id == _selectedTemplate?.id,
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

    final rendered = TemplateEngine.render(
      templateBody: currentTemplate.body,
      profile: widget.profile,
      products: widget.products,
      subtotal: calc.subtotal,
      deliveryCharge: calc.deliveryCharge,
      totalAmount: calc.total,
      packSummary: packSummary,
      trackingId: _trackingCtrl.text,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Customer Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Number',
                          hintText: '9876543210',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Address + Pincode (Optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _trackingCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'DTDC / Courier Tracking ID (For Dispatch)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Auto Price & Delivery Calculator',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...widget.products.where((p) => p.active).expand((product) {
                  return product.packs.map((pack) {
                    final key = '${product.id}__${pack.label}';
                    final qty = _cartQty[key] ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${product.name} (${pack.label})'),
                      subtitle: Text(
                        '₹${pack.price.toInt()} • ${pack.deliveryCharge <= 0 ? "Free Delivery" : "+₹${pack.deliveryCharge.toInt()} delivery"}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: qty > 0
                                ? () => setState(() => _cartQty[key] = qty - 1)
                                : null,
                          ),
                          Text('$qty',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                setState(() => _cartQty[key] = qty + 1),
                          ),
                        ],
                      ),
                    );
                  });
                }),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Subtotal: ${TemplateEngine.formatMoney(calc.subtotal)} | '
                        'Delivery: ${calc.deliveryCharge <= 0 ? "FREE" : TemplateEngine.formatMoney(calc.deliveryCharge)}
'
                        'Total: ${TemplateEngine.formatMoney(calc.total)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 115,
                      child: TextField(
                        controller: _manualDeliveryCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Override ₹',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _saveAsOrder(calc, items),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save to Order CRM'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select WhatsApp Template',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: templates.map((t) {
                    final selected = t.id == currentTemplate.id;
                    return ChoiceChip(
                      label: Text(t.title),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedTemplate = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7FFDB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    rendered,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => WhatsAppService.openDirectChat(
                          phone: _phoneCtrl.text,
                          message: rendered,
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await WhatsAppService.copyMessage(rendered);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('മെസ്സേജ് കോപ്പി ചെയ്തു 📋')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Share',
                      onPressed: () => WhatsAppService.shareMessage(rendered),
                      icon: const Icon(Icons.share),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
