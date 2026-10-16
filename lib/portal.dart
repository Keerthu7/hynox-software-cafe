import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'domain.dart';
import 'store.dart';
import 'receipt.dart';
import 'ui.dart';
import 'team_workspace.dart';
import 'bill_message.dart';

class PortalApi {
  final http.Client client;
  String token = '';
  int revision = 0;
  Set<String> paidIds = {};
  PortalApi({http.Client? client}) : client = client ?? http.Client();
  Uri url(String path) {
    const configured = String.fromEnvironment('Hynox_API_URL');
    return (configured.isNotEmpty
            ? Uri.parse(configured)
            : kIsWeb
            ? Uri.base
            : Uri.parse('http://127.0.0.1:8766/'))
        .resolve(path);
  }

  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final headers = {
      'Content-Type': 'application/json',
      'X-Hynox-Client': '1',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final response =
        await (body == null
                ? client.get(url(path), headers: headers)
                : client.post(
                    url(path),
                    headers: headers,
                    body: jsonEncode(body),
                  ))
            .timeout(const Duration(seconds: 20));
    if (!(response.headers['content-type'] ?? '').contains(
      'application/json',
    )) {
      throw StateError(
        'Start Hynox using START-HYNOS.cmd to enable the sign-in server.',
      );
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw StateError(result['error'] ?? 'Request failed.');
    }
    return result;
  }

  Future<CafeData> load() async {
    final result = await request('/api/state');
    revision = result['revision'];
    final data = CafeData.decode(jsonEncode(result['state']));
    paidIds = data.orders
        .where((o) => o.payment != PaymentState.unpaid)
        .map((o) => o.id)
        .toSet();
    return data;
  }

  Future<Map<String, String>> statuses() async {
    final result = await request('/api/receipts');
    return {
      for (final r in result['receipts'] as List)
        r['order_id'] as String: r['status'] as String,
    };
  }

  Future<void> syncReceipts(CafeData data, Set<String> newPaidIds) async {
    final existing = await statuses();
    for (final order in data.orders.where(
      (o) =>
          o.payment == PaymentState.paid &&
          newPaidIds.contains(o.id) &&
          !existing.containsKey(o.id),
    )) {
      await request('/api/receipt', {
        'orderId': order.id,
        'pdf': base64Encode(await buildReceipt(order, data.businessName)),
      });
    }
  }

  Future<void> save(String raw) async {
    final result = await request('/api/state', {
      'state': jsonDecode(raw),
      'revision': revision,
    });
    revision = result['revision'];
    final data = CafeData.decode(raw);
    final newPaidIds = data.orders
        .where((o) => o.payment == PaymentState.paid && !paidIds.contains(o.id))
        .map((o) => o.id)
        .toSet();
    paidIds = data.orders
        .where((o) => o.payment != PaymentState.unpaid)
        .map((o) => o.id)
        .toSet();
    // The bill is already committed. PDF failure must not roll back that payment.
    try {
      await syncReceipts(data, newPaidIds);
    } catch (_) {
      /* Missing PDFs can be retried from the bill details. */
    }
  }
}

class PortalGate extends StatefulWidget {
  final PortalApi? api;
  final CafeStore legacy;
  final Widget Function(CafeStore store, VoidCallback logout) vendorBuilder;
  const PortalGate({
    super.key,
    this.api,
    required this.legacy,
    required this.vendorBuilder,
  });
  @override
  State<PortalGate> createState() => _PortalGateState();
}

