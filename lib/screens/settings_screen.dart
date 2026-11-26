import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/business_profile.dart';
import '../models/delivery_rules.dart';
import '../models/template_model.dart';
import '../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  final FirestoreService service;
  final BusinessProfile profile;
  final DeliveryRules rules;
  final List<TemplateModel> templates;

  const SettingsScreen({
    super.key,
    required this.service,
    required this.profile,
    required this.rules,
    required this.templates,
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
  late TextEditingController _reviewCtrl;
  late TextEditingController _courierCtrl;
  late TextEditingController _trackingUrlCtrl;
  late TextEditingController _flatCtrl;
  late TextEditingController _thresholdCtrl;
  late TextEditingController _belowCtrl;
  late DeliveryMode _mode;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController(text: widget.profile.brandName);
    _taglineCtrl = TextEditingController(text: widget.profile.tagline);
    _phoneCtrl = TextEditingController(text: widget.profile.phone);
    _websiteCtrl = TextEditingController(text: widget.profile.website);
    _instaCtrl = TextEditingController(text: widget.profile.instagramHandle);
    _reviewCtrl = TextEditingController(text: widget.profile.reviewUrl);
    _courierCtrl = TextEditingController(text: widget.profile.courierName);
    _trackingUrlCtrl = TextEditingController(text: widget.profile.trackingUrl);
    _flatCtrl = TextEditingController(text: '${widget.rules.flatCharge.toInt()}');
    _thresholdCtrl = TextEditingController(
        text: '${widget.rules.freeThresholdAmount.toInt()}');
    _belowCtrl = TextEditingController(
        text: '${widget.rules.belowThresholdCharge.toInt()}');
    _mode = widget.rules.mode;
  }

  Future<void> _saveSettings() async {
    await widget.service.saveBusinessProfile(
      widget.profile.copyWith(
        brandName: _brandCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        instagramHandle: _instaCtrl.text.trim(),
        reviewUrl: _reviewCtrl.text.trim(),
        courierName: _courierCtrl.text.trim(),
        trackingUrl: _trackingUrlCtrl.text.trim(),
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
        const SnackBar(content: Text('Settings Saved ✅')),
      );
    }
  }

  Future<void> _editTemplate(TemplateModel tpl) async {
    final ctrl = TextEditingController(text: tpl.body);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${tpl.title}'),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated != null) {
      await widget.service.saveTemplate(TemplateModel(
        id: tpl.id,
        order: tpl.order,
        title: tpl.title,
        stage: tpl.stage,
        body: updated,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('White-Label Business Profile',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextField(
                    controller: _brandCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Business Name',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _taglineCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Tagline',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Business WhatsApp Phone',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _websiteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Website',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _instaCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Instagram Handle',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _reviewCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Google Review Link',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _courierCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Courier Name',
                        border: OutlineInputBorder(),
                        isDense: true)),
                const SizedBox(height: 8),
                TextField(
                    controller: _trackingUrlCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Courier Tracking URL',
                        border: OutlineInputBorder(),
                        isDense: true)),
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
                const Text('Delivery Charge Rules Engine',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                RadioListTile<DeliveryMode>(
                  title: const Text('Per Pack (ഓരോ പാക്കിനും വെവ്വേറെ)'),
                  value: DeliveryMode.perPack,
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                RadioListTile<DeliveryMode>(
                  title: const Text('Free Above Order Total (പരിധിക്ക് മുകളിൽ സൗജന്യം)'),
                  value: DeliveryMode.cartThreshold,
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                if (_mode == DeliveryMode.cartThreshold)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _thresholdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Free Above ₹',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _belowCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Below Charge ₹',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                    ],
                  ),
                RadioListTile<DeliveryMode>(
                  title: const Text('Flat Charge Per Order (എല്ലാ ഓർഡറിനും ഒറ്റ ചാർജ്)'),
                  value: DeliveryMode.flatPerOrder,
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                ),
                if (_mode == DeliveryMode.flatPerOrder)
                  TextField(
                    controller: _flatCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Flat Delivery Charge ₹',
                        border: OutlineInputBorder(),
                        isDense: true),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Business & Delivery Settings'),
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
                const Text('WhatsApp Templates (Tap to Edit)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...widget.templates.map((t) => ListTile(
                      dense: true,
                      title: Text(t.title),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _editTemplate(t),
                    )),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await widget.service.seedLakfaDefaults();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Lakfa Foods Default Data Loaded ✅')),
                            );
                          }
                        },
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Load Lakfa Defaults'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
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
