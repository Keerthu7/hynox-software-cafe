import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'portal.dart';

/// Device-local accounts and workspaces for the frontend-only application.
class LocalPortalApi extends PortalApi {
  static const storageKey = 'Hynox.frontend.v1';
  final SharedPreferences prefs;
  Map<String, dynamic> database;
  String? currentPhone;
  LocalPortalApi(this.prefs, this.database);
  static String hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
  static Future<LocalPortalApi> open(
    SharedPreferences prefs,
    CafeData legacy,
  ) async {
    final singleStarterPlan = {
      'id': 'starter',
      'name': 'Starter',
      'price': 9900,
      'features': ['Billing', 'Customers', 'Reports', 'WhatsApp Bills'],
      'active': true,
      'version': 1,
    };
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      final db = jsonDecode(raw) as Map<String, dynamic>;
      db['plans'] = [singleStarterPlan];
      return LocalPortalApi(prefs, db);
    }
    final now = DateTime.now();
    final second = CafeData(
      businessName: 'Corner Cafe',
      trialStartedAt: now,
      menu: [],
      orders: [],
    );
    final api = LocalPortalApi(prefs, {
      'accounts': {
        '9345966973': {
          'hash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
          'role': 'vendor',
          'shop': 'daily-brew',
        },
        '9659694472': {
          'hash': '5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5',
          'role': 'vendor',
          'shop': 'corner-cafe',
        },
        '9865563844': {
          'hash': '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
          'role': 'team',
          'shop': null,
        },
      },
      'shops': {
        'daily-brew': jsonDecode(legacy.encode()),
        'corner-cafe': jsonDecode(second.encode()),
      },
      'vendors': {
        'daily-brew': {'owner': '', 'email': ''},
        'corner-cafe': {'owner': '', 'email': ''},
      },
      'subscriptions': {
        for (final slug in ['daily-brew', 'corner-cafe'])
          slug: {
            'status': 'trial',
            'expiresAt': now.add(const Duration(days: 15)).toIso8601String(),
          },
      },
      'profiles': {},
      'plans': [
        singleStarterPlan,
      ],
    });
    await api.persist(api.database);
    return api;
  }

  Future<void> persist(Map<String, dynamic> candidate) async {
    if (!await prefs.setString(storageKey, jsonEncode(candidate))) {
      throw StateError('Could not save changes on this device.');
    }
    database = candidate;
  }

  Map<String, dynamic> get account {
    if (currentPhone == null) throw StateError('Please sign in.');
    return Map<String, dynamic>.from(database['accounts'][currentPhone]);
  }

  void requireRole(String role) {
    if (account['role'] != role) {
      throw StateError('This account cannot access that workspace.');
    }
  }

  List<dynamic> get plans => database['plans'];
  Map<String, dynamic> subscription(String shop) {
    final result = Map<String, dynamic>.from(
      database['subscriptions'][shop] ?? {'status': 'none'},
    );
    final expiry = DateTime.tryParse(result['expiresAt'] ?? '');
    if (['active', 'trial'].contains(result['status']) &&
        expiry != null &&
        !expiry.isAfter(DateTime.now())) {
      result['status'] = 'expired';
    }
    return result;
  }

  Map<String, dynamic> dashboard() {
    final vendors = <Map<String, dynamic>>[];
    for (final entry in (database['shops'] as Map).entries) {
      final state = entry.value;
      final login = (database['accounts'] as Map).entries
          .firstWhere((a) => a.value['shop'] == entry.key)
          .key;
      vendors.add({
        'slug': entry.key,
        'name': state['businessName'],
        'address': state['profile']['address'],
        'phone': state['profile']['phone'],
        'loginPhone': login,
        'orders': state['orders'].length,
        ...Map<String, dynamic>.from(database['vendors'][entry.key]),
        'subscription': subscription(entry.key),
      });
    }
    return {
      'vendors': vendors,
      'totalVendors': vendors.length,
      'plans': plans,
      'profile': {
        'name': 'Hynox team',
        'email': '',
        'contactPhone': currentPhone,
        ...Map<String, dynamic>.from(database['profiles'][currentPhone] ?? {}),
        'loginPhone': currentPhone,
      },
      'counts': {
        for (final status in [
          'active',
          'trial',
          'expired',
          'none',
          'cancelled',
        ])
          status: vendors
              .where((v) => v['subscription']['status'] == status)
              .length,
        'pending': vendors
            .where((v) => v['subscription']['requestStatus'] == 'pending')
            .length,
      },
    };
  }

  @override
  Future<CafeData> load() async {
    requireRole('vendor');
    return CafeData.decode(jsonEncode(database['shops'][account['shop']]));
  }

  @override
  Future<void> save(String raw) async {
    requireRole('vendor');
    final candidate = jsonDecode(jsonEncode(database)) as Map<String, dynamic>;
    candidate['shops'][account['shop']] = jsonDecode(raw);
    await persist(candidate);
  }

  @override
  Future<Map<String, String>> statuses() async => {};
  @override
  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (path == '/api/login') {
      final phone = body!['phone'] as String;
      var a = database['accounts'][phone];
      if (a == null) {
        if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
          throw StateError('Enter a 10-digit mobile number.');
        }
        final password = body['password'] as String;
        if (password.length < 4) {
          throw StateError('Password must be at least 4 characters.');
        }
        final slug = 'shop-${DateTime.now().microsecondsSinceEpoch}';
        final state = CafeData(
          businessName: 'My Café',
          trialStartedAt: DateTime.now(),
          menu: [],
          orders: [],
        );
        final candidate = jsonDecode(jsonEncode(database)) as Map<String, dynamic>;
        candidate['shops'][slug] = jsonDecode(state.encode());
        candidate['accounts'][phone] = {
          'role': 'vendor',
          'shop': slug,
          'hash': hash(password),
        };
        candidate['vendors'][slug] = {'owner': '', 'email': ''};
        candidate['subscriptions'][slug] = {
          'status': 'trial',
          'expiresAt': DateTime.now().add(const Duration(days: 15)).toIso8601String(),
        };
        await persist(candidate);
        a = candidate['accounts'][phone];
      } else if (a['hash'] != hash(body['password'])) {
        throw StateError('The password does not match.');
      }
      currentPhone = phone;
      return {'token': 'local', 'role': a['role'], 'shop': a['shop']};
    }
    if (path == '/api/logout') {
      currentPhone = null;
      return {};
    }
    if (path == '/api/admin') {
      requireRole('team');
      return dashboard();
    }
    if (path == '/api/catalog') {
      requireRole('vendor');
      return {
        'plans': plans.where((p) => p['active'] == true).toList(),
        'subscription': subscription(account['shop']),
      };
    }
    final candidate = jsonDecode(jsonEncode(database)) as Map<String, dynamic>;
    if (path == '/api/password') {
      if (account['hash'] != hash(body!['current'])) {
        throw StateError('Current password is incorrect.');
      }
      if ((body['new'] as String).length < 4) {
        throw StateError('Use at least 4 characters.');
      }
      candidate['accounts'][currentPhone]['hash'] = hash(body['new']);
      await persist(candidate);
      return {};
    }
    if (path == '/api/subscription/request') {
      requireRole('vendor');
      final planMatches = plans.where((p) => p['id'] == body!['planId'] && p['active'] == true);
      if (planMatches.isEmpty) {
        throw StateError('This plan is unavailable.');
      }
      final targetPlan = planMatches.first;
      candidate['subscriptions'][account['shop']] = {
        ...subscription(account['shop']),
        'requestedPlanId': body!['planId'],
        'requestedPlanName': targetPlan['name'],
        'requestedPrice': targetPlan['price'],
        'requestStatus': 'pending',
        'requestedAt': DateTime.now().toIso8601String(),
      };
      await persist(candidate);
      return request('/api/catalog');
    }
    if (path == '/api/subscription/pay') {
      requireRole('vendor');
      final planId = body!['planId'];
      final matches = plans.where((p) => p['id'] == planId && p['active'] == true);
      if (matches.isEmpty) {
        throw StateError('This plan is unavailable.');
      }
      final targetPlan = matches.first;
      final currentSub = subscription(account['shop']);
      final now = DateTime.now();
      final currentExpiry = DateTime.tryParse(currentSub['expiresAt'] ?? '');
      final newExpiry = (currentExpiry != null && currentExpiry.isAfter(now))
          ? currentExpiry.add(const Duration(days: 30))
          : now.add(const Duration(days: 30));
      candidate['subscriptions'][account['shop']] = {
        'status': 'active',
        'planId': targetPlan['id'],
        'planName': targetPlan['name'],
        'price': targetPlan['price'],
        'expiresAt': newExpiry.toIso8601String(),
        'paidAt': now.toIso8601String(),
        'paymentMethod': body['method'] ?? 'UPI',
      };
      await persist(candidate);
      return request('/api/catalog');
    }
    if (path == '/api/receipt') {
      requireRole('vendor');
      return {};
    }
    requireRole('team');
    final values = Map<String, dynamic>.from(body ?? {});
    if (path == '/api/admin/profile') {
      candidate['profiles'][currentPhone] = values;
    } else if (path == '/api/admin/vendor') {
      final phone = values['phone'] as String;
      if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        throw StateError('Enter a 10-digit mobile number.');
      }
      var slug = values['slug'];
      if (slug == null) {
        if (candidate['accounts'][phone] != null) {
          throw StateError('This mobile number already has an account.');
        }
        if ((values['password'] as String).length < 4) {
          throw StateError('Use at least 4 password characters.');
        }
        slug = 'shop-${DateTime.now().microsecondsSinceEpoch}';
        final state = CafeData(
          businessName: values['name'],
          trialStartedAt: DateTime.now(),
          menu: [],
          orders: [],
        );
        candidate['shops'][slug] = jsonDecode(state.encode());
        candidate['accounts'][phone] = {
          'role': 'vendor',
          'shop': slug,
          'hash': hash(values['password']),
        };
        candidate['subscriptions'][slug] = {
          'status': 'trial',
          'expiresAt': state.trialEndsAt.toIso8601String(),
        };
      }
      candidate['shops'][slug]['businessName'] = values['name'];
      candidate['shops'][slug]['profile']['address'] = values['address'];
      candidate['shops'][slug]['profile']['phone'] = phone;
      candidate['vendors'][slug] = {
        'owner': values['owner'],
        'email': values['email'],
      };
    } else if (path == '/api/admin/plan') {
      final id = values['id'];
      final list = candidate['plans'] as List;
      if (id == null) {
        values['id'] = 'plan-${DateTime.now().microsecondsSinceEpoch}';
        values['version'] = 1;
        list.add(values);
      } else {
        final index = list.indexWhere((p) => p['id'] == id);
        if (index < 0) throw StateError('Plan not found.');
        values['version'] = (list[index]['version'] as int) + 1;
        list[index] = values;
      }
    } else if (path == '/api/admin/subscription') {
      final shop = values['shop'];
      final status = values['status'];
      if (status == 'active' || status == 'trial') {
        final expiry = DateTime.tryParse(values['expiresAt'] ?? '');
        if (expiry == null || !expiry.isAfter(DateTime.now())) {
          throw StateError('Enter a future expiry date.');
        }
        values['expiresAt'] = expiry.toIso8601String();
      }
      if (status == 'active') {
        final matches = plans.where(
          (p) => p['id'] == values['planId'] && p['active'] == true,
        );
        if (matches.isEmpty) throw StateError('Choose a published plan.');
        values['planName'] = matches.first['name'];
        values['price'] = matches.first['price'];
      }
      values.remove('requestStatus');
      values.remove('requestedPlanId');
      values.remove('requestedPlanName');
      values.remove('requestedPrice');
      values.remove('requestedAt');
      candidate['subscriptions'][shop] = values;
    } else if (path == '/api/admin/subscription/accept') {
      final shop = values['shop'];
      final sub = subscription(shop);
      final planId = values['planId'] ?? sub['requestedPlanId'];
      final matches = plans.where((p) => p['id'] == planId && p['active'] != false);
      if (matches.isEmpty) throw StateError('Plan not found.');
      final targetPlan = matches.first;
      final now = DateTime.now();
      final currentExpiry = DateTime.tryParse(sub['expiresAt'] ?? '');
      final newExpiry = (currentExpiry != null && currentExpiry.isAfter(now))
          ? currentExpiry.add(const Duration(days: 30))
          : now.add(const Duration(days: 30));
      candidate['subscriptions'][shop] = {
        'status': 'active',
        'planId': targetPlan['id'],
        'planName': targetPlan['name'],
        'price': targetPlan['price'],
        'expiresAt': newExpiry.toIso8601String(),
        'activatedAt': now.toIso8601String(),
        'activatedBy': 'Hynox team',
      };
    } else {
      throw StateError('This action is unavailable.');
    }
    await persist(candidate);
    return dashboard();
  }
}
