import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'pages.dart';
import 'pos.dart';
import 'reports.dart';
import 'portal.dart';
import 'local_portal.dart';
import 'settings_page.dart';
import 'account_password.dart';
import 'bill_message.dart';

const storageKey = 'Hynox.local.v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettingsPrefs();
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final data = raw == null
        ? CafeData.seed(DateTime.now())
        : CafeData.decode(raw);
    Future<void> persist(String value) async {
      if (!await prefs.setString(storageKey, value)) {
        throw StateError('Your browser or device could not save this change.');
      }
    }

    if (raw == null) {
      await persist(data.encode());
    }
    final api = await LocalPortalApi.open(prefs, data);
    runApp(
      HynoxApp(
        store: CafeStore(
          data,
          persist,
          openWhatsApp: (order) =>
              openWhatsAppMessage(order, data.businessName),
        ),
        connected: true,
        api: api,
      ),
    );
  } catch (_) {
    runApp(
      ValueListenableBuilder<int>(
        valueListenable: themeIndexNotifier,
        builder: (context, themeIndex, _) => MaterialApp(
          theme: appTheme(getActiveThemePrimary(themeIndex)),
          home: const Scaffold(
            body: SafeArea(
              child: EmptyState(
                'Local data could not be loaded',
                'Your saved data has not been overwritten. Reopen the app, check storage permissions, or ask your developer to inspect the local data.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HynoxApp extends StatelessWidget {
  final CafeStore store;
  final bool connected;
  final PortalApi? api;
  const HynoxApp({
    super.key,
    required this.store,
    this.connected = false,
    this.api,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: themeIndexNotifier,
    builder: (context, themeIndex, _) => MaterialApp(
      title: 'Hynox • Café workspace',
      debugShowCheckedModeBanner: false,
      theme: appTheme(getActiveThemePrimary(themeIndex)),
      home: connected
          ? PortalGate(
              api: api,
              legacy: store,
              vendorBuilder: (remote, logout) => Workspace(
                store: remote,
                initialRole: 'Vendor',
                onLogout: logout,
              ),
            )
          : Workspace(store: store),
    ),
  );
}

class Workspace extends StatefulWidget {
  final CafeStore store;
  final String? initialRole;
  final VoidCallback? onLogout;
  const Workspace({
    super.key,
    required this.store,
    this.initialRole,
    this.onLogout,
  });
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  late String? role = widget.initialRole;
  int page = 0;
  bool get admin => role == 'Hynox team';
  List<String> get labels => admin
      ? ['Overview', 'Vendors', 'Settings']
      : ['Overview', 'Orders', 'Menu', 'Customers', 'Reports', 'Settings'];
  List<IconData> get icons => admin
      ? [
          Icons.space_dashboard_outlined,
          Icons.storefront_outlined,
          Icons.settings_outlined,
        ]
      : [
          Icons.space_dashboard_outlined,
          Icons.receipt_long_outlined,
          Icons.restaurant_menu,
          Icons.people_outline,
          Icons.bar_chart_outlined,
          Icons.settings_outlined,
        ];

  @override
  void initState() {
    super.initState();
    _refreshSubscription();
  }

  void _refreshSubscription() {
    widget.store.loadSubscription?.call().then((catalog) {
      if (mounted) {
        widget.store.updateSubscription(catalog['subscription'] as Map<String, dynamic>?);
      }
    }).catchError((_) {});
  }

  void select(int value) {
    setState(() => page = value);
    _refreshSubscription();
  }
  Future<void> openPos([CafeOrder? order]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PosPage(store: widget.store, existing: order),
      ),
    );
  }



  Widget sidebar({bool drawer = false}) {
    final activeTheme = getActiveTheme();
    return Container(
      width: 232,
      color: activeTheme.dark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 30, 28, 4),
              child: Row(
                children: [
                  Icon(Icons.blur_on, color: activeTheme.accent, size: 31),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Hynox',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 8, 20, 36),
              child: Text(
                admin ? 'PLATFORM WORKSPACE' : 'A LITTLE LESS BUSY.',
                style: TextStyle(
                  color: activeTheme.accent.withValues(alpha: .7),
                  fontSize: 9,
                  letterSpacing: 1.7,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .06),
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    StoreLogoAvatar(
                      logo: widget.store.data.profile.logo,
                      name: admin ? 'HY' : widget.store.data.businessName,
                      size: 28,
                      borderColor: Colors.white24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin ? 'Hynox HQ' : widget.store.data.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Business workspace',
                            style: TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ...List.generate(
              labels.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                child: Material(
                  color: page == index ? activeTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      select(index);
                      if (drawer) {
                        Navigator.pop(context);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icons[index],
                            size: 20,
                            color: page == index ? activeTheme.dark : Colors.white60,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: page == index ? activeTheme.dark : Colors.white70,
                              fontWeight: page == index
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final sub = widget.store.activeSubscription;
                      final isActive = sub != null && sub['status'] == 'active';
                      final planName = sub?['planName'] ?? 'Active';
                      if (admin) {
                        return const Text(
                          'Built for growing businesses.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        );
                      }
                      if (isActive) {
                        return Row(
                          children: [
                            const Icon(Icons.verified, color: Color(0xFF4ADE80), size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$planName Plan · Active',
                                style: const TextStyle(
                                  color: Color(0xFF4ADE80),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }
                      return Text(
                        '${widget.store.data.trialDaysLeft(DateTime.now())} days left in your trial',
                        style: TextStyle(color: activeTheme.accent, fontSize: 11),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final sub = widget.store.activeSubscription;
                      final isActive = sub != null && sub['status'] == 'active';
                      return LinearProgressIndicator(
                        value: isActive ? 1.0 : (widget.store.data.trialDaysLeft(DateTime.now()) / 15).clamp(0.0, 1.0),
                        color: isActive ? const Color(0xFF4ADE80) : activeTheme.accent,
                        backgroundColor: Colors.white12,
                        minHeight: 3,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      if (drawer) {
                        Navigator.pop(context);
                      }
                      if (widget.onLogout != null) {
                        widget.onLogout!();
                        return;
                      }
                      setState(() {
                        role = null;
                        page = 0;
                      });
                    },
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(
                      widget.onLogout != null ? 'Sign out' : 'Switch workspace',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.store, themeIndexNotifier]),
    builder: (context, _) {
      if (role == null) {
        return WorkspaceEntry(
          onEnter: (value) => setState(() {
            role = value;
            page = 0;
          }),
        );
      }
      final screenWidth = MediaQuery.sizeOf(context).width;
      final wide = screenWidth >= 1024;
      final isMobile = screenWidth < 640;
      final isTablet = screenWidth >= 640 && screenWidth < 1024;
      final Widget content;
      if (admin) {
        content = AdminPage(data: widget.store.data, section: page, store: widget.store);
      } else {
        content = switch (page) {
          0 => OverviewPage(
            store: widget.store,
            onNew: () => openPos(),
            onOrders: () => select(1),
            onOrder: (o) => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => OrderDetailPage(
                  store: widget.store,
                  id: o.id,
                  onEdit: openPos,
                ),
              ),
            ),
          ),
          1 => OrdersPage(
            store: widget.store,
            onNew: () => openPos(),
            onEdit: openPos,
          ),
          2 => MenuPage(store: widget.store),
          3 => CustomersPage(data: widget.store.data),
          4 => ReportsPage(data: widget.store.data),
          _ => SettingsHub(store: widget.store),
        };
      }
      return Scaffold(
        drawer: wide ? null : Drawer(width: 232, child: sidebar(drawer: true)),
        body: Row(
          children: [
            if (wide) sidebar(),
            Expanded(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      height: 72,
                      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : (isMobile ? 12 : 18)),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: border)),
                      ),
                      child: Row(
                        children: [
                          if (!wide) ...[
                            Builder(
                              builder: (context) => IconButton(
                                tooltip: 'Open navigation',
                                onPressed: () => Scaffold.of(context).openDrawer(),
                                icon: const Icon(Icons.menu),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      admin ? Icons.shield_outlined : Icons.storefront_outlined,
                                      size: 13,
                                      color: muted,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        admin ? 'HYNOX PLATFORM' : widget.store.data.businessName.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.1,
                                          color: muted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  labels[page],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                    letterSpacing: -.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (!admin && wide) ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onPressed: () => openPos(),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('New Order', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (widget.store.changePassword != null)
                            IconButton(
                              tooltip: 'Change password',
                              icon: const Icon(Icons.lock_outline, size: 20),
                              onPressed: () => changeAccountPassword(
                                context,
                                widget.store.changePassword!,
                              ),
                            ),
                          const SizedBox(width: 4),
                          // Modern Interactive Store Profile Pill (Round DP)
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              if (!admin) {
                                select(5); // Direct jump to Settings & Profile
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: wide ? 10 : 4, vertical: 4),
                              decoration: BoxDecoration(
                                color: wide ? canvas : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                border: wide ? Border.all(color: border) : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StoreLogoAvatar(
                                    logo: widget.store.data.profile.logo,
                                    name: admin ? 'HY' : widget.store.data.businessName,
                                    size: wide ? 38 : (isMobile ? 32 : 36),
                                    borderColor: widget.store.data.profile.logo.isNotEmpty
                                        ? getActiveThemePrimary()
                                        : border,
                                  ),
                                  if (wide) ...[
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          admin ? 'Hynox HQ' : widget.store.data.businessName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: ink,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          admin
                                              ? 'Platform Admin'
                                              : (widget.store.activeSubscription?['status'] == 'active'
                                                  ? '${widget.store.activeSubscription?['planName']} Plan'
                                                  : 'Store Profile · 15-Day Trial'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: widget.store.activeSubscription?['status'] == 'active'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: widget.store.activeSubscription?['status'] == 'active'
                                                ? const Color(0xFF16A34A)
                                                : muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_right, size: 16, color: muted),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.store.busy)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : (isTablet ? 20 : 32),
                          vertical: isMobile ? 14 : 24,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: content,
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
      );
    },
  );
}

class WorkspaceEntry extends StatelessWidget {
  final ValueChanged<String> onEnter;
  const WorkspaceEntry({super.key, required this.onEnter});
  @override
  Widget build(BuildContext context) {
    final activeTheme = getActiveTheme();
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 850;
          final isSmall = constraints.maxWidth < 480;
          final intro = Container(
            color: activeTheme.dark,
            padding: EdgeInsets.all(wide ? 64 : (isSmall ? 20 : 28)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(Icons.blur_on, color: activeTheme.accent, size: 36),
                      const SizedBox(width: 12),
                      const Text(
                        'Hynox',
                        style: TextStyle(
                          fontSize: 38,
                          letterSpacing: -2,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 80 : (isSmall ? 20 : 30)),
                  Text(
                    'Big care.\nSmall business.',
                    style: TextStyle(
                      fontSize: isSmall ? 32 : 48,
                      height: 1.1,
                      letterSpacing: isSmall ? -1.2 : -2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'A calmer counter. Happier customers.\nYour café, all in one place.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.8,
                      color: Color(0xFFADC0B5),
                    ),
                  ),
                  const SizedBox(height: 38),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Pill('ORDERS', color: activeTheme.accent),
                      Pill('BILLING', color: activeTheme.accent),
                      Pill('INSIGHTS', color: activeTheme.accent),
                    ],
                  ),
                ],
              ),
            ),
          );
        final entry = Padding(
          padding: EdgeInsets.all(wide ? 64 : (isSmall ? 20 : 28)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Pill('HYNOX CAFÉ WORKSPACE'),
                  SizedBox(height: isSmall ? 16 : 24),
                  Text(
                    'Welcome to your\nnext chapter.',
                    style: TextStyle(
                      color: ink,
                      fontSize: isSmall ? 28 : 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose your workspace.',
                    style: TextStyle(color: muted, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  _entryCard(
                    'Café workspace',
                    'Take orders, record payments, and see your day.',
                    Icons.storefront_outlined,
                    () => onEnter('Vendor'),
                  ),
                  const SizedBox(height: 14),
                  _entryCard(
                    'Hynox team',
                    'Explore the platform administration view.',
                    Icons.grid_view_outlined,
                    () => onEnter('Hynox team'),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Offline local storage enabled. All transactions and workspace data are saved securely on this device.',
                    style: TextStyle(fontSize: 12, height: 1.7, color: muted),
                  ),
                ],
              ),
            ),
          ),
        );
        return wide
            ? Row(
                children: [
                  Expanded(
                    child: SizedBox(height: double.infinity, child: intro),
                  ),
                  Expanded(child: SingleChildScrollView(child: entry)),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(width: double.infinity, child: intro),
                    entry,
                  ],
                ),
              );
      },
    ),
  );
}

  Widget _entryCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: green, size: 27),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: muted,
                      height: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: green, size: 18),
          ],
        ),
      ),
    ),
  );
}
