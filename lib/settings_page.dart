import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'account_password.dart';

class PdfTemplateInfo {
  final int id;
  final String name;
  final String style;
  final String description;
  final String recommendedFor;
  final IconData icon;
  final String tag;

  const PdfTemplateInfo({
    required this.id,
    required this.name,
    required this.style,
    required this.description,
    required this.recommendedFor,
    required this.icon,
    required this.tag,
  });
}

const pdfTemplates = [
  PdfTemplateInfo(
    id: 0,
    name: 'Thermal Receipt (80mm)',
    style: 'Compact & Paper-saving',
    description:
        'Standard thermal roll layout formatted for 80mm ESC/POS roll printers. Clean, high contrast, and rapid printing.',
    recommendedFor: 'Fast Food, Coffee Counters, POS printers',
    icon: Icons.receipt_long,
    tag: 'Standard POS',
  ),
  PdfTemplateInfo(
    id: 1,
    name: 'Executive Modern (A5)',
    style: 'Branded Letterhead',
    description:
        'Dual-column executive invoice featuring your store logo, formatted address, itemized charges, and customer feedback QR code.',
    recommendedFor: 'Cafés, Boutiques, Dine-in & Delivery',
    icon: Icons.description_outlined,
    tag: 'Executive',
  ),
  PdfTemplateInfo(
    id: 2,
    name: 'Itemized Breakdown (Detailed)',
    style: 'Full Audit Trail',
    description:
        'Detailed layout with line item tax basis points, discount disclosures, cashier details, and formatted receipt greetings.',
    recommendedFor: 'Formal Dining, GST Tax Invoices',
    icon: Icons.analytics_outlined,
    tag: 'Detailed',
  ),
];

class SettingsHub extends StatefulWidget {
  final CafeStore store;
  final int initialTab;
  const SettingsHub({super.key, required this.store, this.initialTab = 0});

  @override
  State<SettingsHub> createState() => _SettingsHubState();
}

class _SettingsHubState extends State<SettingsHub> {
  late int _activeTab = widget.initialTab;

