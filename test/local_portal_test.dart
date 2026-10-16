import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Hynox_app/local_portal.dart';
import 'package:Hynox_app/domain.dart';
import 'package:Hynox_app/team_workspace.dart';
import 'package:Hynox_app/ui.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late LocalPortalApi api;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = await LocalPortalApi.open(prefs, CafeData.seed(DateTime.now()));
    api.database['accounts'] = {
      '9000000000': {
        'hash': LocalPortalApi.hash('team-pass'),
        'role': 'team',
        'shop': null,
      },
      '9000000002': {
        'hash': LocalPortalApi.hash('vendor-pass'),
        'role': 'vendor',
        'shop': 'daily-brew',
      },
      '9000000003': {
        'hash': LocalPortalApi.hash('other-pass'),
        'role': 'vendor',
        'shop': 'corner-cafe',
      },
    };
  });
  tearDown(() => api.client.close());
  Future<void> team() async {
    await api.request('/api/login', {
      'phone': '9000000000',
      'password': 'team-pass',
    });
  }

  testWidgets(
    'mobile team navigation opens vendor creation and profile settings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await team();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: TeamWorkspace(
            initial: await api.request('/api/admin'),
            request: api.request,
            logout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('TOTAL VENDORS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vendors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create vendor'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Shop name'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Login mobile number'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Update profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('created vendor signs into its own persisted empty workspace', () async {
    await team();
    await api.request('/api/admin/vendor', {
      'name': 'ABCD',
      'owner': 'Owner',
      'address': 'New street',
      'phone': '9000000001',
      'password': 'test-pass',
      'email': '',
    });
    final restored = await LocalPortalApi.open(
      prefs,
      CafeData.seed(DateTime.now()),
    );
    await restored.request('/api/login', {
      'phone': '9000000001',
      'password': 'test-pass',
    });
    final data = await restored.load();
    expect(data.businessName, 'ABCD');
    expect(data.profile.address, 'New street');
    expect(data.orders, isEmpty);
    expect(data.menu, isEmpty);
    await expectLater(restored.request('/api/admin'), throwsStateError);
    restored.client.close();
  });
  test('plan edits and requests are shared with team on this device', () async {
    await team();
    final admin = await api.request('/api/admin');
    final plan = Map<String, dynamic>.from(admin['plans'][0]);
    plan['price'] = 49900;
    await api.request('/api/admin/plan', plan);
    await api.request('/api/login', {
      'phone': '9000000002',
      'password': 'vendor-pass',
    });
    final catalog = await api.request('/api/catalog');
    expect(catalog['plans'][0]['price'], 49900);
    await api.request('/api/subscription/request', {'planId': plan['id']});
    await team();
    final refreshed = await api.request('/api/admin');
    expect(refreshed['counts']['pending'], 1);
    await api.request('/api/admin/subscription', {
      'shop': 'daily-brew',
      'status': 'active',
      'planId': plan['id'],
      'expiresAt': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
    });
    expect((await api.request('/api/admin'))['counts']['active'], 1);
  });
  test('wrong password and duplicate phone do not modify workspaces', () async {
    await expectLater(
      api.request('/api/login', {'phone': '9000000002', 'password': 'wrong'}),
      throwsStateError,
    );
    await team();
    await expectLater(
      api.request('/api/admin/vendor', {
        'name': 'New',
        'owner': 'Owner',
        'address': 'Street',
        'phone': '9000000002',
        'password': 'test-pass',
        'email': '',
      }),
      throwsStateError,
    );
    expect((await api.request('/api/admin'))['totalVendors'], 2);
  });
}
