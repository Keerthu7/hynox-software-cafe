import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui.dart';
import 'domain.dart';
import 'billing_extras.dart';
import 'account_password.dart';

typedef TeamRequest =
    Future<Map<String, dynamic>> Function(
      String path, [
      Map<String, dynamic>? body,
    ]);

class TeamWorkspace extends StatefulWidget {
  final Map<String, dynamic> initial;
  final TeamRequest request;
  final VoidCallback logout;
  const TeamWorkspace({
    super.key,
    required this.initial,
    required this.request,
    required this.logout,
  });
  @override
  State<TeamWorkspace> createState() => _TeamWorkspaceState();
}

class _TeamWorkspaceState extends State<TeamWorkspace> {
  late Map<String, dynamic> data = widget.initial;
  int page = 0;
  int settingsPage = 0;
  bool loading = false;
  String search = '';
  final labels = const ['Overview', 'Vendors', 'Subscriptions', 'Settings'];
  final icons = const [
    Icons.dashboard_outlined,
    Icons.storefront_outlined,
    Icons.credit_card_outlined,
    Icons.settings_outlined,
  ];
  List<dynamic> get vendors => data['vendors'];
  List<dynamic> get plans => data['plans'];
  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final result = await widget.request('/api/admin');
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit(String kind, [Map<String, dynamic>? initial]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TeamEditor(
        kind: kind,
        initial: initial ?? {},
        plans: plans,
        request: widget.request,
        saved: (result) {
          if (mounted) setState(() => data = result);
        },
      ),
    );
  }

  Widget navigation(bool drawer) {
    final activeTheme = getActiveTheme();
    return SizedBox(
      width: 232,
      child: Material(
        color: activeTheme.dark,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  children: [
                    Icon(Icons.blur_on, color: activeTheme.accent),
                    const SizedBox(width: 10),
                    const Text(
                      'Hynox',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'TEAM WORKSPACE',
                  style: TextStyle(color: activeTheme.accent, fontSize: 11),
                ),
              ),
              for (final entry in labels.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  child: ListTile(
                    leading: Icon(
                      icons[entry.$1],
                      color: page == entry.$1 ? activeTheme.accent : Colors.white70,
                    ),
                    title: Text(
                      entry.$2,
                      style: TextStyle(
                        color: page == entry.$1 ? activeTheme.accent : Colors.white70,
                        fontWeight: page == entry.$1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: page == entry.$1,
                    selectedTileColor: Colors.white10,
                    onTap: () {
                      setState(() => page = entry.$1);
                      if (drawer) Navigator.pop(context);
                    },
                  ),
                ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: widget.logout,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  String status(dynamic v) => switch (v['subscription']['status']) {
    'active' => 'Subscribed',
    'trial' => 'Trial',
    'expired' => 'Expired',
    'cancelled' => 'Cancelled',
    _ => 'Not subscribed',
  };
  Future<void> acceptPlan(dynamic v, [String? explicitPlanId]) async {
    final sub = v['subscription'] as Map<String, dynamic>;
    final planId = explicitPlanId ?? sub['requestedPlanId'] ?? (plans.isNotEmpty ? plans.first['id'] : null);
    if (planId == null) {
      toast(context, 'No subscription plans available.');
      return;
    }
    final planMatches = plans.where((p) => p['id'] == planId);
    final planName = planMatches.isNotEmpty ? planMatches.first['name'] : 'Subscription';
    setState(() => loading = true);
    try {
      final result = await widget.request('/api/admin/subscription/accept', {
        'shop': v['slug'],
        'planId': planId,
      });
      if (mounted) {
        setState(() => data = result);
        toast(context, 'Success! $planName plan activated for ${v['name']}.');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> chooseAndActivatePlan(dynamic v) async {
    final sub = v['subscription'] as Map<String, dynamic>;
    if (sub['requestStatus'] == 'pending' && sub['requestedPlanId'] != null) {
      await acceptPlan(v, sub['requestedPlanId']);
      return;
    }
    if (plans.isEmpty) {
      toast(context, 'No subscription plans available. Please create a plan first.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Activate Plan · ${v['name']}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a subscription plan to immediately activate for this vendor:',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (final p in plans)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: border),
                    ),
                    leading: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
                    title: Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${money(p['price'])} / month'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.pop(ctx, p['id'] as String),
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
        ],
      ),
    );
    if (selected != null && mounted) {
      await acceptPlan(v, selected);
    }
  }

  Widget vendorCard(dynamic v, {bool subscription = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                v['name'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Pill(status(v)),
              if (v['subscription']['requestStatus'] == 'pending')
                const Pill('Plan requested', color: Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${v['owner']}\nLogin: ${v['loginPhone']}\n${v['address']}',
            style: const TextStyle(color: muted, height: 1.6),
          ),
          if (v['subscription']['planName'] != null)
            Text('Plan: ${v['subscription']['planName']}'),
          if (v['subscription']['expiresAt'] != null)
            Text(
              'Expires ${shortDate(DateTime.parse(v['subscription']['expiresAt']))}',
            ),
          if (v['subscription']['requestedPlanId'] != null)
            Text(
              'Requested: ${plans.where((p) => p['id'] == v['subscription']['requestedPlanId']).map((p) => p['name']).join()}',
            ),
          if (v['subscription']['requestStatus'] == 'pending') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: Color(0xFFB45309), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Requested: ${v['subscription']['requestedPlanName'] ?? (plans.where((p) => p['id'] == v['subscription']['requestedPlanId']).map((p) => p['name']).join())} · Awaiting Activation',
                      style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          // Action Buttons with generous spacing and prominent Accept & Activate button
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: loading ? null : () => chooseAndActivatePlan(v),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  v['subscription']['requestStatus'] == 'pending'
                      ? 'Accept & Activate Plan'
                      : (v['subscription']['status'] == 'active' ? 'Change Plan' : 'Activate Plan'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => edit('subscription', {
                  'shop': v['slug'],
                  ...Map<String, dynamic>.from(v['subscription']),
                }),
                icon: const Icon(Icons.credit_card_outlined, size: 18),
                label: const Text('Manage subscription'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => edit(
                  'vendor',
                  Map<String, dynamic>.from(v)..['phone'] = v['loginPhone'],
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit vendor'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget content() {
    final counts = data['counts'];
    if (page == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            'Hynox dashboard',
            'Your vendors and subscriptions in one place.',
          ),
          StatGrid(
            children: [
              StatCard(
                label: 'TOTAL VENDORS',
                value: '${data['totalVendors']}',
                note: 'Registered shops',
                icon: Icons.storefront_outlined,
                dark: true,
              ),
              StatCard(
                label: 'SUBSCRIBED',
                value: '${counts['active']}',
                note: 'Active subscriptions',
                icon: Icons.verified_outlined,
              ),
              StatCard(
                label: 'ON TRIAL',
                value: '${counts['trial']}',
                note: 'Trial subscriptions',
                icon: Icons.timer_outlined,
              ),
              StatCard(
                label: 'EXPIRED',
                value: '${counts['expired']}',
                note: 'Subscription renewal needed',
                icon: Icons.event_busy_outlined,
              ),
            ],
          ),
          if ((counts['pending'] as int? ?? 0) > 0) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Color(0xFFB45309), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '${counts['pending']} Vendor Plan Request(s) Awaiting Activation',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final pv in vendors.where((v) => v['subscription']['requestStatus'] == 'pending'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pv['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Requested: ${pv['subscription']['requestedPlanName'] ?? (plans.where((p) => p['id'] == pv['subscription']['requestedPlanId']).map((p) => p['name']).join())}',
                                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                              onPressed: loading ? null : () => acceptPlan(pv),
                              icon: const Icon(Icons.check_circle, size: 16),
                              label: const Text('Accept & Activate Plan'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => edit('vendor'),
                icon: const Icon(Icons.add),
                label: const Text('Create vendor'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => page = 2),
                child: Text('Plan requests · ${counts['pending']}'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final v in vendors.take(5)) vendorCard(v),
        ],
      );
    }
    if (page == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading('Vendors', 'Create a shop and its login account.'),
          FilledButton.icon(
            onPressed: () => edit('vendor'),
            icon: const Icon(Icons.add),
            label: const Text('Create vendor'),
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (v) => setState(() => search = v),
            decoration: const InputDecoration(
              labelText: 'Search vendors',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 20),
          for (final v in vendors.where(
            (v) => '${v['name']} ${v['owner']} ${v['loginPhone']}'
                .toLowerCase()
                .contains(search.toLowerCase()),
          ))
            vendorCard(v),
        ],
      );
    }
    if (page == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            'Subscriptions',
            'Edit plans shown to vendors and manage their subscription status.',
          ),
          FilledButton.icon(
            onPressed: () => edit('plan'),
            icon: const Icon(Icons.add),
            label: const Text('Create plan'),
          ),
          const SizedBox(height: 20),
          for (final p in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          p['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Pill(p['active'] ? 'Published' : 'Hidden'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${money(p['price'])} / month',
                      style: TextStyle(
                        fontSize: 22,
                        color: getActiveThemePrimary(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final f in p['features']) Text('• $f'),
                    TextButton.icon(
                      onPressed: () =>
                          edit('plan', Map<String, dynamic>.from(p)),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit plan'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Vendor subscriptions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final v in vendors) vendorCard(v, subscription: true),
        ],
      );
    }
    final profile = data['profile'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading('Team settings', 'Profile and account security.'),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Profile'),
              icon: Icon(Icons.person_outline),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Security'),
              icon: Icon(Icons.lock_outline),
            ),
          ],
          selected: {settingsPage},
          onSelectionChanged: (v) => setState(() => settingsPage = v.first),
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: settingsPage == 0
                ? [
                    Row(
                      children: [
                        StoreLogoAvatar(
                          logo: '',
                          name: profile['name'] ?? 'HY',
                          size: 72,
                          borderColor: getActiveThemePrimary(),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['name'] ?? 'Hynox Administrator',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Pill('SUPER ADMIN', color: getActiveThemePrimary()),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 14),
                    Text('Login phone: ${profile['loginPhone']}', style: const TextStyle(height: 1.6)),
                    Text('Contact phone: ${profile['contactPhone']}', style: const TextStyle(height: 1.6)),
                    Text('Email: ${profile['email']}', style: const TextStyle(height: 1.6)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          edit('profile', Map<String, dynamic>.from(profile)),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Update profile'),
                    ),
                  ]
                : [
                    const Text(
                      'Account password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => changeAccountPassword(context, (
                        current,
                        password,
                      ) async {
                        await widget.request('/api/password', {
                          'current': current,
                          'new': password,
                        });
                      }),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Change password'),
                    ),
                  ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: themeIndexNotifier,
    builder: (context, _, __) => LayoutBuilder(
      builder: (context, size) {
        final wide = size.maxWidth >= 900;
        return Scaffold(
          drawer: wide ? null : Drawer(child: navigation(true)),
          body: Row(
            children: [
              if (wide) navigation(false),
              Expanded(
                child: Column(
                  children: [
                    AppBar(
                      automaticallyImplyLeading: !wide,
                      title: Text('Hynox · ${labels[page]}'),
                      actions: [
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: loading ? null : refresh,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (loading) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(wide ? 32 : 20),
                        child: content(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class TeamEditor extends StatefulWidget {
  final String kind;
  final Map<String, dynamic> initial;
  final List<dynamic> plans;
  final TeamRequest request;
  final ValueChanged<Map<String, dynamic>> saved;
  const TeamEditor({
    super.key,
    required this.kind,
    required this.initial,
    required this.plans,
    required this.request,
    required this.saved,
  });
  @override
  State<TeamEditor> createState() => _TeamEditorState();
}

class _TeamEditorState extends State<TeamEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool saving = false;
  late bool published = widget.initial['active'] ?? true;
  late String status = widget.initial['status'] == 'expired'
      ? 'active'
      : widget.initial['status'] ?? 'active';
  late String plan =
      widget.initial['requestedPlanId'] ?? widget.initial['planId'] ?? '';
  String? error;
  bool get editing => widget.initial['slug'] != null;
  @override
  void initState() {
    super.initState();
    for (final k in [
      'name',
      'owner',
      'address',
      'phone',
      'email',
      'password',
      'confirm',
      'price',
      'features',
      'contactPhone',
      'expiresAt',
    ]) {
      var value = widget.initial[k];
      if (k == 'price') value = ((value ?? 0) / 100).toStringAsFixed(2);
      if (k == 'features') value = (value as List? ?? []).join('\n');
      if (k == 'expiresAt') {
        value =
            (value ??
                    DateTime.now()
                        .add(const Duration(days: 30))
                        .toIso8601String())
                .toString()
                .split('T')
                .first;
      }
      fields[k] = TextEditingController(text: '${value ?? ''}');
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String key,
    String label, {
    bool optional = false,
    bool secret = false,
    int lines = 1,
    int maximum = 120,
    bool phone = false,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !saving && enabled,
      obscureText: secret,
      maxLines: lines,
      maxLength: maximum,
      keyboardType: phone
          ? TextInputType.phone
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      inputFormatters: phone
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : null,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (v) {
        if (!optional && (v ?? '').trim().isEmpty) return 'Enter $label';
        if (phone && v!.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(v)) {
          return 'Enter a 10-digit number';
        }
        if (key == 'confirm' && v != fields['password']!.text) {
          return 'Passwords do not match';
        }
        if (key == 'password' && v!.length < 4) {
          return 'Use at least 4 characters';
        }
        if (key == 'price' && parseRupees(v ?? '') == null) {
          return 'Enter a valid price';
        }
        return null;
      },
    ),
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{...widget.initial};
      final keys = switch (widget.kind) {
        'vendor' => [
          'name',
          'owner',
          'address',
          'phone',
          'email',
          if (!editing) 'password',
        ],
        'plan' => ['name'],
        'profile' => ['name', 'email', 'contactPhone'],
        _ => ['expiresAt'],
      };
      for (final k in keys) {
        body[k] = k == 'password' ? fields[k]!.text : fields[k]!.text.trim();
      }
      if (widget.kind == 'plan') {
        body['price'] = parseRupees(fields['price']!.text);
        body['features'] = fields['features']!.text
            .split('\n')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
        body['active'] = published;
      }
      if (widget.kind == 'subscription') {
        body['status'] = status;
        body['planId'] = plan;
      }
      final result = await widget.request('/api/admin/${widget.kind}', body);
      widget.saved(result);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(switch (widget.kind) {
        'vendor' => editing ? 'Edit vendor' : 'Create vendor',
        'plan' => 'Subscription plan',
        'profile' => 'Update profile',
        _ => 'Manage subscription',
      }),
      content: SizedBox(
        width: 480,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.kind == 'vendor') ...[
                  field('name', 'Shop name', maximum: 60),
                  field('owner', 'Owner name', maximum: 80),
                  field('address', 'Address', lines: 3, maximum: 300),
                  field(
                    'phone',
                    'Login mobile number',
                    phone: true,
                    enabled: !editing,
                  ),
                  field('email', 'Email', optional: true),
                  if (!editing) ...[
                    field('password', 'Password', secret: true, maximum: 128),
                    field(
                      'confirm',
                      'Confirm password',
                      secret: true,
                      maximum: 128,
                    ),
                  ],
                ],
                if (widget.kind == 'plan') ...[
                  field('name', 'Plan name', maximum: 60),
                  field('price', 'Monthly price (INR)', maximum: 12),
                  field(
                    'features',
                    'Features (one per line)',
                    optional: true,
                    lines: 5,
                    maximum: 2400,
                  ),
                  SwitchListTile(
                    title: const Text('Show this plan to vendors'),
                    value: published,
                    onChanged: saving
                        ? null
                        : (v) => setState(() => published = v),
                  ),
                ],
                if (widget.kind == 'profile') ...[
                  field('name', 'Name', maximum: 80),
                  field('email', 'Email', optional: true),
                  field(
                    'contactPhone',
                    'Contact phone',
                    phone: true,
                    optional: true,
                  ),
                ],
                if (widget.kind == 'subscription') ...[
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const ['active', 'trial', 'none', 'cancelled']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setState(() => status = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: widget.plans.any((p) => p['id'] == plan)
                        ? plan
                        : '',
                    decoration: const InputDecoration(labelText: 'Plan'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('No plan')),
                      for (final p in widget.plans)
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(p['name']),
                        ),
                    ],
                    onChanged: saving ? null : (v) => setState(() => plan = v!),
                  ),
                  const SizedBox(height: 16),
                  if (status == 'active' || status == 'trial')
                    field('expiresAt', 'Expiry date (YYYY-MM-DD)', maximum: 10),
                  const Text(
                    'Activation records the status you confirm. It does not charge the vendor.',
                    style: TextStyle(color: muted, height: 1.5),
                  ),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(
            saving
                ? 'Saving…'
                : widget.kind == 'vendor' && !editing
                ? 'Create vendor'
                : 'Save',
          ),
        ),
      ],
    ),
  );
}
