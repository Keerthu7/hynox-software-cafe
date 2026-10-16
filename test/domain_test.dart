import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Hynox_app/domain.dart';
import 'package:Hynox_app/store.dart';
import 'package:Hynox_app/receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 12, 10);
  const line = OrderLine(
    itemId: 'm1',
    name: 'Coffee',
    unitPrice: 6010,
    quantity: 3,
  );
  test(
    'Exact money, original prices, unique ids and persistence round trip',
    () {
      final data = CafeData.seed(now);
      final first = data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line],
        now: now,
        paymentMethod: 'Cash',
      );
      data.saveMenuItem(
        const MenuItem(
          id: 'm1',
          name: 'New coffee',
          category: 'Coffee',
          price: 9000,
        ),
      );
      expect(data.order(first.id).total, 18030);
      expect(data.order(first.id).lines.single.name, 'Coffee');
      final restored = CafeData.decode(data.encode());
      expect(restored.orders.single.total, 18030);
      expect(
        restored
            .createOrder(
              customer: 'Receipt customer',
              phone: '9000000099',
              lines: [line],
              now: now,
            )
            .id,
        'HY-1002',
      );
      expect(money(18030), '₹180.30');
    },
  );
  test('Invalid orders cannot be saved', () {
    final data = CafeData.seed(now);
    expect(
      () => data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [],
        now: now,
      ),
      throwsStateError,
    );
    expect(
      () => data.createOrder(
        customer: 'Receipt customer',
        lines: [line],
        now: now,
        phone: '123',
      ),
      throwsStateError,
    );
    expect(
      () => data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line],
        now: now,
        service: 'Dine-in',
      ),
      throwsStateError,
    );
    expect(
      () => data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line, line],
        now: now,
      ),
      throwsStateError,
    );
    expect(
      () => data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line.withQuantity(0)],
        now: now,
      ),
      throwsStateError,
    );
    expect(data.orders, isEmpty);
  });
  test(
    'Pay-later edit works; paid bills reject edits, duplicate payment and cancellation',
    () {
      final data = CafeData.seed(now);
      final order = data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line],
        now: now,
      );
      data.updateLines(order.id, [line.withQuantity(4)]);
      expect(data.unpaidTotal, 24040);
      data.recordPayment(order.id, 'UPI', now);
      expect(data.unpaidTotal, 0);
      expect(data.netOn(now), 24040);
      expect(() => data.recordPayment(order.id, 'Cash', now), throwsStateError);
      expect(() => data.updateLines(order.id, [line]), throwsStateError);
      expect(
        () => data.setStage(order.id, OrderStage.cancelled),
        throwsStateError,
      );
    },
  );
  test(
    'Cancel excludes unpaid balance; service stages require payment to complete',
    () {
      final data = CafeData.seed(now);
      final order = data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line],
        now: now,
      );
      data.setStage(order.id, OrderStage.ready);
      expect(
        () => data.setStage(order.id, OrderStage.completed),
        throwsStateError,
      );
      data.setStage(order.id, OrderStage.cancelled);
      expect(data.unpaidTotal, 0);
      expect(() => data.recordPayment(order.id, 'Cash', now), throwsStateError);
    },
  );
  test(
    'Refunds count on refund date without erasing original cash collection',
    () {
      final data = CafeData.seed(now);
      final order = data.createOrder(
        customer: 'Receipt customer',
        phone: '9000000099',
        lines: [line],
        now: now,
        paymentMethod: 'Cash',
      );
      final tomorrow = now.add(const Duration(days: 1));
      data.refund(order.id, 'Customer returned item', tomorrow);
      expect(data.netOn(now), 18030);
      expect(data.netOn(tomorrow), -18030);
      expect(() => data.refund(order.id, 'Again', tomorrow), throwsStateError);
      expect(() => data.updateLines(order.id, [line]), throwsStateError);
    },
  );
  test('15-day trial survives restart and ends at the exact boundary', () {
    final data = CafeData.decode(CafeData.seed(now).encode());
    expect(data.trialDaysLeft(now), 15);
    expect(data.trialDaysLeft(now.add(const Duration(days: 14, hours: 23))), 1);
    expect(data.trialDaysLeft(now.add(const Duration(days: 15))), 0);
  });
  test(
    'Storage failure leaves published data untouched and allows retry',
    () async {
      var fail = true;
      final store = CafeStore(CafeData.seed(now), (_) async {
        if (fail) {
          throw StateError('Storage full');
        }
      });
      await expectLater(
        store.change(
          (data) => data.createOrder(
            customer: 'Receipt customer',
            phone: '9000000099',
            lines: [line],
            now: now,
          ),
        ),
        throwsStateError,
      );
      expect(store.data.orders, isEmpty);
      expect(store.busy, false);
      fail = false;
      await store.change(
        (data) => data.createOrder(
          customer: 'Receipt customer',
          phone: '9000000099',
          lines: [line],
          now: now,
        ),
      );
      expect(store.data.orders.single.id, 'HY-1001');
    },
  );
  test('Receipt generation produces a PDF for a paid order', () async {
    final data = CafeData.seed(now);
    final order = data.createOrder(
      customer: 'Receipt customer',
      phone: '9000000099',
      lines: [line],
      now: now,
      paymentMethod: 'Cash',
    );
    final bytes = await buildReceipt(order, 'The Daily Brew');
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
  });
}
