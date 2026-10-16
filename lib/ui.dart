import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';

Uint8List? safeLogoBytes(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    var clean = raw.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return null;
    }
    if (clean.contains(',')) {
      clean = clean.split(',').last;
    }
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    final bytes = base64Decode(clean);
    return bytes.isNotEmpty ? bytes : null;
  } catch (_) {
    return null;
  }
}

class StoreLogoAvatar extends StatelessWidget {
  final String logo;
  final String name;
  final double size;
  final Color? borderColor;
  final double borderWidth;
  final Widget? badge;

  const StoreLogoAvatar({
    super.key,
    required this.logo,
    required this.name,
    this.size = 38,
    this.borderColor,
    this.borderWidth = 1.5,
    this.badge,
  });

  String _initials(String n) {
    final clean = n.trim();
    if (clean.isEmpty) return 'HY';
    final parts = clean.split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final themePrimary = getActiveThemePrimary();
    final cleanLogo = logo.trim();
    final isNetwork = cleanLogo.startsWith('http://') || cleanLogo.startsWith('https://');
    final bytes = !isNetwork ? safeLogoBytes(cleanLogo) : null;
    final hasImage = bytes != null || isNetwork;

    Widget imageContent;
    if (isNetwork) {
      imageContent = Image.network(
        cleanLogo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(themePrimary),
      );
    } else if (bytes != null) {
      imageContent = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(themePrimary),
      );
    } else {
      imageContent = _fallback(themePrimary);
    }

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: borderColor ?? (hasImage ? themePrimary : border),
          width: hasImage ? 2.0 : borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageContent,
    );

    if (badge == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: badge!,
        ),
      ],
    );
  }

  Widget _fallback(Color themePrimary) => CircleAvatar(
    radius: size / 2,
    backgroundColor: themePrimary.withValues(alpha: .15),
    child: Text(
      _initials(name),
      style: TextStyle(
        color: themePrimary,
        fontSize: size * 0.35,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

const ink = Color(0xFF172D2A);
const green = Color(0xFF26735D);
const canvas = Color(0xFFF5F6F2);
const muted = Color(0xFF71817A);
const lime = Color(0xFFDDF2B3);
const border = Color(0xFFE4E9E2);

const kThemeKey = 'Hynox.settings.themeIndex';
const kTemplateKey = 'Hynox.settings.pdfTemplate';
const _kTheme = kThemeKey;
const _kTemplate = kTemplateKey;

class ThemeOption {
  final String name;
  final Color primary;
  final Color dark;
  final Color accent;
  final String description;
  const ThemeOption(this.name, this.primary, this.dark, this.accent, this.description);
}

const themeOptions = [
  ThemeOption('Forest Green', Color(0xFF26735D), Color(0xFF172D2A), Color(0xFFDDF2B3), 'Nature & Eco'),
  ThemeOption('Royal Blue', Color(0xFF1D4ED8), Color(0xFF0F172A), Color(0xFFBFDBFE), 'Modern & Professional'),
  ThemeOption('Berry Purple', Color(0xFF7C3AED), Color(0xFF1E1030), Color(0xFFE9D5FF), 'Creative & Boutique'),
  ThemeOption('Sunset Orange', Color(0xFFEA580C), Color(0xFF2A1200), Color(0xFFFED7AA), 'Warm Café & Bakery'),
  ThemeOption('Crimson Red', Color(0xFFDC2626), Color(0xFF2A0009), Color(0xFFFECACA), 'Bold & Energetic'),
  ThemeOption('Slate Dark', Color(0xFF334155), Color(0xFF0F172A), Color(0xFFCBD5E1), 'Sleek & Minimalist'),
  ThemeOption('Midnight Teal', Color(0xFF0D9488), Color(0xFF042F2E), Color(0xFF99F6E4), 'Calming & Premium'),
  ThemeOption('Warm Espresso', Color(0xFF78350F), Color(0xFF261205), Color(0xFFFDE68A), 'Artisan Coffee Shop'),
];

final themeIndexNotifier = ValueNotifier<int>(0);
final pdfTemplateNotifier = ValueNotifier<int>(0);

ThemeOption getActiveTheme([int? index]) {
  final idx = (index ?? themeIndexNotifier.value).clamp(0, themeOptions.length - 1);
  return themeOptions[idx];
}

Color getActiveThemePrimary([int? index]) => getActiveTheme(index).primary;
Color getActiveThemeDark([int? index]) => getActiveTheme(index).dark;
Color getActiveThemeAccent([int? index]) => getActiveTheme(index).accent;

Future<void> loadSettingsPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  themeIndexNotifier.value = prefs.getInt(_kTheme) ?? 0;
  pdfTemplateNotifier.value = prefs.getInt(_kTemplate) ?? 0;
}

ThemeData appTheme([Color? primaryColor, Color? darkColor, Color? accentColor]) {
  final current = getActiveTheme();
  final p = primaryColor ?? current.primary;
  final a = accentColor ?? current.accent;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p,
      primary: p,
      secondary: a,
      surface: Colors.white,
    ),
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: ink, fontSize: 14),
      titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: ink, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p,
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
  );
}


