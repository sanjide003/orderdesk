import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

class ProductsScreen extends StatelessWidget {
  final FirestoreService service;
  final List<ProductModel> products;

  const ProductsScreen({
    super.key,
    required this.service,
    required this.products,
  });

  Future<void> _openEditor(BuildContext context, [ProductModel? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final originCtrl = TextEditingController(text: existing?.origin ?? '');
    final highlightsCtrl = TextEditingController(
        text: existing?.highlights.join('
') ?? '');
    final packs = List<ProductPack>.from(existing?.packs ??
        [const ProductPack(label: '500g', price: 500, deliveryCharge: 50)]);
    bool active = existing?.active ?? true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                  existing == null ? 'Add New Product' : 'Edit Product',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: originCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Origin / Subtitle',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Active (Show in WhatsApp List)'),
                  value: active,
                  onChanged: (v) => setModalState(() => active = v),
                ),
                const Text('Packs / Variants',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...packs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return ListTile(
                    dense: true,
                    title: Text('${p.label} — ₹${p.price.toInt()}'),
                    subtitle: Text(p.deliveryCharge <= 0
                        ? 'Free Delivery'
                        : 'Delivery: ₹${p.deliveryCharge.toInt()}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setModalState(() => packs.removeAt(i)),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () async {
                    final labelC = TextEditingController();
                    final priceC = TextEditingController();
                    final delC = TextEditingController(text: '0');
                    final added = await showDialog<ProductPack>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Add Pack'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                                controller: labelC,
                                decoration: const InputDecoration(
                                    labelText: 'Pack Size (e.g. 250g, 1 kg)')),
                            TextField(
                                controller: priceC,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: 'Price ₹')),
                            TextField(
                                controller: delC,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Delivery Charge ₹ (0 = Free)')),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dCtx),
                              child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () => Navigator.pop(
                              dCtx,
                              ProductPack(
                                label: labelC.text.trim(),
                                price: double.tryParse(priceC.text) ?? 0,
                                deliveryCharge: double.tryParse(delC.text) ?? 0,
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                    if (added != null && added.label.isNotEmpty) {
                      setModalState(() => packs.add(added));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Pack Variant'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: highlightsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Highlights (one per line)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final model = ProductModel(
                      id: existing?.id ?? '',
                      name: nameCtrl.text.trim(),
                      origin: originCtrl.text.trim(),
                      active: active,
                      packs: packs,
                      highlights: highlightsCtrl.text
                          .split('
')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    );
                    await service.saveProduct(model);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        itemBuilder: (ctx, i) {
          final p = products[i];
          return Card(
            child: ListTile(
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                p.packs
                    .map((pk) => '${pk.label}: ₹${pk.price.toInt()}')
                    .join(' • '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(label: Text(p.active ? 'Active' : 'Hidden')),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openEditor(context, p),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}
