import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';
import '../services/whatsapp_service.dart';

class TemplatesScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final AppStrings s;

  const TemplatesScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.products,
    required this.templates,
    required this.s,
  });

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  final _phoneCtrl = TextEditingController();
  String _selectedProductId = ''; // empty = All Products
  final Map<String, String> _cardLang = {}; // tplId -> 'ml' | 'en' | 'manglish'

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEditor([TemplateModel? existing]) async {
    final s = widget.s;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final mlCtrl = TextEditingController(text: existing?.bodyMl ?? '');
    final enCtrl = TextEditingController(text: existing?.bodyEn ?? '');
    final manglishCtrl =
        TextEditingController(text: existing?.bodyManglish ?? '');
    String targetProductId = widget.products.any((p) => p.id == (existing?.productId ?? _selectedProductId))
        ? (existing?.productId ?? _selectedProductId)
        : '';
    int activeLangTab = 0; // 0=ML, 1=EN, 2=Manglish

    final vars = TemplateEngine.allAvailableVariables(widget.profile);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          TextEditingController currentBodyCtrl() {
            if (activeLangTab == 1) return enCtrl;
            if (activeLangTab == 2) return manglishCtrl;
            return mlCtrl;
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? s.t('add_template')
                        : s.t('edit_template'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: s.t('template_title'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: targetProductId,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: s.t('active_product'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: '', child: Text(s.t('all_products'))),
                      ...widget.products.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          )),
                    ],
                    onChanged: (v) =>
                        setModalState(() => targetProductId = v ?? ''),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(s.t('lang_ml'))),
                      ButtonSegment(value: 1, label: Text(s.t('lang_en'))),
                      ButtonSegment(
                          value: 2, label: Text(s.t('lang_manglish'))),
                    ],
                    selected: {activeLangTab},
                    onSelectionChanged: (set) =>
                        setModalState(() => activeLangTab = set.first),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentBodyCtrl(),
                    maxLines: 7,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(s.t('insert_variable'),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: vars
                        .map((v) => ActionChip(
                              label:
                                  Text(v, style: const TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final c = currentBodyCtrl();
                                final txt = c.text;
                                c.text = '$txt$v';
                                c.selection = TextSelection.collapsed(
                                    offset: c.text.length);
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (existing != null)
                        TextButton(
                          onPressed: () async {
                            final ok = await UiHelpers.confirmDialog(
                              ctx,
                              title: s.t('confirm_delete'),
                              message: s.t('delete_template_q'),
                              confirmLabel: s.t('delete'),
                              cancelLabel: s.t('cancel'),
                              isDestructive: true,
                            );
                            if (!ok) return;
                            try {
                              await widget.service.softDeleteTemplate(existing);
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                UiHelpers.showFeedback(
                                    context, s.t('template_moved_bin'));
                              }
                            } catch (_) {
                              if (mounted) {
                                UiHelpers.showFeedback(
                                    context, s.t('action_failed'),
                                    isError: true);
                              }
                            }
                          },
                          child: Text(s.t('delete'),
                              style: const TextStyle(color: Colors.red)),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          if (titleCtrl.text.trim().isEmpty) return;
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
                          try {
                            await widget.service.saveTemplate(TemplateModel(
                              id: existing?.id ?? '',
                              order: existing?.order ??
                                  (widget.templates.length + 1),
                              title: titleCtrl.text.trim(),
                              stage: existing?.stage ?? 'custom',
                              bodyMl: mlCtrl.text,
                              bodyEn: enCtrl.text,
                              bodyManglish: manglishCtrl.text,
                              productId: targetProductId,
                            ));
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              UiHelpers.showFeedback(
                                  context, s.t('template_saved'));
                            }
                          } catch (_) {
                            if (mounted) {
                              UiHelpers.showFeedback(
                                  context, s.t('action_failed'),
                                  isError: true);
                            }
                          }
                        },
                        child: Text(s.t('save')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final primary = Color(widget.profile.primaryColorHex);
    final activeProducts = widget.products.where((p) => p.active).toList();
    final safeSelectedId = activeProducts.any((p) => p.id == _selectedProductId)
        ? _selectedProductId
        : '';

    final selectedProduct = safeSelectedId.isEmpty
        ? null
        : activeProducts.cast<ProductModel?>().firstWhere(
              (p) => p?.id == safeSelectedId,
              orElse: () => null,
            );

    final visibleTemplates = widget.templates.where((t) {
      if (t.productId.isEmpty) return true;
      if (safeSelectedId.isEmpty) return true;
      return t.productId == safeSelectedId;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: s.t('quick_phone'),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => _phoneCtrl.clear(),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: safeSelectedId,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: s.t('active_product'),
                    prefixIcon:
                        const Icon(Icons.inventory_2_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: '', child: Text(s.t('all_products'))),
                    ...activeProducts.map((p) =>
                        DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedProductId = v ?? ''),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
              itemCount: visibleTemplates.length,
              itemBuilder: (ctx, i) {
                final tpl = visibleTemplates[i];
                final idxLabel = (i + 1).toString().padLeft(2, '0');
                final lang = _cardLang[tpl.id] ??
                    (widget.profile.appLanguage == 'en' ? 'en' : 'ml');
                final rendered = TemplateEngine.render(
                  templateBody: tpl.bodyForLang(lang),
                  profile: widget.profile,
                  products: widget.products,
                  selectedProduct: selectedProduct,
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 2),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      leading: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          idxLabel,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        tpl.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      subtitle: tpl.productId.isNotEmpty
                          ? Text(
                              s.t('product_specific_badge'),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.orange.shade800),
                            )
                          : null,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
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
                            selected: {lang},
                            onSelectionChanged: (set) =>
                                setState(() => _cardLang[tpl.id] = set.first),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7FFDB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            rendered,
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () => WhatsAppService.openDirectChat(
                                  phone: _phoneCtrl.text,
                                  message: rendered,
                                ),
                                icon:
                                    const Icon(Icons.send_rounded, size: 15),
                                label: Text(s.t('send_whatsapp'),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              onPressed: () async {
                                await WhatsAppService.copyMessage(rendered);
                                if (context.mounted) {
                                  UiHelpers.showFeedback(context, s.t('copied'));
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: Text(s.t('copy'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 4),
                            IconButton.outlined(
                              visualDensity: VisualDensity.compact,
                              tooltip: s.t('share'),
                              onPressed: () =>
                                  WhatsAppService.shareMessage(rendered),
                              icon: const Icon(Icons.share_rounded, size: 16),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: s.t('edit'),
                              onPressed: () => _openEditor(tpl),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _openEditor(),
        tooltip: s.t('add_template'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
