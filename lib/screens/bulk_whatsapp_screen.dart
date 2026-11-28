import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/template_engine.dart';
import '../services/ui_helpers.dart';
import '../services/whatsapp_formatter.dart';
import '../services/whatsapp_service.dart';
import '../widgets/whatsapp_rich_text.dart';

enum BulkAudienceFilter { allCustomers, pendingPaymentOrders, dispatchedOrders }

class _BulkRecipient {
  final String key;
  final String name;
  final String phone;
  final String address;
  final String customerId;
  final OrderModel? order;
  final String subtitle;

  const _BulkRecipient({
    required this.key,
    required this.name,
    required this.phone,
    required this.address,
    this.customerId = '',
    this.order,
    this.subtitle = '',
  });
}

class BulkWhatsAppScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final List<ProductModel> products;
  final List<TemplateModel> templates;
  final List<OrderModel> orders;
  final AppStrings s;
  final bool embedded;
  final BulkAudienceFilter initialAudience;

  const BulkWhatsAppScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.products,
    required this.templates,
    required this.orders,
    required this.s,
    this.embedded = false,
    this.initialAudience = BulkAudienceFilter.allCustomers,
  });

  @override
  State<BulkWhatsAppScreen> createState() => _BulkWhatsAppScreenState();
}

class _BulkWhatsAppScreenState extends State<BulkWhatsAppScreen> {
  late BulkAudienceFilter _audience;
  final _searchCtrl = TextEditingController();
  final _customBodyCtrl = TextEditingController();
  final _bodyFocus = FocusNode();
  String _query = '';
  String _prevCustomBody = '';
  final Set<String> _selectedKeys = {};
  bool _useTemplate = true;
  String _selectedTemplateId = '';
  String _lang = 'ml';

  // Queue execution state
  bool _inQueue = false;
  List<_BulkRecipient> _queue = [];
  int _queueIndex = 0;
  int _sentCount = 0;
  int _skippedCount = 0;