class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const Pill(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? getActiveThemePrimary();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: LayoutBuilder(
      builder: (context, size) {
        final isSmall = size.maxWidth < 420;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isSmall ? 22 : 28,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: muted, height: 1.5)),
          ],
        );
        if (size.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: action!,
                ),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            if (action != null) ...[
              const SizedBox(width: 16),
              action!,
            ],
          ],
        );
      },
    ),
  );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final bool dark;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    this.dark = false,
  });
  @override
  Widget build(BuildContext context) {
    final activeTheme = getActiveTheme();
    return Panel(
      color: dark ? activeTheme.dark : Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: dark ? Colors.white70 : muted,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(icon, size: 19, color: dark ? activeTheme.accent : activeTheme.primary),
            ],
          ),
          const SizedBox(height: 22),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: dark ? Colors.white : ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: TextStyle(fontSize: 11, color: dark ? Colors.white60 : muted),
          ),
        ],
      ),
    );
  }
}


class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 900
          ? 4
          : size.maxWidth >= 480
          ? 2
          : 1;
      const gap = 14.0;
      final itemWidth = math.max(0.0, (size.maxWidth - (columns - 1) * gap) / columns - 0.2);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map(
              (e) => SizedBox(
                width: itemWidth,
                child: e,
              ),
            )
            .toList(),
      );
    },
  );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Widget? action;
  const EmptyState(
    this.title,
    this.body, {
    super.key,
    this.icon = Icons.receipt_long_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: green),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: muted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

IconData categoryIcon(String category) => switch (category) {
  'Coffee' => Icons.coffee_outlined,
  'Tea' => Icons.emoji_food_beverage_outlined,
  'Bites' => Icons.bakery_dining_outlined,
  _ => Icons.restaurant_outlined,
};
String stageLabel(OrderStage stage) => switch (stage) {
  OrderStage.preparing => 'Preparing',
  OrderStage.ready => 'Ready',
  OrderStage.completed => 'Completed',
  OrderStage.cancelled => 'Cancelled',
};
String paymentLabel(PaymentState state) => switch (state) {
  PaymentState.unpaid => 'Unpaid',
  PaymentState.paid => 'Paid',
  PaymentState.refunded => 'Refunded',
};
Color paymentColor(PaymentState state) => switch (state) {
  PaymentState.unpaid => const Color(0xFFAC731E),
  PaymentState.paid => green,
  PaymentState.refunded => const Color(0xFF9C5262),
};

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
String errorText(Object error) => error is StateError
    ? error.message.toString()
    : 'Could not save locally. Check device storage and try again.';

String receiptStatusMessage(String? status) => switch (status) {
  'accepted' =>
    'Payment received. Bill message accepted by WhatsApp for sending.',
  'connection_needed' =>
    'Payment received. Bill saved. WhatsApp Business connection is needed for automatic sending.',
  'delivery_unknown' =>
    'Payment received. WhatsApp submission could not be confirmed.',
  'failed' =>
    'Payment received. WhatsApp submission failed. Retry from Orders.',
  _ => 'Payment received. Check receipt delivery in Orders.',
};

Future<String?> paymentDialog(
  BuildContext context,
  int total, {
  String? customerName,
  String? customerPhone,
}) {
  final primaryColor = Theme.of(context).colorScheme.primary;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Icon(Icons.check_circle_outline, color: primaryColor, size: 24),
          const SizedBox(width: 10),
          const Text(
            'Payment Received',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryColor.withValues(alpha: .2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AMOUNT RECEIVED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(total),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    if (customerName != null && customerName.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble,
                            color: Color(0xFF25D366),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$customerName · +91 $customerPhone',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select payment method to complete order & send WhatsApp bill:',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _PaymentMethodBtn(
                      label: 'Cash',
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF0284C7),
                      onTap: () => Navigator.pop(context, 'Cash'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PaymentMethodBtn(
                      label: 'UPI',
                      icon: Icons.qr_code_2,
                      color: const Color(0xFF16A34A),
                      onTap: () => Navigator.pop(context, 'UPI'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PaymentMethodBtn(
                      label: 'Card',
                      icon: Icons.credit_card_outlined,
                      color: const Color(0xFF9333EA),
                      onTap: () => Navigator.pop(context, 'Card'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: muted)),
        ),
      ],
    ),
  );
}


class _PaymentMethodBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PaymentMethodBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
