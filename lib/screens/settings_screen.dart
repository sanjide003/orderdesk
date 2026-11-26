import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/template_model.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final DeliveryRules rules;
  final List<TemplateModel> templates;
  final AppStrings s;

  const SettingsScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.templates,
    required this.s,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _brandCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _instaCtrl;
  late TextEditingController _instaUrlCtrl;
  late TextEditingController _reviewCtrl;
  late TextEditingController _courierCtrl;
  late TextEditingController _trackingUrlCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _flatCtrl;
  late TextEditingController _thresholdCtrl;
  late TextEditingController _belowCtrl;
  late DeliveryMode _mode;
  late int _colorHex;

  static const List<int> _presetColors = [
    0xFF0F766E, // Ocean Teal
    0xFF1D4ED8, // Royal Blue
    0xFF15803D, // Forest Green
    0xFFB45309, // Warm Amber
    0xFF7C3AED, // Deep Violet
    0xFFBE123C, // Crimson
  ];

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  void _syncFromWidget() {
    _brandCtrl = TextEditingController(text: widget.profile.brandName);
    _taglineCtrl = TextEditingController(text: widget.profile.tagline);
    _phoneCtrl = TextEditingController(text: widget.profile.phone);
    _websiteCtrl = TextEditingController(text: widget.profile.website);
    _instaCtrl = TextEditingController(text: widget.profile.instagramHandle);
    _instaUrlCtrl = TextEditingController(text: widget.profile.instagramUrl);
    _reviewCtrl = TextEditingController(text: widget.profile.reviewUrl);
    _courierCtrl = TextEditingController(text: widget.profile.courierName);
    _trackingUrlCtrl = TextEditingController(text: widget.profile.trackingUrl);
    _bankCtrl = TextEditingController(text: widget.profile.paymentBankLabel);
    _flatCtrl =
        TextEditingController(text: '${widget.rules.flatCharge.toInt()}');
    _thresholdCtrl = TextEditingController(
        text: '${widget.rules.freeThresholdAmount.toInt()}');
    _belowCtrl = TextEditingController(
        text: '${widget.rules.belowThresholdCharge.toInt()}');
    _mode = widget.rules.mode;
    _colorHex = widget.profile.primaryColorHex;
  }

  Future<void> _saveSettings() async {
    await widget.service.saveBusinessProfile(
      widget.profile.copyWith(
        brandName: _brandCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        instagramHandle: _instaCtrl.text.trim(),
        instagramUrl: _instaUrlCtrl.text.trim(),
        reviewUrl: _reviewCtrl.text.trim(),
        courierName: _courierCtrl.text.trim(),
        trackingUrl: _trackingUrlCtrl.text.trim(),
        paymentBankLabel: _bankCtrl.text.trim(),
        primaryColorHex: _colorHex,
      ),
    );
    await widget.service.saveDeliveryRules(
      DeliveryRules(
        mode: _mode,
        flatCharge: double.tryParse(_flatCtrl.text) ?? 50,
        freeThresholdAmount: double.tryParse(_thresholdCtrl.text) ?? 1000,
        belowThresholdCharge: double.tryParse(_belowCtrl.text) ?? 50,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.s.t('settings_saved'))),
      );
    }
  }

  Future<void> _openTemplateEditor([TemplateModel? existing]) async {
    final s = widget.s;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final saved = await showModalBottomSheet<bool>(
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
                existing == null ? s.t('add_template') : s.t('edit_template'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
              TextField(
                controller: bodyCtrl,
                maxLines: 9,
                decoration: InputDecoration(
                  labelText: s.t('template_body'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 6),
              Text(s.t('placeholders_hint'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.t('save')),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && titleCtrl.text.trim().isNotEmpty) {
      await widget.service.saveTemplate(TemplateModel(
        id: existing?.id ?? '',
        order: existing?.order ?? (widget.templates.length + 1),
        title: titleCtrl.text.trim(),
        stage: existing?.stage ?? 'custom',
        body: bodyCtrl.text,
      ));
    }
  }

  Future<void> _confirmLoadDefaults() async {
    final s = widget.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('load_lakfa_defaults')),
        content: Text(s.t('load_defaults_q')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.service.seedLakfaDefaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('defaults_loaded'))),
        );
      }
    }
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final currentLang = widget.profile.appLanguage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      children: [
        // 1. APP LANGUAGE SWITCHER (EN / ML)
        _CardBox(
          title: s.t('app_language'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('lang_desc'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'ml', label: Text('മലയാളം')),
                  ],
                  selected: {currentLang},
                  onSelectionChanged: (set) {
                    widget.service.updateAppLanguage(set.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 2. BUSINESS PROFILE
        _CardBox(
          title: s.t('business_profile'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_brandCtrl, s.t('brand_name')),
              _field(_taglineCtrl, s.t('tagline')),
              _field(_phoneCtrl, s.t('business_phone'),
                  type: TextInputType.phone),
              _field(_websiteCtrl, s.t('website')),
              _field(_instaCtrl, s.t('instagram_handle')),
              _field(_instaUrlCtrl, s.t('instagram_url')),
              _field(_reviewCtrl, s.t('review_url')),
              _field(_courierCtrl, s.t('courier_name')),
              _field(_trackingUrlCtrl, s.t('tracking_url')),
              _field(_bankCtrl, s.t('payment_bank')),
              const SizedBox(height: 4),
              Text(s.t('theme_color'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _presetColors.map((hex) {
                  final selected = _colorHex == hex;
                  return InkWell(
                    onTap: () => setState(() => _colorHex = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(hex),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.black, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 3. DELIVERY RULES
        _CardBox(
          title: s.t('delivery_rules'),
          child: Column(
            children: [
              RadioListTile<DeliveryMode>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.t('mode_per_pack'),
                    style: const TextStyle(fontSize: 13)),
                value: DeliveryMode.perPack,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
              ),
              RadioListTile<DeliveryMode>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.t('mode_threshold'),
                    style: const TextStyle(fontSize: 13)),
                value: DeliveryMode.cartThreshold,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
              ),
              if (_mode == DeliveryMode.cartThreshold)
                Row(
                  children: [
                    Expanded(
                        child: _field(_thresholdCtrl, s.t('free_above'),
                            type: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _field(_belowCtrl, s.t('below_charge'),
                            type: TextInputType.number)),
                  ],
                ),
              RadioListTile<DeliveryMode>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s.t('mode_flat'),
                    style: const TextStyle(fontSize: 13)),
                value: DeliveryMode.flatPerOrder,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
              ),
              if (_mode == DeliveryMode.flatPerOrder)
                _field(_flatCtrl, s.t('flat_charge'),
                    type: TextInputType.number),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(s.t('save_settings')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 4. TEMPLATES & ACCOUNT
        _CardBox(
          title: s.t('templates_section'),
          trailing: TextButton.icon(
            onPressed: () => _openTemplateEditor(),
            icon: const Icon(Icons.add, size: 16),
            label: Text(s.t('add_template'),
                style: const TextStyle(fontSize: 12)),
          ),
          child: Column(
            children: [
              ...widget.templates.map((t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.title, style: const TextStyle(fontSize: 13)),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => _openTemplateEditor(t),
                  )),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _confirmLoadDefaults,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: Text(s.t('load_lakfa_defaults'),
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, size: 16, color: Colors.red),
                    label: Text(s.t('sign_out'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red)),
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

class _CardBox extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _CardBox({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
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
