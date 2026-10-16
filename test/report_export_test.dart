import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Hynox_app/domain.dart';
import 'package:Hynox_app/report_export.dart';
import 'package:Hynox_app/receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Workbook exports every order and escapes customer formulas as text',
    () async {
      final data = CafeData.seed(DateTime(2026, 10, 13));
      data.businessName = 'Receipt verification café';
      data.profile = const BusinessProfile(
        greeting: 'Thank you for visiting!',
        reviewUrl: 'https://example.com/review',
      );
      const line = OrderLine(
        itemId: 'm1',
        name: 'Coffee & cake',
        unitPrice: 6010,
        quantity: 3,
      );
      final order = data.createOrder(
        lines: [line],
        now: DateTime(2026, 10, 13),
        customer: '=SUM(1,2)',
        phone: '9000000099',
        paymentMethod: 'Cash',
      );
      data.createOrder(
        lines: [line],
        now: DateTime(2026, 10, 13),
        customer: 'Pending customer',
        phone: '9000000098',
      );
      final bytes = buildReportWorkbook(data);
      final archive = ZipDecoder().decodeBytes(bytes);
      String part(String path) =>
          utf8.decode(archive.findFile(path)!.content as List<int>);
      expect(part('xl/workbook.xml'), contains('Order items'));
      final bills = part('xl/worksheets/sheet2.xml');
      expect(bills, contains('=SUM(1,2)'));
      expect(bills, isNot(contains('<f>')));
      expect(bills, contains('9000000099'));
      expect(bills, contains('Pending customer'));
      expect(part('xl/worksheets/sheet1.xml'), contains('180.3'));
      expect(part('xl/worksheets/sheet3.xml'), contains('Coffee &amp; cake'));
      if (Platform.environment['HYNOX_EXPORT_PROOF'] == '1') {
        final output = Directory('../../work/product-proof')
          ..createSync(recursive: true);
        File('${output.path}/report-check.xlsx').writeAsBytesSync(bytes);
        File(
          '${output.path}/receipt-check.pdf',
        ).writeAsBytesSync(await buildReceipt(order, data.businessName));
      }
    },
  );
  test('New bills require customer name and WhatsApp number', () {
    final data = CafeData.seed(DateTime.now());
    const line = OrderLine(
      itemId: 'm1',
      name: 'Coffee',
      unitPrice: 6000,
      quantity: 1,
    );
    expect(
      () => data.createOrder(lines: [line], now: DateTime.now()),
      throwsStateError,
    );
    expect(
      () => data.createOrder(
        lines: [line],
        now: DateTime.now(),
        customer: 'Customer',
      ),
      throwsStateError,
    );
    expect(
      () => data.createOrder(
        lines: [line],
        now: DateTime.now(),
        phone: '9000000099',
      ),
      throwsStateError,
    );
  });
}
