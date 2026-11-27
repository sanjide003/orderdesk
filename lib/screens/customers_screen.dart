import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../services/app_strings.dart';
import '../services/excel_import_service.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
import '../services/ui_helpers.dart';
import '../services/whatsapp_service.dart';

class CustomersScreen extends StatefulWidget {
  final FirestoreService service;
  final void Function(CustomerModel customer)? onTakeOrder;

  const CustomersScreen({
    super.key,
    required this.service,
    this.onTakeOrder,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _importing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCustomerEditor(
      BuildContext context, AppStrings s, [CustomerModel? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

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
                existing == null ? s.t('add_customer') : s.t('edit_customer'),
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
                  if (phoneCtrl.text.trim().isEmpty &&
                      nameCtrl.text.trim().isEmpty) {
                    UiHelpers.showFeedback(ctx, s.t('enter_phone_first'),
                        isError: true);
                    return;
                  }
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
                  final now = DateTime.now();
                  final model = CustomerModel(
                    id: existing?.id ?? '',
                    name: nameCtrl.text.trim().isEmpty
                        ? 'Customer'
                        : nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addrCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    source: existing?.source ?? 'manual',
                    createdAt: existing?.createdAt ?? now,
                    updatedAt: now,
                  );
                  try {
                    await widget.service.saveCustomer(model);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      UiHelpers.showFeedback(context, s.t('customer_saved'));
                    }
                  } catch (_) {
                    if (context.mounted) {
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

  Future<void> _handleExcelUpload(BuildContext context, AppStrings s) async {
    try {
      final parsed = await ExcelImportService.pickAndParseFile();
      if (parsed == null) return;
      if (parsed.rows.isEmpty) {
        if (context.mounted) {
          UiHelpers.showFeedback(context, s.t('excel_no_rows'), isError: true);
        }
        return;
      }
      if (!context.mounted) return;

      String mode = 'both'; // 'customers' | 'orders' | 'both'
      String defaultStatus = OrderModel.statuses.first;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.t('excel_import_title'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${parsed.fileName} • ${parsed.rows.length} ${s.t('rows_detected')}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.teal.shade800,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t('import_target'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'customers',
                          label: Text(s.t('import_customers_only'),
                              style: const TextStyle(fontSize: 11))),
                      ButtonSegment(
                          value: 'orders',
                          label: Text(s.t('import_orders_only'),
                              style: const TextStyle(fontSize: 11))),
                      ButtonSegment(
                          value: 'both',
                          label: Text(s.t('import_both'),
                              style: const TextStyle(fontSize: 11))),
                    ],
                    selected: {mode},
                    onSelectionChanged: (set) =>
                        setModalState(() => mode = set.first),
                  ),
                  if (mode == 'orders' || mode == 'both') ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: defaultStatus,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: s.t('default_order_status'),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: OrderModel.statuses
                          .map((st) => DropdownMenuItem(
                                value: st,
                                child: Text(st),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() => defaultStatus = v);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount:
                          parsed.rows.length > 8 ? 8 : parsed.rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (_, i) {
                        final r = parsed.rows[i];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r.name} • ${r.phone}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  if (r.address.isNotEmpty)
                                    Text(r.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700)),
                                  if (r.productName.isNotEmpty || r.amount > 0)
                                    Text(
                                        '${r.productName} ${r.packLabel} x${r.quantity} • ₹${r.amount.toStringAsFixed(0)}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.teal.shade800)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _importing ? null : () => Navigator.pop(ctx),
                          child: Text(s.t('cancel')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _importing
                              ? null
                              : () async {
                                  final ok = await UiHelpers.confirmDialog(
                                    ctx,
                                    title: s.t('excel_import_title'),
                                    message:
                                        '${parsed.rows.length} ${s.t('rows_detected')}. ${s.t('save_changes_q')}',
                                    confirmLabel: s.t('import_now'),
                                    cancelLabel: s.t('cancel'),
                                  );
                                  if (!ok) return;
                                  setModalState(() => _importing = true);
                                  try {
                                    await widget.service.importExcelRows(
                                      rows: parsed.rows,
                                      saveCustomers: mode == 'customers' ||
                                          mode == 'both',
                                      saveOrders:
                                          mode == 'orders' || mode == 'both',
                                      defaultOrderStatus: defaultStatus,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      UiHelpers.showFeedback(
                                        context,
                                        '${s.t('import_success')} (${parsed.rows.length})',
                                      );
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      UiHelpers.showFeedback(
                                          context, s.t('action_failed'),
                                          isError: true);
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _importing = false);
                                    }
                                  }
                                },
                          icon: _importing
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload_file_rounded, size: 17),
                          label: Text(s.t('import_now')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    }
  }

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

            return StreamBuilder<List<CustomerModel>>(
              stream: widget.service.watchCustomers(),
              builder: (context, custSnap) {
                final customers = custSnap.data ?? [];
                final filtered = customers.where((c) {
                  if (_query.isEmpty) return true;
                  final q = _query.toLowerCase();
                  return c.name.toLowerCase().contains(q) ||
                      c.phone.contains(q) ||
                      c.address.toLowerCase().contains(q);
                }).toList();

                return Scaffold(
                  appBar: AppBar(
                    title: Text(s.t('customers_title')),
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    actions: [
                      TextButton.icon(
                        onPressed: () => _handleExcelUpload(context, s),
                        icon: const Icon(Icons.upload_file_rounded,
                            color: Colors.white, size: 18),
                        label: Text(
                          s.t('upload_excel'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        children: [
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) =>
                                      setState(() => _query = v.trim()),
                                  decoration: InputDecoration(
                                    hintText: s.t('search_customers'),
                                    prefixIcon:
                                        const Icon(Icons.search, size: 18),
                                    suffixIcon: _query.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 16),
                                            onPressed: () {
                                              _searchCtrl.clear();
                                              setState(() => _query = '');
                                            },
                                          )
                                        : null,
                                    isDense: true,
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s.t('excel_columns_hint'),
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.people_outline_rounded,
                                              size: 48,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 10),
                                          Text(s.t('no_customers'),
                                              style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                            onPressed: () =>
                                                _handleExcelUpload(context, s),
                                            icon: const Icon(
                                                Icons.upload_file_rounded,
                                                size: 18),
                                            label: Text(s.t('upload_excel')),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 80),
                                    itemCount: filtered.length,
                                    itemBuilder: (ctx, i) {
                                      final c = filtered[i];
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border:
                                              Border.all(color: Colors.black12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor: primary
                                                      .withValues(alpha: 0.12),
                                                  child: Text(
                                                    c.name.isNotEmpty
                                                        ? c.name[0]
                                                            .toUpperCase()
                                                        : 'C',
                                                    style: TextStyle(
                                                        color: primary,
                                                        fontWeight:
                                                            FontWeight.w800),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        c.name,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 13.5),
                                                      ),
                                                      Text(
                                                        c.phone,
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors
                                                                .grey.shade700),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (c.source == 'excel')
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors
                                                          .green.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      'EXCEL',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors
                                                            .green.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 18),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () =>
                                                      _openCustomerEditor(
                                                          context, s, c),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 18,
                                                      color: Colors.red),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onPressed: () async {
                                                    final ok = await UiHelpers
                                                        .confirmDialog(
                                                      context,
                                                      title: s
                                                          .t('confirm_delete'),
                                                      message: s.t(
                                                          'delete_customer_q'),
                                                      confirmLabel:
                                                          s.t('delete'),
                                                      cancelLabel:
                                                          s.t('cancel'),
                                                      isDestructive: true,
                                                    );
                                                    if (!ok) return;
                                                    try {
                                                      await widget.service
                                                          .softDeleteCustomer(
                                                              c.id);
                                                      if (context.mounted) {
                                                        UiHelpers.showFeedback(
                                                            context,
                                                            s.t(
                                                                'customer_moved_bin'));
                                                      }
                                                    } catch (_) {
                                                      if (context.mounted) {
                                                        UiHelpers.showFeedback(
                                                            context,
                                                            s.t(
                                                                'action_failed'),
                                                            isError: true);
                                                      }
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                            if (c.address.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                c.address,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.grey.shade700),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                    onPressed: () =>
                                                        WhatsAppService
                                                            .openDirectChat(
                                                      phone: c.phone,
                                                      message: '',
                                                    ),
                                                    icon: const Icon(
                                                        Icons.chat_outlined,
                                                        size: 14),
                                                    label: Text(
                                                        s.t('send_whatsapp'),
                                                        style: const TextStyle(
                                                            fontSize: 11.5)),
                                                  ),
                                                ),
                                                if (widget.onTakeOrder !=
                                                    null) ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: FilledButton.icon(
                                                      style: FilledButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            primary,
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        widget.onTakeOrder!(c);
                                                      },
                                                      icon: const Icon(
                                                          Icons
                                                              .add_shopping_cart,
                                                          size: 14),
                                                      label: Text(
                                                          s.t('take_order_for'),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      11.5)),
                                                    ),
                                                  ),
                                                ],
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
                    ),
                  ),
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _openCustomerEditor(context, s),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(s.t('add_customer')),
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
