import 'package:flutter_test/flutter_test.dart';
import 'package:Hynox_app/domain.dart';
import 'package:Hynox_app/bill_message.dart';

void main() {
  test(
    'WhatsApp bill is text with greeting, item totals and review request; no PDF attachment',
    () {
      final data = CafeData.seed(DateTime.now());
      data.profile = const BusinessProfile(
        greeting: 'Thank you!',
        reviewUrl: 'https://example.com/review',
      );
      final order = data.createOrder(
        customer: 'Customer',
        phone: '9000000099',
        lines: [
          const OrderLine(
            itemId: 'm1',
            name: 'Coffee',
            unitPrice: 6000,
            quantity: 2,
          ),
        ],
        now: DateTime.now(),
        paymentMethod: 'UPI',
      );
      final message = billMessage(order, data.businessName);
      expect(message, contains('Hello Customer'));
      expect(message, contains('Thank you!'));
      expect(message, contains('Coffee × 2: ₹120'));
      expect(message, contains('Total paid: ₹120'));
      expect(message, contains('Payment: UPI'));
      expect(message, contains('https://example.com/review'));
      expect(message, isNot(contains('.pdf')));
      final noLink = CafeData.seed(DateTime.now()).createOrder(
        customer: 'Customer',
        phone: '9000000099',
        lines: order.lines,
        now: DateTime.now(),
        paymentMethod: 'Cash',
      );
      expect(
        billMessage(noLink, 'Shop'),
        contains('Please share your review with us.'),
      );
      expect(billMessage(noLink, 'Shop'), isNot(contains('example.com')));
    },
  );
}
