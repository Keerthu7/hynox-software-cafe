import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Hynox_app/report_export.dart';

void main() {
  testWidgets(
    'Android export passes exact bytes to Save As; cancellation is not reported as saved',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('hynox/files');
      MethodCall? received;
      bool result = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        received = call;
        return result;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      await exportFile(context, bytes, 'reports.xlsx', spreadsheetMime);
      await tester.pump();
      expect(received!.method, 'save');
      expect(received!.arguments['name'], 'reports.xlsx');
      expect(received!.arguments['mime'], spreadsheetMime);
      expect(received!.arguments['bytes'], bytes);
      expect(find.text('File saved.'), findsNothing);
      result = true;
      await exportFile(context, bytes, 'reports.xlsx', spreadsheetMime);
      await tester.pump();
      expect(find.text('File saved.'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