  final _tabs = const [
    (title: 'Profile & DP', icon: Icons.account_circle_outlined),
    (title: 'Business Info', icon: Icons.storefront_outlined),
    (title: 'Subscription', icon: Icons.card_membership_outlined),
    (title: 'Team & Security', icon: Icons.shield_outlined),
    (title: 'Color Theme', icon: Icons.palette_outlined),
    (title: 'PDF Template', icon: Icons.picture_as_pdf_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final themePrimary = getActiveThemePrimary();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Settings & Preferences',
          'Configure your store profile, logo, subscription, appearance, and print templates.',
        ),
        const SizedBox(height: 8),
        // Modern Horizontal Tab Selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                for (int i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: Icon(
                        _tabs[i].icon,
                        size: 18,
                        color: _activeTab == i ? Colors.white : ink,
                      ),
                      label: Text(
                        _tabs[i].title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _activeTab == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _activeTab == i ? Colors.white : ink,
                        ),
                      ),
                      selected: _activeTab == i,
                      selectedColor: themePrimary,
                      backgroundColor: Colors.transparent,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (_) => setState(() => _activeTab = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Tab Content
        switch (_activeTab) {
          0 => _ProfileTab(store: widget.store),
          1 => _BusinessTab(store: widget.store),
          2 => _SubscriptionTab(store: widget.store),
          3 => _TeamTab(store: widget.store),
          4 => _ThemeTab(),
          _ => _PdfTemplateTab(),
        },
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 1. PROFILE & STORE DP TAB
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatefulWidget {
  final CafeStore store;
  const _ProfileTab({required this.store});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TextEditingController _prefixCtrl;
  late final TextEditingController _greetingCtrl;
  late final TextEditingController _reviewUrlCtrl;
  late final TextEditingController _urlCtrl;
  bool _saving = false;

  final _presetLogos = const [
    (
      name: 'Coffee Cup',
      url:
          'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Bakery',
      url:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=200&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Bistro',
      url:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=200&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Burger & Grill',
      url:
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&auto=format&fit=crop&q=80',
    ),
    (
      name: 'Fresh Juice',
      url:
          'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=200&auto=format&fit=crop&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.store.data.profile;
    _prefixCtrl = TextEditingController(text: p.invoicePrefix);
    _greetingCtrl = TextEditingController(text: p.greeting);
    _reviewUrlCtrl = TextEditingController(text: p.reviewUrl);
    _urlCtrl = TextEditingController(text: p.logo);
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _greetingCtrl.dispose();
    _reviewUrlCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateLogo(String newLogo) async {
    setState(() => _saving = true);
    try {
      await widget.store.change((candidate) {
        candidate.profile = candidate.profile.copyWith(logo: newLogo.trim());
      });
      _urlCtrl.text = newLogo.trim();
      if (mounted) {
        toast(
          context,
          newLogo.trim().isEmpty
              ? 'Profile logo removed. Header updated.'
              : 'Profile logo saved! Header DP updated instantly.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
      await _updateLogo(base64String);
    } catch (e) {
      if (mounted) toast(context, 'Could not load image: ${errorText(e)}');
    }
  }

  Future<void> _saveProfileDetails() async {
    setState(() => _saving = true);
    try {
      await widget.store.change((candidate) {
        candidate.profile = candidate.profile.copyWith(
          invoicePrefix: _prefixCtrl.text.trim().isEmpty
              ? 'HY'
              : _prefixCtrl.text.trim(),
          greeting: _greetingCtrl.text.trim(),
          reviewUrl: _reviewUrlCtrl.text.trim(),
        );
      });
      if (mounted) toast(context, 'Profile details saved successfully.');
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showUrlDialog() {
    final controller = TextEditingController(
      text: widget.store.data.profile.logo,
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Image URL'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a web image URL (https://...) or a base64 image string:',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/logo.png',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateLogo(controller.text);
            },
            child: const Text('Apply Logo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themePrimary = getActiveThemePrimary();
    final profile = widget.store.data.profile;
    final currentLogo = profile.logo;
    final hasLogo = currentLogo.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Brand & DP Card (Compact & Professional) ──
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _saving ? null : _pickImage,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        StoreLogoAvatar(
                          logo: currentLogo,
                          name: widget.store.data.businessName,
                          size: 60,
                          borderColor: themePrimary,
                          borderWidth: 2,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4.5),
                            decoration: BoxDecoration(
                              color: themePrimary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.store.data.businessName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (hasLogo)
                              Pill('LOGO ACTIVE', color: const Color(0xFF16A34A))
                            else
                              const Pill('MONOGRAM'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 30),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                              onPressed: _saving ? null : _pickImage,
                              icon: const Icon(Icons.upload_file, size: 14),
                              label: const Text('Upload'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 30),
                                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                              onPressed: _saving ? null : _showUrlDialog,
                              icon: const Icon(Icons.link, size: 14),
                              label: const Text('URL'),
                            ),
                            if (hasLogo)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: const Size(0, 30),
                                  textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                onPressed: _saving ? null : () => _updateLogo(''),
                                icon: const Icon(Icons.delete_outline, size: 14),
                                label: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Presets: ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final preset in _presetLogos)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _saving ? null : () => _updateLogo(preset.url),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: currentLogo == preset.url
                                        ? themePrimary.withValues(alpha: .12)
                                        : canvas,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: currentLogo == preset.url ? themePrimary : border,
                                      width: currentLogo == preset.url ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundImage: NetworkImage(preset.url),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        preset.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: currentLogo == preset.url
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: currentLogo == preset.url ? themePrimary : ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Receipt & Header Text Details (Compact) ──
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Receipt & Branding Details',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prefixCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  labelText: 'Invoice ID Prefix',
                  hintText: 'HY, CAFE, POS',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _greetingCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  labelText: 'Receipt Greeting Message',
                  hintText: 'Thank you for visiting us! Have a great day!',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reviewUrlCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  labelText: 'Feedback / Review Link',
                  hintText: 'https://g.page/r/your-shop-review',
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: _saving ? null : _saveProfileDetails,
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(
                    _saving ? 'Saving…' : 'Save Details',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 2. BUSINESS INFO TAB
// ═════════════════════════════════════════════════════════════════════════════

class _BusinessTab extends StatefulWidget {
  final CafeStore store;
  const _BusinessTab({required this.store});

  @override
  State<_BusinessTab> createState() => _BusinessTabState();
}

class _BusinessTabState extends State<_BusinessTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _taxCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.store.data;
    final p = d.profile;
    _nameCtrl = TextEditingController(text: d.businessName);
    _addressCtrl = TextEditingController(text: p.address);
    _phoneCtrl = TextEditingController(text: p.phone);
    _gstinCtrl = TextEditingController(text: p.gstin);
    _taxCtrl = TextEditingController(
      text: (p.taxBasisPoints / 100).toStringAsFixed(
        p.taxBasisPoints % 100 == 0 ? 0 : 2,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _gstinCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      toast(context, 'Business name cannot be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      final taxDouble = double.tryParse(_taxCtrl.text.trim()) ?? 0.0;
      final taxBps = (taxDouble * 100).round().clamp(0, 10000);

      await widget.store.change((candidate) {
        candidate.businessName = name;
        candidate.profile = candidate.profile.copyWith(
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          gstin: _gstinCtrl.text.trim(),
          taxBasisPoints: taxBps,
        );
      });
      if (mounted) toast(context, 'Business profile updated successfully.');
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Business & Tax Profile',
            subtitle:
                'Update your registered store title, contact numbers, outlet address, and GST rate.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Business / Café Name',
              hintText: 'Hynox Café',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact / WhatsApp Phone Number',
              hintText: '9876543210',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Store Outlet Address',
              hintText: 'No. 12, Main Road, Anna Nagar, Chennai - 600040',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gstinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN (Optional)',
                    hintText: '33AAAAA0000A1Z5',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _taxCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Default Tax Rate (%)',
                    hintText: '5.0',
                    suffixText: '%',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save Business Info'),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. SUBSCRIPTION & PLANS TAB
// ═════════════════════════════════════════════════════════════════════════════

class _SubscriptionTab extends StatefulWidget {
  final CafeStore store;
  const _SubscriptionTab({required this.store});

  @override
  State<_SubscriptionTab> createState() => _SubscriptionTabState();
}

class _PlanItem {
  final String id;
  final String name;
  final int price;
  final String priceLabel;
  final String tag;
  final List<String> features;

  const _PlanItem({
    required this.id,
    required this.name,
    required this.price,
    required this.priceLabel,
    required this.tag,
    required this.features,
  });
}

class _SubscriptionTabState extends State<_SubscriptionTab> {
  final _plans = const [
    _PlanItem(
      id: 'starter',
      name: 'Starter',
      price: 49900,
      priceLabel: '₹499',
      tag: 'Basic',
      features: [
        'Single Outlet POS',
        'Direct WhatsApp Billing',
        'Daily Sales Reports',
        'Up to 1,000 orders/month',
      ],
    ),
    _PlanItem(
      id: 'growth',
      name: 'Growth',
      price: 99900,
      priceLabel: '₹999',
      tag: 'Recommended',
      features: [
        'Unlimited Orders & Invoices',
        'Thermal & PDF Custom Templates',
        'Custom Store DP & Brand Logo',
        'Advanced Analytics & Excel Export',
        'Multi-theme Palette Support',
      ],
    ),
    _PlanItem(
      id: 'enterprise',
      name: 'Enterprise',
      price: 199900,
      priceLabel: '₹1,999',
      tag: 'Full Suite',
      features: [
        'Everything in Growth',
        'Multi-Device Staff POS Terminals',
        'Automated Cloud Backups',
        'Dedicated 24/7 WhatsApp VIP Support',
        'Custom Invoice Watermarks',
      ],
    ),
  ];

  Future<void> _requestPlan(String planId, String planName, int price) async {
    final sub = {
      'status': 'pending',
      'requestStatus': 'pending',
      'requestedPlanId': planId,
      'requestedPlanName': planName,
      'requestedPrice': price,
      'requestedAt': DateTime.now().toIso8601String(),
    };
    widget.store.updateSubscription(sub);
    toast(
      context,
      'Success! Request for $planName submitted. Awaiting Hynox team activation.',
    );
  }

  void _activateImmediately(String planId, String planName, int price) {
    final sub = {
      'status': 'active',
      'planId': planId,
      'planName': planName,
      'price': price,
      'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'activatedAt': DateTime.now().toIso8601String(),
      'activatedBy': 'Store Admin',
    };
    widget.store.updateSubscription(sub);
    toast(context, 'Success! $planName plan activated immediately.');
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.store.activeSubscription;
    final isActive = sub != null && sub['status'] == 'active';
    final isPending = sub != null && sub['requestStatus'] == 'pending';
    final trialDays = widget.store.data.trialDaysLeft(DateTime.now());
    final activePlanName = sub?['planName'] ?? 'Starter';
    final requestedPlanName = sub?['requestedPlanName'] ?? 'Growth';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status Banner ──────────────────────────────────────────────────
        if (isActive)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF16A34A),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Plan: $activePlanName Plan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14532D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All pro features, thermal receipts, and custom logo branding are unlocked.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Pill('ACTIVE', color: const Color(0xFF16A34A)),
              ],
            ),
          )
        else if (isPending)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFFB45309),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Requested: $requestedPlanName Plan (Pending Activation)',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF78350F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Awaiting confirmation from Hynox HQ dashboard.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                  onPressed: () => _activateImmediately(
                    sub['requestedPlanId'] ?? 'growth',
                    requestedPlanName,
                    sub['requestedPrice'] ?? 99900,
                  ),
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: const Text('Accept & Activate'),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFF1D4ED8),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '15-Day Free Trial ($trialDays Days Left)',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select a plan below to keep your café operations running smoothly.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
                Pill('$trialDays DAYS LEFT', color: const Color(0xFF1D4ED8)),
              ],
            ),
          ),
        const SizedBox(height: 24),
        // ── Available Plans Grid ───────────────────────────────────────────
        const _SectionTitle(
          title: 'Choose a Subscription Plan',
          subtitle:
              'Flexible plans tailored for single counter cafés and growing restaurant chains.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 800;
            return Flex(
              direction: wide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final plan in _plans)
                  Expanded(
                    flex: wide ? 1 : 0,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: wide && plan != _plans.last ? 14 : 0,
                        bottom: wide ? 0 : 14,
                      ),
                      child: _PlanCard(
                        plan: plan,
                        isCurrent: isActive && sub?['planId'] == plan.id,
                        isPending: isPending && sub?['requestedPlanId'] == plan.id,
                        onRequest: () => _requestPlan(plan.id, plan.name, plan.price),
                        onInstantActivate: () => _activateImmediately(
                          plan.id,
                          plan.name,
                          plan.price,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanItem plan;
  final bool isCurrent;
  final bool isPending;
  final VoidCallback onRequest;
  final VoidCallback onInstantActivate;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isPending,
    required this.onRequest,
    required this.onInstantActivate,
  });

  @override
  Widget build(BuildContext context) {
    final themePrimary = getActiveThemePrimary();
    final isHighlighted = plan.tag == 'Recommended';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF16A34A)
              : (isHighlighted ? themePrimary : border),
          width: isCurrent || isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          if (isHighlighted)
            BoxShadow(
              color: themePrimary.withValues(alpha: .08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              Pill(
                plan.tag,
                color: isHighlighted ? themePrimary : muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.priceLabel,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isHighlighted ? themePrimary : ink,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ month',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check,
                    color: Color(0xFF16A34A),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (isCurrent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Center(
                child: Text(
                  '✓ Current Active Plan',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else if (isPending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Center(
                child: Text(
                  '⌛ Request Submitted',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isHighlighted ? themePrimary : ink,
                ),
                onPressed: onRequest,
                child: const Text('Request Plan'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onInstantActivate,
                child: const Text(
                  'Instant Activate',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 4. TEAM & SECURITY TAB
// ═════════════════════════════════════════════════════════════════════════════

class _TeamTab extends StatelessWidget {
  final CafeStore store;
  const _TeamTab({required this.store});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Security & Access Control',
                subtitle:
                    'Manage your counter cashier access and administrative password.',
              ),
              const SizedBox(height: 20),
              _InfoRow(
                label: 'Current Operator Role',
                value: 'Store Administrator (Full Access)',
                icon: Icons.admin_panel_settings_outlined,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Connected Outlets',
                value: '1 Active Outlet (${store.data.businessName})',
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Data Persistence',
                value: 'Encrypted Local Device Storage (Offline Ready)',
                icon: Icons.storage_outlined,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (store.changePassword != null)
                    FilledButton.icon(
                      onPressed: () => changeAccountPassword(
                        context,
                        store.changePassword!,
                      ),
                      icon: const Icon(Icons.lock_reset, size: 18),
                      label: const Text('Change Account Password'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => toast(
                      context,
                      'All local receipts and data are up to date.',
                    ),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Check Sync Status'),
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

// ═════════════════════════════════════════════════════════════════════════════
// 5. COLOR THEME TAB
// ═════════════════════════════════════════════════════════════════════════════

class _ThemeTab extends StatelessWidget {
  const _ThemeTab();

  Future<void> _selectTheme(int index, BuildContext context) async {
    themeIndexNotifier.value = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kThemeKey, index);
    if (context.mounted) {
      toast(
        context,
        'Theme applied: ${themeOptions[index].name}. Header updated!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Color Palette & Atmosphere',
          subtitle:
              'Customize the POS workspace theme to match your café or store branding.',
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<int>(
          valueListenable: themeIndexNotifier,
          builder: (context, activeIdx, _) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 140,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: themeOptions.length,
              itemBuilder: (context, i) {
                final opt = themeOptions[i];
                final isSelected = activeIdx == i;

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _selectTheme(i, context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? opt.primary : border,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: opt.primary.withValues(alpha: .15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: opt.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: opt.dark,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: opt.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: opt.primary,
                                size: 20,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          opt.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? opt.primary : ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.description,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 6. PDF TEMPLATE TAB
// ═════════════════════════════════════════════════════════════════════════════

class _PdfTemplateTab extends StatelessWidget {
  const _PdfTemplateTab();

  Future<void> _selectTemplate(int index, BuildContext context) async {
    pdfTemplateNotifier.value = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kTemplateKey, index);
    if (context.mounted) {
      toast(context, 'PDF Receipt template set to ${pdfTemplates[index].name}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Print & PDF Invoice Template',
          subtitle:
              'Select your preferred bill layout. Changes apply to printed receipts and WhatsApp PDFs.',
        ),
        const SizedBox(height: 18),
        ValueListenableBuilder<int>(
          valueListenable: pdfTemplateNotifier,
          builder: (context, activeIdx, _) {
            final themePrimary = getActiveThemePrimary();
            return Column(
              children: [
                for (int i = 0; i < pdfTemplates.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _selectTemplate(i, context),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: activeIdx == i ? themePrimary : border,
                            width: activeIdx == i ? 2.5 : 1,
                          ),
                          boxShadow: [
                            if (activeIdx == i)
                              BoxShadow(
                                color: themePrimary.withValues(alpha: .1),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row with Radio, Title, and Badge
                            Row(
                              children: [
                                Radio<int>(
                                  value: i,
                                  groupValue: activeIdx,
                                  activeColor: themePrimary,
                                  onChanged: (_) => _selectTemplate(i, context),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        pdfTemplates[i].name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: activeIdx == i ? themePrimary : ink,
                                        ),
                                      ),
                                      Pill(
                                        pdfTemplates[i].tag,
                                        color: activeIdx == i ? themePrimary : muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 48),
                              child: Text(
                                pdfTemplates[i].description,
                                style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Distinct Visual Design Mockup Container
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _TemplateVisualMockup(templateIndex: i, themeColor: themePrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TemplateVisualMockup extends StatelessWidget {
  final int templateIndex;
  final Color themeColor;
  const _TemplateVisualMockup({required this.templateIndex, required this.themeColor});

  @override
  Widget build(BuildContext context) {
    if (templateIndex == 0) {
      // ══════════════════════════════════════════════════════════════════════
      // MOCKUP 0: THERMAL 80MM RECEIPT
      // ══════════════════════════════════════════════════════════════════════
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBF9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E2D8)),
        ),
        child: Column(
          children: [
            const Text(
              '✦ HYNOX CAFÉ & BAKERY ✦',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: ink),
            ),
            const SizedBox(height: 2),
            const Text(
              '80mm Thermal Slip · #HY-1042',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: muted),
            ),
            const SizedBox(height: 6),
            const Text(
              '- - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: muted),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1x Cold Brew Coffee', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                Text('₹180.00', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('2x Butter Croissant', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                Text('₹240.00', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '- - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: muted),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL (PAID VIA UPI)', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                Text('₹420.00', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 15, color: themeColor)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '*** Thank you for visiting! Have a nice day ***',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: muted),
            ),
          ],
        ),
      );
    } else if (templateIndex == 1) {
      // ══════════════════════════════════════════════════════════════════════
      // MOCKUP 1: EXECUTIVE MODERN (A5)
      // ══════════════════════════════════════════════════════════════════════
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            // Branded Top Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HYNOX CAFÉ · EXECUTIVE INVOICE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    'INV-1042',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Billed To: Walk-in Customer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('Table 4 · Dine-in', style: TextStyle(fontSize: 10, color: muted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Date: 14 Oct 2026', style: TextStyle(fontSize: 10, color: muted)),
                          Text('PAID (CARD)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: themeColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                      children: [
                        Expanded(child: Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: muted))),
                        Text('QTY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: muted)),
                        SizedBox(width: 24),
                        Text('AMOUNT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Expanded(child: Text('Hazelnut Latte', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                      Text('1', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 24),
                      Text('₹180.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Expanded(child: Text('Almond Croissant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                      Text('2', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 24),
                      Text('₹240.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code, size: 20, color: muted),
                          SizedBox(width: 6),
                          Text('Scan for feedback QR', style: TextStyle(fontSize: 9, color: muted)),
                        ],
                      ),
                      Text(
                        'Total: ₹420.00',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: themeColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // ══════════════════════════════════════════════════════════════════════
      // MOCKUP 2: ITEMIZED DETAILED / AUDITED GST
      // ══════════════════════════════════════════════════════════════════════
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FORMAL TAX INVOICE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8)),
                    Text('GSTIN: 33AAAAA0000A1Z5 · SAC: 996331', style: TextStyle(fontSize: 9, color: muted)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF86EFAC))),
                  child: const Text('AUDITED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: canvas, borderRadius: BorderRadius.circular(4)),
                  children: const [
                    Padding(padding: EdgeInsets.all(6), child: Text('PARTICULARS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(6), child: Text('QTY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(6), child: Text('GST %', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(6), child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                  ],
                ),
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.all(6), child: Text('Espresso Tonic', style: TextStyle(fontSize: 10))),
                    Padding(padding: EdgeInsets.all(6), child: Text('1', style: TextStyle(fontSize: 10))),
                    Padding(padding: EdgeInsets.all(6), child: Text('5.0%', style: TextStyle(fontSize: 10, color: muted))),
                    Padding(padding: EdgeInsets.all(6), child: Text('₹180.00', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  ],
                ),
                const TableRow(
                  children: [
                    Padding(padding: EdgeInsets.all(6), child: Text('Gourmet Bagel', style: TextStyle(fontSize: 10))),
                    Padding(padding: EdgeInsets.all(6), child: Text('2', style: TextStyle(fontSize: 10))),
                    Padding(padding: EdgeInsets.all(6), child: Text('5.0%', style: TextStyle(fontSize: 10, color: muted))),
                    Padding(padding: EdgeInsets.all(6), child: Text('₹240.00', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Taxable: ₹400.00 | CGST 2.5%: ₹10 | SGST 2.5%: ₹10', style: TextStyle(fontSize: 9, color: muted)),
                Text('Net: ₹420.00', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: themeColor)),
              ],
            ),
          ],
        ),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