  @override
  void initState() {
    super.initState();
    _audience = widget.initialAudience;
    _lang = widget.profile.appLanguage == 'en' ? 'en' : 'ml';
    if (widget.templates.isNotEmpty) {
      _selectedTemplateId = widget.templates.first.id;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customBodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  List<_BulkRecipient> _buildCandidates(List<CustomerModel> customers) {
    final List<_BulkRecipient> list = [];
    if (_audience == BulkAudienceFilter.allCustomers) {
      for (final c in customers) {
        if (c.phone.trim().isEmpty) continue;
        list.add(_BulkRecipient(
          key: 'c_${c.id}',
          name: c.name,
          phone: c.phone,
          address: c.address,
          customerId: c.id,
          subtitle: c.address.isNotEmpty ? c.address : c.phone,
        ));
      }
    } else if (_audience == BulkAudienceFilter.pendingPaymentOrders) {
      for (final o in widget.orders.where((o) => o.isPaymentPending)) {
        if (o.phone.trim().isEmpty) continue;
        list.add(_BulkRecipient(
          key: 'o_${o.id}',
          name: o.customerName,
          phone: o.phone,
          address: o.address,
          order: o,
          subtitle:
              '${o.status} · ${o.paymentStatus} (Due ${TemplateEngine.formatMoney(o.balanceDue)})',
        ));
      }
    } else {
      for (final o in widget.orders
          .where((o) => o.status == 'Dispatched' || o.status == 'Delivered')) {
        if (o.phone.trim().isEmpty) continue;
        list.add(_BulkRecipient(
          key: 'o_${o.id}',
          name: o.customerName,
          phone: o.phone,
          address: o.address,
          order: o,
          subtitle:
              '${o.status} · ${o.paymentStatus}${o.trackingId.isNotEmpty ? " · ${o.trackingId}" : ""}',
        ));
      }
    }

    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.phone.contains(q) ||
            r.subtitle.toLowerCase().contains(q))
        .toList();
  }

  TemplateModel? _activeTemplate(List<TemplateModel> templates) {
    if (templates.isEmpty) return null;
    for (final t in templates) {
      if (t.id == _selectedTemplateId) return t;
    }
    return templates.first;
  }

  String _renderForRecipient(
    _BulkRecipient recipient,
    BusinessProfile profile,
    List<TemplateModel> templates,
  ) {
    final tpl = _activeTemplate(templates);
    final rawBody = _useTemplate
        ? (tpl?.bodyForLang(_lang) ?? '')
        : _customBodyCtrl.text;
    final o = recipient.order;
    return TemplateEngine.render(
      templateBody: rawBody,
      profile: profile,
      products: widget.products,
      orderItems: o?.items ?? const [],
      subtotal: o?.subtotal ?? 0,
      discountAmount: o?.discountAmount ?? 0,
      discountPercent: o?.discountPercent ?? 0,
      deliveryCharge: o?.deliveryCharge ?? 0,
      totalAmount: o?.totalAmount ?? 0,
      paidAmount: o?.effectivePaidAmount ?? 0,
      balanceDue: o?.balanceDue ?? 0,
      customerName: recipient.name,
      customerPhone: recipient.phone,
      customerAddress: recipient.address,
      packSummary: o?.itemsSummary ?? '',
      trackingId: o?.trackingId ?? 'RXXXXXXXXXX',
    );
  }

  Widget _buildThreeRowVariableChips(BusinessProfile profile) {
    final vars = TemplateEngine.allAvailableVariables(profile);
    final rows = [
      <String>[],
      <String>[],
      <String>[],
    ];
    for (int i = 0; i < vars.length; i++) {
      rows[i % 3].add(vars[i]);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int r = 0; r < 3; r++)
            if (rows[r].isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: r < 2 ? 5 : 0),
                child: Row(
                  children: [
                    for (final v in rows[r])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(v, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            WhatsAppFormatter.insertAtCursor(
                                _customBodyCtrl, v);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _sendCurrentAndAdvance(
    BusinessProfile profile,
    List<TemplateModel> templates,
  ) async {
    if (_queueIndex >= _queue.length) return;
    final current = _queue[_queueIndex];
    final tpl = _activeTemplate(templates);
    final msg = _renderForRecipient(current, profile, templates);
    await WhatsAppService.openDirectChat(
      phone: current.phone,
      message: msg,
      logMeta: WhatsAppLogMeta(
        recipientName: current.name,
        orderId: current.order?.id ?? '',
        customerId: current.customerId,
        templateId: _useTemplate ? (tpl?.id ?? '') : '',
        templateTitle:
            _useTemplate ? (tpl?.title ?? '') : widget.s.t('custom_message'),
        stage: _useTemplate ? (tpl?.stage ?? '') : 'bulk',
        lang: _useTemplate ? _lang : profile.appLanguage,
        mode: 'bulk_queue',
      ),
    );
    if (!mounted) return;
    setState(() {
      _sentCount++;
      _queueIndex++;
    });
  }

  void _skipCurrent() {
    if (_queueIndex >= _queue.length) return;
    setState(() {
      _skippedCount++;
      _queueIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.service.languageNotifier,
      builder: (context, langOverride, _) {
        return StreamBuilder<BusinessProfile>(
          stream: widget.service.watchBusinessProfile(),
          initialData: widget.profile,
          builder: (context, profSnap) {
            final profile = profSnap.data ?? widget.profile;
            final s = AppStrings(langOverride ?? profile.appLanguage);
            final primary = Color(
                widget.service.colorNotifier.value ?? profile.primaryColorHex);

            return StreamBuilder<List<CustomerModel>>(
              stream: widget.service.watchCustomers(),
              builder: (context, custSnap) {
                final customers = custSnap.data ?? [];
                final candidates = _buildCandidates(customers);
                final templates = widget.templates;

                return Scaffold(
                  backgroundColor: widget.embedded
                      ? Colors.transparent
                      : const Color(0xFFF4F7F6),
                  appBar: widget.embedded
                      ? null
                      : AppBar(
                          title: Text(s.t('bulk_whatsapp_title')),
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: _inQueue
                          ? _buildQueueRunner(s, primary, profile, templates)
                          : _buildSetupView(
                              s, primary, profile, candidates, templates),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSetupView(
    AppStrings s,
    Color primary,
    BusinessProfile profile,
    List<_BulkRecipient> candidates,
    List<TemplateModel> templates,
  ) {
    final activeTpl = _activeTemplate(templates);
    final selectedList =
        candidates.where((c) => _selectedKeys.contains(c.key)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.t('bulk_notice_info'),
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                    child: Text(
                      s.t('select_recipients'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${_selectedKeys.length} ${s.t("recipients_selected")}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _audienceChip(BulkAudienceFilter.allCustomers,
                        s.t('filter_all_customers'), primary),
                    const SizedBox(width: 6),
                    _audienceChip(BulkAudienceFilter.pendingPaymentOrders,
                        s.t('filter_pending_pay'), primary),
                    const SizedBox(width: 6),
                    _audienceChip(BulkAudienceFilter.dispatchedOrders,
                        s.t('filter_dispatched'), primary),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: s.t('search_customers'),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final c in candidates) {
                          _selectedKeys.add(c.key);
                        }
                      });
                    },
                    child: Text(s.t('select_all'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedKeys.clear()),
                    child: Text(s.t('clear_selection'),
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: candidates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            s.t('no_customers'),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final c = candidates[i];
                          final checked = _selectedKeys.contains(c.key);
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: checked,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedKeys.add(c.key);
                                } else {
                                  _selectedKeys.remove(c.key);
                                }
                              });
                            },
                            title: Text(
                              '${c.name} · ${c.phone}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            subtitle: c.subtitle.isNotEmpty
                                ? Text(
                                    c.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('choose_message'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(s.t('use_template'),
                          style: const TextStyle(fontSize: 11.5)),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(s.t('custom_message'),
                          style: const TextStyle(fontSize: 11.5)),
                    ),
                  ],
                  selected: {_useTemplate},
                  onSelectionChanged: (set) =>
                      setState(() => _useTemplate = set.first),
                ),
              ),
              const SizedBox(height: 10),
              if (_useTemplate) ...[
                if (templates.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: activeTpl?.id,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: s.t('tile_templates'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: templates
                        .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.title,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedTemplateId = v);
                    },
                  ),
                const SizedBox(height: 8),
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
                    selected: {_lang},
                    onSelectionChanged: (set) =>
                        setState(() => _lang = set.first),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F6),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(10)),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_bold'),
                          icon: Icons.format_bold_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleInline(
                                _customBodyCtrl, WhatsAppInlineFormat.bold);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_italic'),
                          icon: Icons.format_italic_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleInline(
                                _customBodyCtrl, WhatsAppInlineFormat.italic);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_strike'),
                          icon: Icons.format_strikethrough_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleInline(_customBodyCtrl,
                                WhatsAppInlineFormat.strikethrough);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_mono'),
                          icon: Icons.data_object_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleInline(_customBodyCtrl,
                                WhatsAppInlineFormat.monospace);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_code'),
                          icon: Icons.code_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleInline(_customBodyCtrl,
                                WhatsAppInlineFormat.inlineCode);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        Container(
                          width: 1,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: Colors.grey.shade300,
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_bullet'),
                          icon: Icons.format_list_bulleted_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleLinePrefix(_customBodyCtrl,
                                WhatsAppLineFormat.bulletedList);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_number'),
                          icon: Icons.format_list_numbered_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleLinePrefix(_customBodyCtrl,
                                WhatsAppLineFormat.numberedList);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                        _MiniFormatBtn(
                          tooltip: s.t('fmt_quote'),
                          icon: Icons.format_quote_rounded,
                          onPressed: () {
                            WhatsAppFormatter.toggleLinePrefix(_customBodyCtrl,
                                WhatsAppLineFormat.blockQuote);
                            _prevCustomBody = _customBodyCtrl.text;
                            _bodyFocus.requestFocus();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                TextField(
                  focusNode: _bodyFocus,
                  controller: _customBodyCtrl,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: (_) {
                    final next = WhatsAppFormatter.handleEnterAutoContinue(
                      _customBodyCtrl,
                      _prevCustomBody,
                    );
                    _prevCustomBody = next;
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(s.t('insert_variable'),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                _buildThreeRowVariableChips(profile),
              ],
              const SizedBox(height: 10),
              if (selectedList.isNotEmpty) ...[
                Text(
                  '${s.t("recipient_preview")} (${selectedList.first.name})',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7FFDB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: WhatsAppRichText(
                    text: _renderForRecipient(
                        selectedList.first, profile, templates),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              final queue = candidates
                  .where((c) => _selectedKeys.contains(c.key))
                  .toList();
              if (queue.isEmpty) {
                UiHelpers.showFeedback(context, s.t('no_recipients_selected'),
                    isError: true);
                return;
              }
              if (!_useTemplate && _customBodyCtrl.text.trim().isEmpty) {
                UiHelpers.showFeedback(context, s.t('preview_empty'),
                    isError: true);
                return;
              }
              setState(() {
                _queue = queue;
                _queueIndex = 0;
                _sentCount = 0;
                _skippedCount = 0;
                _inQueue = true;
              });
            },
            icon: const Icon(Icons.campaign_rounded, size: 20),
            label: Text(
              '${s.t("start_queue")} (${selectedList.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueRunner(
    AppStrings s,
    Color primary,
    BusinessProfile profile,
    List<TemplateModel> templates,
  ) {
    final total = _queue.length;
    final done = _queueIndex >= total;
    final progress = total > 0 ? (_queueIndex / total).clamp(0.0, 1.0) : 1.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
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
                      child: Text(
                        '${s.t("queue_progress")}: ${_queueIndex.clamp(0, total)} / $total',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    Text(
                      '${s.t("sent_count")}: $_sentCount · ${s.t("skipped_count")}: $_skippedCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: const Color(0xFF16A34A),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: done
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 64, color: Color(0xFF16A34A)),
                        const SizedBox(height: 12),
                        Text(
                          s.t('queue_completed'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${s.t("sent_count")}: $_sentCount   ·   ${s.t("skipped_count")}: $_skippedCount',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => setState(() => _inQueue = false),
                          icon: const Icon(Icons.done_all_rounded),
                          label: Text(s.t('ok')),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _queue[_queueIndex].name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _queue[_queueIndex].phone,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          if (_queue[_queueIndex].subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _queue[_queueIndex].subtitle,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                          const Divider(height: 20),
                          Text(
                            s.t('recipient_preview'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7FFDB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: WhatsAppRichText(
                              text: _renderForRecipient(
                                  _queue[_queueIndex], profile, templates),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (!done) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _inQueue = false),
                  child: Text(s.t('cancel')),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _skipCurrent,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(s.t('skip_recipient')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () =>
                          _sendCurrentAndAdvance(profile, templates),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        s.t('send_next_log'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _audienceChip(
      BulkAudienceFilter filter, String label, Color primary) {
    final selected = _audience == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: primary,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) {
        setState(() {
          _audience = filter;
          _selectedKeys.clear();
        });
      },
      visualDensity: VisualDensity.compact,
    );
  }
}

class _MiniFormatBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniFormatBtn({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        canRequestFocus: false,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 42, minHeight: 40),
          child: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
        ),
      ),
    );
  }
}
