import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Receipt font bytes parse', () async {
    for (final name in [
      'NotoSans-Regular',
      'NotoSans-Bold',
      'NotoSansTamil-Regular',
      'NotoSansTamil-Bold',
    ]) {
      final data = await rootBundle.load('assets/fonts/$name.ttf');
      expect(data.lengthInBytes, greaterThan(70000));
      try {
        pw.Font.ttf(data);
      } catch (e, s) {
        throw StateError('$name $e\n$s');
      }
    }
  });
}
