import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Hynox_app/domain.dart';
import 'package:Hynox_app/billing_extras.dart';
import 'package:Hynox_app/receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Tax after discount rounds to paise and snapshots business settings',
    () {
      final data = CafeData.seed(DateTime(2026, 10, 13));
      data.profile = const BusinessProfile(
        taxBasisPoints: 500,
        invoicePrefix: 'SB',
        greeting: 'Thanks!',
        reviewUrl: 'https://example.com/review',
      );
      final o = data.createOrder(
        customer: 'Customer',
        phone: '9000000099',
        lines: [
          const OrderLine(
            itemId: '1',
            name: 'Burger',
            unitPrice: 14900,
            quantity: 1,
          ),
        ],
        now: DateTime.now(),
        discount: 1000,
        paymentMethod: 'UPI',
      );
      expect(o.id, 'SB-1001');
      expect(o.tax, 695);
      expect(o.total, 14595);
      data.profile = const BusinessProfile(
        taxBasisPoints: 1800,
        greeting: 'Changed',
      );
      data.businessName = 'Changed café';
      final restored = CafeData.decode(data.encode()).orders.single;
      expect(restored.total, 14595);
      expect(restored.profile.greeting, 'Thanks!');
      expect(restored.businessName, 'The Daily Brew');
    },
  );
  test('Legacy saved data loads with zero tax and no discount', () {
    final map =
        jsonDecode(CafeData.seed(DateTime.now()).encode())
            as Map<String, dynamic>;
    map.remove('profile');
    expect(CafeData.decode(jsonEncode(map)).profile.taxBasisPoints, 0);
  });
  test('Reject discounts that exceed bill, including when editing', () {
    final data = CafeData.seed(DateTime.now());
    const line = OrderLine(
      itemId: 'x',
      name: 'Tea',
      unitPrice: 4000,
      quantity: 1,
    );
    expect(
      () =>
          data.createOrder(lines: [line], now: DateTime.now(), discount: 4000),
      throwsStateError,
    );
    final o = data.createOrder(
      customer: 'Customer',
      phone: '9000000099',
      lines: [line.withQuantity(2)],
      now: DateTime.now(),
      discount: 5000,
    );
    expect(() => data.updateLines(o.id, [line]), throwsStateError);
  });
  test('Price entry rejects excess decimals and non-finite values', () {
    expect(parseRupees('19.95'), 1995);
    expect(parseRupees('19.999'), null);
    expect(parseRupees('NaN'), null);
    expect(parseRupees('-1'), null);
  });
  test(
    'PDF with tax, greeting and QR review link generates successfully',
    () async {
      final data = CafeData.seed(DateTime.now());
      data.profile = const BusinessProfile(
        taxBasisPoints: 500,
        greeting: 'Thanks for visiting!',
        reviewUrl: 'https://example.com/review',
        address: '12 Main Road',
      );
      final o = data.createOrder(
        customer: 'Customer',
        phone: '9000000099',
        lines: [
          const OrderLine(
            itemId: 'x',
            name: 'Coffee',
            unitPrice: 6000,
            quantity: 2,
          ),
        ],
        now: DateTime.now(),
        paymentMethod: 'Cash',
      );
      expect(
        (await buildReceipt(o, data.businessName)).length,
        greaterThan(2000),
      );
    },
  );
}
