import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/product_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';
import 'bin_screen.dart';

class ProductsScreen extends StatelessWidget {
  final FirestoreService service;
  final List<ProductModel> initialProducts;
  final AppStrings initialStrings;
  final bool embedded;
  final VoidCallback? onOpenBin;

  const ProductsScreen({
    super.key,
    required this.service,
    required this.initialProducts,
    required this.initialStrings,
    this.embedded = false,
    this.onOpenBin,
  });

  Future<void> _confirmDelete(
      BuildContext context, AppStrings s, ProductModel p) async {
    final ok = await UiHelpers.confirmDialog(
      context,
      title: s.t('confirm_delete'),
      message: s.t('delete_product_q'),
      confirmLabel: s.t('delete'),
      cancelLabel: s.t('cancel'),
      isDestructive: true,
    );
    if (!ok) return;
    try {
      await service.softDeleteProduct(p);
      if (context.mounted) {
        UiHelpers.showFeedback(context, s.t('product_moved_bin'));
      }
    } catch (_) {
      if (context.mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    }
  }

  Future<void> _openEditor(
      BuildContext context, AppStrings s, [ProductModel? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final originCtrl = TextEditingController(text: existing?.origin ?? '');
    final highlightsCtrl =
        TextEditingController(text: existing?.highlights.join('\n') ?? '');
    final packs = List<ProductPack>.from(existing?.packs ??
        [const ProductPack(label: '500g', price: 500, deliveryCharge: 50)]);
    bool active = existing?.active ?? true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
                  existing == null ? s.t('new_product') : s.t('edit_product'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.t('product_name'),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: originCtrl,
                  decoration: InputDecoration(
                    labelText: s.t('origin_subtitle'),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.t('active_in_list'),
                      style: const TextStyle(fontSize: 13)),
                  value: active,
                  onChanged: (v) => setModalState(() => active = v),
                ),
                Text(s.t('packs_variants'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                ...packs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.label} • ${TemplateEngine.formatMoney(p.price)} (${p.deliveryCharge <= 0 ? s.t("free_delivery") : "+₹${p.deliveryCharge.toInt()}"})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final ok = await UiHelpers.confirmDialog(
                              ctx,
                              title: s.t('delete'),
                              message: s.t('delete_pack_q'),
                              confirmLabel: s.t('delete'),
                              cancelLabel: s.t('cancel'),
                              isDestructive: true,
                            );
                            if (ok) {
                              setModalState(() => packs.removeAt(i));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final labelC = TextEditingController();
                      final priceC = TextEditingController();
                      final taxC = TextEditingController(text: '5% GST incl.');
                      final delC = TextEditingController(text: '0');
                      final added = await showDialog<ProductPack>(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          title: Text(s.t('add_pack')),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                  controller: labelC,
                                  decoration: InputDecoration(
                                      labelText: s.t('pack_size'),
                                      isDense: true)),
                              TextField(
                                  controller: priceC,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: s.t('price_inr'),
                                      isDense: true)),
                              TextField(
                                  controller: taxC,
                                  decoration: InputDecoration(
                                      labelText: s.t('tax_note'),
                                      isDense: true)),
                              TextField(
                                  controller: delC,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: s.t('pack_delivery'),
                                      isDense: true)),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: Text(s.t('cancel'))),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                dCtx,
                                ProductPack(
                                  label: labelC.text.trim(),
                                  price: double.tryParse(priceC.text) ?? 0,
                                  taxNote: taxC.text.trim(),
                                  deliveryCharge:
                                      double.tryParse(delC.text) ?? 0,
                                ),
                              ),
                              child: Text(s.t('save')),
                            ),
                          ],
                        ),
                      );
                      if (added != null && added.label.isNotEmpty) {
                        setModalState(() => packs.add(added));
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(s.t('add_pack')),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: highlightsCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: s.t('highlights_label'),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    if (existing != null) {
                      final ok = await UiHelpers.confirmDialog(
                        ctx,
                        title: s.t('confirm_save'),
                        message: s.t('save_changes_q'),
                        confirmLabel: s.t('save'),
                        cancelLabel: s.t('cancel'),
                      );
                      if (!ok) return;
                    }
                    final model = ProductModel(
                      id: existing?.id ?? '',
                      name: nameCtrl.text.trim(),
                      origin: originCtrl.text.trim(),
                      active: active,
                      packs: packs,
                      highlights: highlightsCtrl.text
                          .split('\n')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    );
                    try {
                      await service.saveProduct(model);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        UiHelpers.showFeedback(context, s.t('product_saved'));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        UiHelpers.showFeedback(context, s.t('action_failed'),
                            isError: true);
                      }
                    }
                  },
                  child: Text(s.t('save_product')),
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
    return ValueListenableBuilder<String?>(
      valueListenable: service.languageNotifier,
      builder: (context, langOverride, _) {
        return StreamBuilder<BusinessProfile>(
          stream: service.watchBusinessProfile(),
          builder: (context, profSnap) {
            final profile = profSnap.data ?? LakfaSeedData.profile;
            final s = AppStrings(
                langOverride ?? profSnap.data?.appLanguage ?? initialStrings.lang);
            final primary =
                Color(service.colorNotifier.value ?? profile.primaryColorHex);

            return StreamBuilder<List<ProductModel>>(
              stream: service.watchProducts(),
              initialData: initialProducts,
              builder: (context, prodSnap) {
                final products = prodSnap.data ?? [];

                Widget buildProductCard(ProductModel p) {
                  return Container(
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  if (p.origin.isNotEmpty)
                                    Text(p.origin,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Switch(
                              value: p.active,
                              onChanged: (v) async {
                                try {
                                  await service.toggleProductActive(p, v);
                                  if (context.mounted) {
                                    UiHelpers.showFeedback(
                                        context, s.t('product_saved'));
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    UiHelpers.showFeedback(
                                        context, s.t('action_failed'),
                                        isError: true);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _openEditor(context, s, p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _confirmDelete(context, s, p),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: p.packs
                              .map((pk) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${pk.label} • ${TemplateEngine.formatMoney(pk.price)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  );
                }

                return Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: embedded
                      ? null
                      : AppBar(
                          title: Text(s.t('products_title')),
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          actions: [
                            IconButton(
                              tooltip: s.t('bin_title'),
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BinScreen(service: service),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 760;
                          return Column(
                            children: [
                              if (embedded)
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${s.t("products_title")} (${products.length})',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15),
                                      ),
                                      const Spacer(),
                                      if (onOpenBin != null) ...[
                                        OutlinedButton.icon(
                                          onPressed: onOpenBin,
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16),
                                          label: Text(s.t('bin_title')),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: primary),
                                        onPressed: () =>
                                            _openEditor(context, s),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: Text(s.t('add_product')),
                                      ),
                                    ],
                                  ),
                                ),
                              if (embedded) const Divider(height: 1),
                              Expanded(
                                child: products.isEmpty
                                    ? Center(child: Text(s.t('no_products')))
                                    : isWide
                                        ? GridView.builder(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 16, 16, 80),
                                            gridDelegate:
                                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 460,
                                              mainAxisSpacing: 10,
                                              crossAxisSpacing: 10,
                                              mainAxisExtent: 142,
                                            ),
                                            itemCount: products.length,
                                            itemBuilder: (ctx, i) =>
                                                buildProductCard(products[i]),
                                          )
                                        : ListView.separated(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 12, 12, 80),
                                            itemCount: products.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (ctx, i) =>
                                                buildProductCard(products[i]),
                                          ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  floatingActionButton: embedded
                      ? null
                      : FloatingActionButton.extended(
                          onPressed: () => _openEditor(context, s),
                          icon: const Icon(Icons.add),
                          label: Text(s.t('add_product')),
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}