class _PortalGateState extends State<PortalGate> {
  late final api = widget.api ?? PortalApi();
  final phone = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  String? role;
  String? shop;
  CafeStore? store;
  Map<String, dynamic>? teamData;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    api.client.close();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = await api.request('/api/login', {
        'phone': phone.text.trim(),
        'password': password.text,
      });
      api.token = auth['token'];
      role = auth['role'];
      shop = auth['shop'];
      if (role == 'team') {
        teamData = await api.request('/api/admin');
        store = null;
      } else {
        teamData = null;
        final data = await api.load();
        Map<String, dynamic>? initialSub;
        try {
          final cat = await api.request('/api/catalog');
          initialSub = cat['subscription'] as Map<String, dynamic>?;
        } catch (_) {}
        store = CafeStore(
          data,
          api.save,
          connected: false,
          activeSubscription: initialSub,
          loadSubscription: () async {
            final res = await api.request('/api/catalog');
            store?.updateSubscription(res['subscription'] as Map<String, dynamic>?);
            return res;
          },
          requestPlan: (id) async {
            final res = await api.request('/api/subscription/request', {'planId': id});
            store?.updateSubscription(res['subscription'] as Map<String, dynamic>?);
            return res;
          },
          paySubscription: (id, method) async {
            final res = await api.request('/api/subscription/pay', {'planId': id, 'method': method});
            store?.updateSubscription(res['subscription'] as Map<String, dynamic>?);
            return res;
          },
          receiptStatuses: api.statuses,
          retryReceipt: (orderId) async {
            final order = store!.data.order(orderId);
            await api.request('/api/receipt', {
              'orderId': orderId,
              'pdf': base64Encode(
                await buildReceipt(order, store!.data.businessName),
              ),
            });
          },
          changePassword: (current, password) async {
            await api.request('/api/password', {
              'current': current,
              'new': password,
            });
          },
          openWhatsApp: (order) =>
              openWhatsAppMessage(order, store!.data.businessName),
        );
      }
      password.clear();
    } catch (e) {
      api.token = '';
      error = e is StateError ? e.message.toString() : 'Could not open your workspace. Please try again.';
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  Future<void> logout() async {
    try {
      await api.request('/api/logout', {});
    } catch (_) {}
    api.token = '';
    if (mounted) {
      setState(() {
        store = null;
        teamData = null;
      });
    }
  }

  Future<void> importLegacy() async {
    setState(() => busy = true);
    try {
      await store!.change((data) {
        data.businessName = widget.legacy.data.businessName;
        data.profile = widget.legacy.data.profile;
        data.menu
          ..clear()
          ..addAll(widget.legacy.data.menu);
        data.orders
          ..clear()
          ..addAll(widget.legacy.data.orders);
        data.nextOrderNumber = widget.legacy.data.nextOrderNumber;
      });
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (store != null) {
      return widget.vendorBuilder(store!, () => logout());
    }
    if (teamData != null) {
      return TeamWorkspace(
        initial: teamData!,
        request: api.request,
        logout: () => logout(),
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Panel(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.blur_on, color: getActiveThemePrimary(), size: 32),
                        const SizedBox(width: 10),
                        const Text(
                          'Hynox',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in to your Hynox account.',
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                      ),
                      validator: (v) =>
                          !RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                          ? 'Enter a 10-digit mobile number'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Enter your password' : null,
                      onFieldSubmitted: (_) {
                        if (!busy) {
                          login();
                        }
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red, height: 1.5),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : login,
                        child: Text(busy ? 'Signing in…' : 'Log in →'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'Quick sign-in',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: busy ? null : () {
                              phone.text = '9345966973';
                              password.text = '1234';
                              login();
                            },
                            icon: const Icon(Icons.storefront_outlined, size: 16),
                            label: const Text('Vendor', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: busy ? null : () {
                              phone.text = '9865563844';
                              password.text = '123456';
                              login();
                            },
                            icon: const Icon(Icons.shield_outlined, size: 16),
                            label: const Text('Hynox Team', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReceiptDeliveryPanel extends StatefulWidget {
  final CafeStore store;
  final String orderId;
  const ReceiptDeliveryPanel({
    super.key,
    required this.store,
    required this.orderId,
  });
  @override
  State<ReceiptDeliveryPanel> createState() => _ReceiptDeliveryPanelState();
}

class _ReceiptDeliveryPanelState extends State<ReceiptDeliveryPanel> {
  String label = 'Preparing PDF…';
  bool _hasPhone = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _hasPhone = widget.store.data.order(widget.orderId).phone.isNotEmpty;
    refresh();
  }

  Future<void> refresh() async {
    try {
      final states = await widget.store.receiptStatuses!();
      if (mounted) {
        setState(
          () => label = switch (states[widget.orderId]) {
            'connection_needed' => 'Open WhatsApp to send your text bill, greeting and review request. Automatic sending needs WhatsApp Business.',
            'accepted' => 'Bill message accepted by WhatsApp for sending.',
            'sending' => 'Bill message is being submitted to WhatsApp.',
            'delivery_unknown' => 'WhatsApp submission could not be confirmed. Check the Business account before retrying.',
            'failed' =>
              'WhatsApp submission failed. Check the connection and retry.',
            'phone_needed' =>
              'PDF saved. No customer mobile number was entered on this order.',
            _ => 'PDF is not ready. Refresh to retry generation.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => label = 'Could not check receipt status. Refresh to retry.',
        );
      }
    }
  }

  Future<void> retry() async {
    setState(() => _sending = true);
    try {
      await widget.store.retryReceipt!(widget.orderId);
      await refresh();
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    color: const Color(0xFFEAF0DE),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: green, size: 18),
            SizedBox(width: 8),
            Text(
              'Customer WhatsApp message',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: green, height: 1.6)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_hasPhone && widget.store.openWhatsApp != null)
              FilledButton.icon(
                onPressed: _sending
                    ? null
                    : () async {
                        try {
                          final opened = await widget.store.openWhatsApp!(
                            widget.store.data.order(widget.orderId),
                          );
                          if (context.mounted && !opened) {
                            toast(context, 'WhatsApp could not be opened.');
                          }
                        } catch (e) {
                          if (context.mounted) toast(context, errorText(e));
                        }
                      },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Open WhatsApp message'),
              ),
            if (_hasPhone)
              FilledButton.icon(
                onPressed: _sending ? null : retry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                ),
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text(
                  _sending ? 'Submitting…' : 'Retry WhatsApp delivery',
                ),
              ),
            TextButton(onPressed: refresh, child: const Text('Refresh status')),
          ],
        ),
        if (!_hasPhone)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Add customer mobile number on the order to enable WhatsApp sending.',
              style: TextStyle(fontSize: 11, color: green),
            ),
          ),
      ],
    ),
  );
}
