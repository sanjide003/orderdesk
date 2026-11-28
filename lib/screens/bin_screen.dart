import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';

class BinScreen extends StatefulWidget {
  final FirestoreService service;
  final bool embedded;

  const BinScreen({super.key, required this.service, this.embedded = false});

  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  int _categoryIndex = 0; // 0=Orders, 1=Products, 2=Templates, 3=Customers

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.service.languageNotifier,
      builder: (context, langOverride, _) {
        return StreamBuilder<BusinessProfile>(
          stream: widget.service.watchBusinessProfile(),
          builder: (context, profSnap) {
            final profile = profSnap.data ?? LakfaSeedData.profile;
            final s = AppStrings(langOverride ?? profile.appLanguage);
            final primary = Color(
                widget.service.colorNotifier.value ?? profile.primaryColorHex);

            return StreamBuilder<List<OrderModel>>(
              stream: widget.service.watchDeletedOrders(),
              builder: (context, ordSnap) {
                final orders = ordSnap.data ?? [];
                return StreamBuilder<List<ProductModel>>(
                  stream: widget.service.watchDeletedProducts(),
                  builder: (context, prodSnap) {
                    final products = prodSnap.data ?? [];
                    return StreamBuilder<List<TemplateModel>>(
                      stream: widget.service.watchDeletedTemplates(),
                      builder: (context, tplSnap) {
                        final templates = tplSnap.data ?? [];
                        return StreamBuilder<List<CustomerModel>>(
                          stream: widget.service.watchDeletedCustomers(),
                          builder: (context, custSnap) {
                            final customers = custSnap.data ?? [];
                            final totalCount = orders.length +
                                products.length +
                                templates.length +
                                customers.length;

                            Future<void> handleEmptyBin() async {
                              final ok = await UiHelpers.confirmDialog(
                                context,
                                title: s.t('empty_bin'),
                                message: s.t('empty_bin_q'),
                                confirmLabel: s.t('delete_forever'),
                                cancelLabel: s.t('cancel'),
                                isDestructive: true,
                              );
                              if (!ok) return;
                              try {
                                await widget.service.emptyBin(
                                  orders: orders,
                                  products: products,
                                  templates: templates,
                                  customers: customers,
                                );
                                if (context.mounted) {
                                  UiHelpers.showFeedback(
                                      context, s.t('bin_emptied'));
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  UiHelpers.showFeedback(
                                      context, s.t('action_failed'),
                                      isError: true);
                                }
                              }
                            }

                            return Scaffold(
                              backgroundColor: widget.embedded
                                  ? Colors.transparent
                                  : const Color(0xFFF4F7F6),
                              appBar: widget.embedded
                                  ? null
                                  : AppBar(
                                      title: Text(s.t('bin_title')),
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      actions: [
                                        if (totalCount > 0)
                                          TextButton.icon(
                                            onPressed: handleEmptyBin,
                                            icon: const Icon(
                                                Icons.delete_sweep_outlined,
                                                color: Colors.white,
                                                size: 18),
                                            label: Text(
                                              s.t('empty_bin'),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                              body: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1200),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        color: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  children: [
                                                    _catChip(
                                                      0,
                                                      '${s.t('bin_orders')} (${orders.length})',
                                                      primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _catChip(
                                                      1,
                                                      '${s.t('bin_products')} (${products.length})',
                                                      primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _catChip(
                                                      2,
                                                      '${s.t('bin_templates')} (${templates.length})',
                                                      primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    _catChip(
                                                      3,
                                                      '${s.t('bin_customers')} (${customers.length})',
                                                      primary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (widget.embedded &&
                                                totalCount > 0)
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.red.shade700,
                                                ),
                                                onPressed: handleEmptyBin,
                                                icon: const Icon(
                                                    Icons.delete_sweep_outlined,
                                                    size: 17),
                                                label: Text(s.t('empty_bin')),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: _buildList(
                                          context,
                                          s: s,
                                          primary: primary,
                                          orders: orders,
                                          products: products,
                                          templates: templates,
                                          customers: customers,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _catChip(int index, String label, Color primary) {
    final selected = _categoryIndex == index;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: primary,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => setState(() => _categoryIndex = index),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildList(
    BuildContext context, {
    required AppStrings s,
    required Color primary,
    required List<OrderModel> orders,
    required List<ProductModel> products,
    required List<TemplateModel> templates,
    required List<CustomerModel> customers,
  }) {
    if (_categoryIndex == 0) {
      if (orders.isEmpty) return _emptyView(s);
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final o = orders[i];
          return _binCard(
            context,
            s: s,
            primary: primary,
            title: o.customerName,
            subtitle:
                '${o.phone} • ${TemplateEngine.formatMoney(o.totalAmount)} • ${o.status}',
            deletedAt: o.deletedAt,
            onRestore: () => widget.service.restoreOrder(o.id),
            onDeleteForever: () => widget.service.permanentlyDeleteOrder(o.id),
          );
        },
      );
    }
    if (_categoryIndex == 1) {
      if (products.isEmpty) return _emptyView(s);
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        itemBuilder: (ctx, i) {
          final p = products[i];
          return _binCard(
            context,
            s: s,
            primary: primary,
            title: p.name,
            subtitle: p.packs.map((e) => e.label).join(', '),
            deletedAt: p.deletedAt,
            onRestore: () => widget.service.restoreProduct(p.id),
            onDeleteForever: () =>
                widget.service.permanentlyDeleteProduct(p.id),
          );
        },
      );
    }
    if (_categoryIndex == 2) {
      if (templates.isEmpty) return _emptyView(s);
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final t = templates[i];
          return _binCard(
            context,
            s: s,
            primary: primary,
            title: t.title,
            subtitle: t.bodyMl,
            deletedAt: t.deletedAt,
            onRestore: () => widget.service.restoreTemplate(t.id),
            onDeleteForever: () =>
                widget.service.permanentlyDeleteTemplate(t.id),
          );
        },
      );
    }

    if (customers.isEmpty) return _emptyView(s);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: customers.length,
      itemBuilder: (ctx, i) {
        final c = customers[i];
        return _binCard(
          context,
          s: s,
          primary: primary,
          title: c.name,
          subtitle: '${c.phone}${c.address.isNotEmpty ? " • ${c.address}" : ""}',
          deletedAt: c.deletedAt,
          onRestore: () => widget.service.restoreCustomer(c.id),
          onDeleteForever: () =>
              widget.service.permanentlyDeleteCustomer(c.id),
        );
      },
    );
  }

  Widget _emptyView(AppStrings s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded,
              size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            s.t('bin_empty'),
            style: TextStyle(
                color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _binCard(
    BuildContext context, {
    required AppStrings s,
    required Color primary,
    required String title,
    required String subtitle,
    required DateTime? deletedAt,
    required Future<void> Function() onRestore,
    required Future<void> Function() onDeleteForever,
  }) {
    final deletedText = deletedAt != null
        ? '${s.t('deleted_on')}: ${DateFormat('dd MMM yyyy, hh:mm a').format(deletedAt.toLocal())}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          if (deletedText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              deletedText,
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await UiHelpers.confirmDialog(
                      context,
                      title: s.t('restore'),
                      message: s.t('restore_q'),
                      confirmLabel: s.t('restore'),
                      cancelLabel: s.t('cancel'),
                    );
                    if (!ok) return;
                    try {
                      await onRestore();
                      if (context.mounted) {
                        UiHelpers.showFeedback(context, s.t('restored_msg'));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        UiHelpers.showFeedback(context, s.t('action_failed'),
                            isError: true);
                      }
                    }
                  },
                  icon: Icon(Icons.restore_rounded, size: 16, color: primary),
                  label: Text(s.t('restore'),
                      style: TextStyle(color: primary, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final ok = await UiHelpers.confirmDialog(
                      context,
                      title: s.t('delete_forever'),
                      message: s.t('delete_forever_q'),
                      confirmLabel: s.t('delete_forever'),
                      cancelLabel: s.t('cancel'),
                      isDestructive: true,
                    );
                    if (!ok) return;
                    try {
                      await onDeleteForever();
                      if (context.mounted) {
                        UiHelpers.showFeedback(
                            context, s.t('deleted_forever_msg'));
                      }
                    } catch (_) {
                      if (context.mounted) {
                        UiHelpers.showFeedback(context, s.t('action_failed'),
                            isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_forever_outlined, size: 16),
                  label: Text(s.t('delete_forever'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
