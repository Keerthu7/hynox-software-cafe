import 'package:flutter/material.dart';

import 'store.dart';
import 'domain.dart';
import 'ui.dart';

class VendorSubscriptionPanel extends StatefulWidget {
  final CafeStore store;
  const VendorSubscriptionPanel({super.key, required this.store});
  @override
  State<VendorSubscriptionPanel> createState() =>
      _VendorSubscriptionPanelState();
}

class _VendorSubscriptionPanelState extends State<VendorSubscriptionPanel> {
  Map<String, dynamic>? catalog;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh([String? plan]) async {
    setState(() => busy = true);
    try {
      if (widget.store.loadSubscription != null) {
        final result = plan == null
            ? await widget.store.loadSubscription!()
            : await widget.store.requestPlan!(plan);
        if (mounted) {
          setState(() {
            catalog = result;
            error = null;
          });
          widget.store.updateSubscription(result['subscription'] as Map<String, dynamic>?);
        }
      } else {
        // Fallback default plans for standalone mode
        final fallbackSub = {
          'status': 'trial',
          'planName': '15-Day Free Trial',
          'expiresAt': widget.store.data.trialEndsAt.toIso8601String(),
          'requestedPlanId': plan,
          'requestStatus': plan != null ? 'pending' : null,
        };
        setState(() {
          catalog = {
            'subscription': fallbackSub,
            'plans': [
              {
                'id': 'starter',
                'name': 'Starter',
                'price': 99900,
                'features': ['Unlimited Invoices', 'WhatsApp Billing', '1 Cashier Account'],
              },
              {
                'id': 'growth',
                'name': 'Growth',
                'price': 199900,
                'features': ['Custom PDF Templates', 'Unlimited Staff Accounts', 'Export Reports', 'Multi-device'],
              },
              {
                'id': 'pro',
                'name': 'Pro Enterprise',
                'price': 349900,
                'features': ['All Growth Features', 'Priority Support', 'Custom Branding & Domain', 'Multi-outlet'],
              },
            ],
          };
          error = null;
        });
        widget.store.updateSubscription(fallbackSub);
      }
      if (plan != null && mounted) {
        toast(context, 'Subscription request submitted! Awaiting HYNOX team activation.');
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> payAndActivate(Map<String, dynamic> plan) async {
    final method = await paymentDialog(
      context,
      plan['price'] as int,
      customerName: widget.store.data.businessName,
      customerPhone: widget.store.data.profile.phone,
    );
    if (method == null || !mounted) return;

    setState(() => busy = true);
    try {
      if (widget.store.paySubscription != null) {
        final result = await widget.store.paySubscription!(plan['id'] as String, method);
        if (mounted) {
          setState(() {
            catalog = result;
            error = null;
          });
          widget.store.updateSubscription(result['subscription'] as Map<String, dynamic>?);
          toast(context, 'Payment confirmed via $method! ${plan['name']} plan is now active.');
        }
      } else {
        // Standalone activation fallback
        final newSub = {
          'status': 'active',
          'planId': plan['id'],
          'planName': plan['name'],
          'price': plan['price'],
          'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'paidAt': DateTime.now().toIso8601String(),
          'paymentMethod': method,
        };
        setState(() {
          catalog = {
            'subscription': newSub,
            'plans': catalog?['plans'] ?? [],
          };
          error = null;
        });
        widget.store.updateSubscription(newSub);
        toast(context, 'Payment confirmed via $method! ${plan['name']} plan is now active.');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = getActiveThemePrimary();
    final subscription = catalog?['subscription'];
    final isPending = subscription?['requestStatus'] == 'pending';
    final requestedPlanId = subscription?['requestedPlanId'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: PageHeading(
                'Store Subscription',
                'Manage your active subscription plan and unlock premium features.',
              ),
            ),
            IconButton(
              tooltip: 'Refresh plans',
              onPressed: busy ? null : () => refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        if (subscription != null) ...[
          const SizedBox(height: 18),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      subscription['status'] == 'active'
                          ? Icons.verified
                          : Icons.access_time_filled,
                      color: subscription['status'] == 'active'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        subscription['status'] == 'active'
                            ? '${subscription['planName'] ?? 'Active Plan'} (Subscribed)'
                            : (subscription['status'] == 'trial'
                                ? '15-Day Free Trial'
                                : 'Subscription Inactive'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Pill(
                      subscription['status'] == 'active' ? 'Active' : 'Trial',
                      color: subscription['status'] == 'active'
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (subscription['expiresAt'] != null)
                  Text(
                    'Plan active until ${shortDate(DateTime.parse(subscription['expiresAt']))}',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                if (isPending) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top, color: Color(0xFFB45309), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Plan upgrade to "${subscription['requestedPlanName'] ?? requestedPlanId}" is pending approval from the HYNOX team. It will activate once accepted, or you can pay directly below.',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Choose a Subscription Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        for (final p in catalog?['plans'] ?? []) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p['name'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${money(p['price'])} / month',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: activeTheme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final feature in p['features'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: activeTheme),
                          const SizedBox(width: 8),
                          Text(feature, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : () => payAndActivate(p),
                        icon: const Icon(Icons.flash_on, size: 18),
                        label: const Text('Pay & Activate Now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy || requestedPlanId == p['id']
                            ? null
                            : () => refresh(p['id']),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: Text(
                          requestedPlanId == p['id']
                              ? 'Request Sent (Pending Approval)'
                              : 'Request Plan from Team',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (catalog != null && (catalog!['plans'] as List).isEmpty)
          const Text('No subscription plans are available yet.'),
      ],
    );
  }
}
