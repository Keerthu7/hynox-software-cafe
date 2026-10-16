import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Hynox_app/domain.dart';
import 'package:Hynox_app/main.dart';
import 'package:Hynox_app/store.dart';

void main() {
  testWidgets(
    'Desktop: create paid order, persist it and open its receipt actions',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? persisted;
      int whatsappDrafts = 0;
      final store = CafeStore(
        CafeData.seed(DateTime.now()),
        (value) async => persisted = value,
        receiptStatuses: () async => {'HY-1001': 'connection_needed'},
        openWhatsApp: (order) async {
          expect(CafeData.decode(persisted!).orders.single.payment, PaymentState.paid);
          expect(order.customer, 'Customer');
          expect(order.phone, '9000000099');
          whatsappDrafts++;
          return true;
        },
      );
      await tester.pumpWidget(HynoxApp(store: store));
      await tester.tap(find.text('Café workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Customer name *'),
        'Customer',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'WhatsApp number *'),
        '9000000099',
      );
      await tester.tap(find.text('Record payment & save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      expect(store.data.orders, isEmpty);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(store.data.orders.single.total, 6000);
      expect(whatsappDrafts, 1);
      expect(store.data.orders.single.payment, PaymentState.paid);
      expect(CafeData.decode(persisted!).orders.single.total, 6000);
      expect(find.text('A good day starts here.'), findsOneWidget);
      await tester.ensureVisible(find.text('HY-1001'));
      await tester.tap(find.text('HY-1001'));
      await tester.pumpAndSettle();
      expect(find.text('Save / share PDF'), findsOneWidget);
      expect(find.text('Payment recorded via Cash'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Phone: create pay-later order using menu and cart tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = CafeStore(CafeData.seed(DateTime.now()), (_) async {});
    await tester.pumpWidget(HynoxApp(store: store));
    await tester.ensureVisible(find.text('Café workspace'));
    await tester.tap(find.text('Café workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter coffee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order (1) · ₹60'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Customer name *'),
      'Customer',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'WhatsApp number *'),
      '9000000099',
    );
    await tester.ensureVisible(find.text('Save order · Pay later'));
    await tester.tap(find.text('Save order · Pay later'));
    await tester.pumpAndSettle();
    expect(store.data.orders.single.payment, PaymentState.unpaid);
    expect(find.text('A good day starts here.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Team workspace opens without demo labels', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      HynoxApp(store: CafeStore(CafeData.seed(DateTime.now()), (_) async {})),
    );
    await tester.tap(find.text('Hynox team'));
    await tester.pumpAndSettle();
    expect(find.text('Hynox REVENUE'), findsOneWidget);
    expect(find.text('PAID SUBSCRIBERS'), findsOneWidget);
    expect(find.text('LOCAL DEMO'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
