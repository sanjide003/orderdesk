import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../services/app_strings.dart';
import '../services/firestore_service.dart';
import '../services/lakfa_seed_data.dart';
import '../services/ui_helpers.dart';

class SettingsScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final DeliveryRules rules;
  final AppStrings s;
  final bool embedded;

  const SettingsScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.s,
    this.embedded = false,
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
  late List<CustomProfileField> _customFields;
  final List<TextEditingController> _customValueCtrls = [];
  bool _saving = false;

  static const List<int> _presetColors = [
    0xFF0F766E,
    0xFF1D4ED8,
    0xFF15803D,
    0xFFB45309,
    0xFF7C3AED,
    0xFFBE123C,
  ];

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController();
    _taglineCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _instaCtrl = TextEditingController();
    _instaUrlCtrl = TextEditingController();
    _reviewCtrl = TextEditingController();
    _courierCtrl = TextEditingController();
    _trackingUrlCtrl = TextEditingController();
    _bankCtrl = TextEditingController();
    _flatCtrl = TextEditingController();
    _thresholdCtrl = TextEditingController();
    _belowCtrl = TextEditingController();
    _applyFromData(widget.profile, widget.rules);
  }

  void _applyFromData(BusinessProfile profile, DeliveryRules rules) {
    _brandCtrl.text = profile.brandName;
    _taglineCtrl.text = profile.tagline;
    _phoneCtrl.text = profile.phone;
    _websiteCtrl.text = profile.website;
    _instaCtrl.text = profile.instagramHandle;
    _instaUrlCtrl.text = profile.instagramUrl;
    _reviewCtrl.text = profile.reviewUrl;
    _courierCtrl.text = profile.courierName;
    _trackingUrlCtrl.text = profile.trackingUrl;
    _bankCtrl.text = profile.paymentBankLabel;
    _flatCtrl.text = '${rules.flatCharge.toInt()}';
    _thresholdCtrl.text = '${rules.freeThresholdAmount.toInt()}';
    _belowCtrl.text = '${rules.belowThresholdCharge.toInt()}';
    _mode = rules.mode;
    _colorHex = widget.service.colorNotifier.value ?? profile.primaryColorHex;
    _customFields = List<CustomProfileField>.from(profile.customFields);
    for (final c in _customValueCtrls) {
      c.dispose();
    }
    _customValueCtrls.clear();
    for (final cf in _customFields) {
      _customValueCtrls.add(TextEditingController(text: cf.value));
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _taglineCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _instaCtrl.dispose();
    _instaUrlCtrl.dispose();
    _reviewCtrl.dispose();
    _courierCtrl.dispose();
    _trackingUrlCtrl.dispose();
    _bankCtrl.dispose();
    _flatCtrl.dispose();
    _thresholdCtrl.dispose();
    _belowCtrl.dispose();
    for (final c in _customValueCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _openCustomFieldDialog(AppStrings s, {int? editIndex}) async {
    final existing = editIndex != null ? _customFields[editIndex] : null;
    final currentVal = editIndex != null
        ? _customValueCtrls[editIndex].text
        : '';
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final valueCtrl = TextEditingController(text: currentVal);
    final result = await showDialog<CustomProfileField>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? s.t('add_custom_field')
            : s.t('edit_custom_field')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: s.t('field_label'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valueCtrl,
              decoration: InputDecoration(
                labelText: s.t('field_value'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel'))),
          FilledButton(
            onPressed: () {
              final lbl = labelCtrl.text.trim();
              if (lbl.isEmpty) return;
              Navigator.pop(
                ctx,
                CustomProfileField(
                  key: CustomProfileField.normalizeKey(lbl),
                  label: lbl,
                  value: valueCtrl.text.trim(),
                ),
              );
            },
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        if (editIndex != null) {
          _customFields[editIndex] = result;
          _customValueCtrls[editIndex].text = result.value;
        } else {
          _customFields.add(result);
          _customValueCtrls.add(TextEditingController(text: result.value));
        }
      });
    }
  }

  Future<void> _saveSettings(
      BusinessProfile latestProfile, AppStrings s) async {
    final ok = await UiHelpers.confirmDialog(
      context,
      title: s.t('confirm_save'),
      message: s.t('save_changes_q'),
      confirmLabel: s.t('save'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      final syncedCustomFields = [
        for (int i = 0; i < _customFields.length; i++)
          CustomProfileField(
            key: _customFields[i].key,
            label: _customFields[i].label,
            value: i < _customValueCtrls.length
                ? _customValueCtrls[i].text.trim()
                : _customFields[i].value,
          ),
      ];
      await widget.service.saveBusinessProfile(
        latestProfile.copyWith(
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
          appLanguage:
              widget.service.languageNotifier.value ?? latestProfile.appLanguage,
          primaryColorHex: _colorHex,
          customFields: syncedCustomFields,
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
        UiHelpers.showFeedback(context, s.t('settings_saved'));
      }
    } catch (_) {
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLoadDefaults(AppStrings s) async {
    final ok = await UiHelpers.confirmDialog(
      context,
      title: s.t('load_lakfa_defaults'),
      message: s.t('load_defaults_q'),
      confirmLabel: s.t('save'),
      cancelLabel: s.t('cancel'),
    );
    if (!ok) return;
    try {
      await widget.service.seedLakfaDefaults();
      if (mounted) {
        setState(() {
          _applyFromData(LakfaSeedData.profile, LakfaSeedData.deliveryRules);
        });
        UiHelpers.showFeedback(context, s.t('defaults_loaded'));
      }
    } catch (_) {
      if (mounted) {
        UiHelpers.showFeedback(context, s.t('action_failed'), isError: true);
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
    return ValueListenableBuilder<String?>(
      valueListenable: widget.service.languageNotifier,
      builder: (context, langOverride, _) {
        return StreamBuilder<BusinessProfile>(
          stream: widget.service.watchBusinessProfile(),
          initialData: widget.profile,
          builder: (context, profSnap) {
            final liveProfile = profSnap.data ?? widget.profile;
            final currentLang = langOverride ?? liveProfile.appLanguage;
            final s = AppStrings(currentLang);
            final primary = Color(_colorHex);

            return Scaffold(
              backgroundColor: widget.embedded
                  ? Colors.transparent
                  : const Color(0xFFF4F7F6),
              appBar: widget.embedded
                  ? null
                  : AppBar(
                      title: Text(s.t('tile_business_app')),
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _CardBox(
                        title: s.t('app_language'),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'en', label: Text('English')),
                              ButtonSegment(
                                  value: 'ml', label: Text('മലയാളം')),
                            ],
                            selected: {currentLang},
                            onSelectionChanged: (set) async {
                              final nextLang = set.first;
                              try {
                                await widget.service
                                    .updateAppLanguage(nextLang);
                                if (context.mounted) {
                                  UiHelpers.showFeedback(
                                    context,
                                    AppStrings(nextLang).t('language_updated'),
                                  );
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
                        ),
                      ),
                      const SizedBox(height: 10),
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
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: _presetColors.map((hex) {
                                final selected = _colorHex == hex;
                                return InkWell(
                                  onTap: () {
                                    setState(() => _colorHex = hex);
                                    widget.service.colorNotifier.value = hex;
                                  },
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Color(hex),
                                      shape: BoxShape.circle,
                                      border: selected
                                          ? Border.all(
                                              color: Colors.black, width: 2.5)
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
                      _CardBox(
                        title: s.t('custom_fields'),
                        trailing: TextButton.icon(
                          onPressed: () => _openCustomFieldDialog(s),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(s.t('add_custom_field'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('custom_fields_sub'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                            const SizedBox(height: 10),
                            ..._customFields.asMap().entries.map((entry) {
                              final i = entry.key;
                              final cf = entry.value;
                              final ctrl = _customValueCtrls[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: ctrl,
                                        decoration: InputDecoration(
                                          labelText:
                                              '${cf.label} ({{${cf.key}}})',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip: s.t('edit'),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _openCustomFieldDialog(
                                          s,
                                          editIndex: i),
                                    ),
                                    IconButton(
                                      tooltip: s.t('delete'),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () async {
                                        final ok =
                                            await UiHelpers.confirmDialog(
                                          context,
                                          title: s.t('delete'),
                                          message: s.t('delete_field_q'),
                                          confirmLabel: s.t('delete'),
                                          cancelLabel: s.t('cancel'),
                                          isDestructive: true,
                                        );
                                        if (ok) {
                                          setState(() {
                                            _customFields.removeAt(i);
                                            _customValueCtrls
                                                .removeAt(i)
                                                .dispose();
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CardBox(
                        title: s.t('delivery_rules'),
                        child: Column(
                          children: [
                            RadioGroup<DeliveryMode>(
                              groupValue: _mode,
                              onChanged: (v) {
                                if (v != null) setState(() => _mode = v);
                              },
                              child: Column(
                                children: [
                                  RadioListTile<DeliveryMode>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(s.t('mode_per_pack'),
                                        style: const TextStyle(fontSize: 13)),
                                    value: DeliveryMode.perPack,
                                  ),
                                  RadioListTile<DeliveryMode>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(s.t('mode_threshold'),
                                        style: const TextStyle(fontSize: 13)),
                                    value: DeliveryMode.cartThreshold,
                                  ),
                                  if (_mode == DeliveryMode.cartThreshold)
                                    Row(
                                      children: [
                                        Expanded(
                                            child: _field(_thresholdCtrl,
                                                s.t('free_above'),
                                                type: TextInputType.number)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: _field(_belowCtrl,
                                                s.t('below_charge'),
                                                type: TextInputType.number)),
                                      ],
                                    ),
                                  RadioListTile<DeliveryMode>(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(s.t('mode_flat'),
                                        style: const TextStyle(fontSize: 13)),
                                    value: DeliveryMode.flatPerOrder,
                                  ),
                                  if (_mode == DeliveryMode.flatPerOrder)
                                    _field(_flatCtrl, s.t('flat_charge'),
                                        type: TextInputType.number),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _saveSettings(liveProfile, s),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.save, size: 18),
                                label: Text(s.t('save_settings')),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmLoadDefaults(s),
                              icon: const Icon(Icons.auto_fix_high, size: 16),
                              label: Text(s.t('load_lakfa_defaults'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final ok = await UiHelpers.confirmDialog(
                                context,
                                title: s.t('confirm_sign_out'),
                                message: s.t('sign_out_q'),
                                confirmLabel: s.t('sign_out'),
                                cancelLabel: s.t('cancel'),
                                isDestructive: true,
                              );
                              if (!ok) return;
                              if (!widget.embedded &&
                                  context.mounted &&
                                  Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              await FirebaseAuth.instance.signOut();
                            },
                            icon: const Icon(Icons.logout,
                                size: 16, color: Colors.red),
                            label: Text(s.t('sign_out'),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red)),
                          ),
                        ],
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
