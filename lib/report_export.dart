import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'domain.dart';

const spreadsheetMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
String _xml(Object? value) => '${value ?? ''}'
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
String _column(int index) {
  String result = '';
  for (int n = index + 1; n > 0; n = (n - 1) ~/ 26) {
    result = String.fromCharCode(65 + (n - 1) % 26) + result;
  }
  return result;
}

/// All dates are ISO local timestamps; monetary columns are numeric INR values.
/// Customer strings are explicit text cells, so they cannot execute Excel formulas.
Uint8List buildReportWorkbook(CafeData data) {
  final paid = data.orders
      .where((o) => o.payment != PaymentState.unpaid)
      .toList();
  final refunded = data.orders
      .where((o) => o.payment == PaymentState.refunded)
      .toList();
  final gross = paid.fold(0, (n, o) => n + o.total);
  final refunds = refunded.fold(0, (n, o) => n + o.total);
  final customers = <String, List<CafeOrder>>{};
  for (final order in data.orders) {
    if (order.phone.isNotEmpty) {
      customers.putIfAbsent(order.phone, () => []).add(order);
    }
  }
  final sheets = <String, List<List<Object?>>>{
    'Summary': [
      ['Metric', 'Value'],
      ['Business', data.businessName],
      ['Exported at', DateTime.now().toIso8601String()],
      ['Scope', 'All saved data'],
      ['Orders', data.orders.length],
      ['Payments', paid.length],
      ['Gross collected INR', gross / 100],
      ['Refunds INR', refunds / 100],
      ['Net collected INR', (gross - refunds) / 100],
      for (final method in ['Cash', 'UPI', 'Card'])
        [
          '$method collected INR',
          paid
                  .where((o) => o.paymentMethod == method)
                  .fold(0, (n, o) => n + o.total) /
              100,
        ],
    ],
    'Bills': [
      [
        'Bill',
        'Created at',
        'Customer',
        'WhatsApp number',
        'Payment status',
        'Method',
        'Paid at',
        'Stage',
        'Subtotal INR',
        'Discount INR',
        'Tax percent',
        'Tax INR',
        'Total INR',
        'Refunded at',
        'Refund reason',
        'Service',
        'Table',
        'Business',
      ],
      for (final o in data.orders)
        [
          o.id,
          o.createdAt.toIso8601String(),
          o.customer,
          o.phone,
          o.payment.name,
          o.paymentMethod,
          o.paidAt?.toIso8601String(),
          o.stage.name,
          o.subtotal / 100,
          o.discount / 100,
          o.taxBasisPoints / 100,
          o.tax / 100,
          o.total / 100,
          o.refundedAt?.toIso8601String(),
          o.refundReason,
          o.service,
          o.table,
          o.businessName,
        ],
    ],
    'Order items': [
      ['Bill', 'Item ID', 'Item', 'Quantity', 'Unit price INR', 'Amount INR'],
      for (final o in data.orders)
        for (final line in o.lines)
          [
            o.id,
            line.itemId,
            line.name,
            line.quantity,
            line.unitPrice / 100,
            line.total / 100,
          ],
    ],
    'Products': [
      ['Item ID', 'Name', 'Category', 'Price INR', 'Available'],
      for (final item in data.menu)
        [
          item.id,
          item.name,
          item.category,
          item.price / 100,
          item.available ? 'Yes' : 'No',
        ],
    ],
    'Customers': [
      ['WhatsApp number', 'Name', 'Orders', 'Paid non-refunded INR'],
      for (final entry in customers.entries)
        [
          entry.key,
          entry.value.first.customer,
          entry.value.length,
          entry.value
                  .where((o) => o.payment == PaymentState.paid)
                  .fold(0, (n, o) => n + o.total) /
              100,
        ],
    ],
    'Business': [
      ['Setting', 'Value'],
      ['Business', data.businessName],
      ['Phone', data.profile.phone],
      ['Address', data.profile.address],
      ['GSTIN', data.profile.gstin],
      ['Invoice prefix', data.profile.invoicePrefix],
      ['Next invoice number', data.nextOrderNumber],
      ['Greeting', data.profile.greeting],
      ['Review link', data.profile.reviewUrl],
      ['Tax percent', data.profile.taxBasisPoints / 100],
      ['Trial started', data.trialStartedAt.toIso8601String()],
    ],
  };
  return createExcelWorkbook(sheets);
}

Uint8List buildCustomersWorkbook(CafeData data, List<String> phones) {
  final customers = <String, List<CafeOrder>>{};
  for (final order in data.orders.where(
    (o) => o.phone.isNotEmpty && o.stage != OrderStage.cancelled,
  )) {
    if (phones.contains(order.phone)) {
      customers.putIfAbsent(order.phone, () => []).add(order);
    }
  }

  final customerRows = <List<Object?>>[
    ['WhatsApp Number', 'Customer Name', 'Total Orders', 'Paid Amount (INR)'],
    for (final entry in customers.entries) [
      entry.key,
      entry.value.first.customer.isEmpty ? 'Walk-in' : entry.value.first.customer,
      entry.value.length,
      entry.value
              .where((o) => o.payment == PaymentState.paid)
              .fold(0, (sum, o) => sum + o.total) /
          100.0,
    ],
  ];

  final historyRows = <List<Object?>>[
    ['Customer Name', 'WhatsApp Number', 'Bill ID', 'Date', 'Payment Status', 'Method', 'Total (INR)'],
    for (final entry in customers.entries)
      for (final o in entry.value) [
        o.customer.isEmpty ? 'Walk-in' : o.customer,
        o.phone,
        o.id,
        o.createdAt.toIso8601String().split('T').first,
        o.payment.name,
        o.paymentMethod ?? '-',
        o.total / 100.0,
      ],
  ];

  return createExcelWorkbook({
    'Customers': customerRows,
    'Order History': historyRows,
  });
}

Uint8List createExcelWorkbook(Map<String, List<List<Object?>>> sheets) {
  final zip = Archive();
  void add(String path, String text) {
    final bytes = utf8.encode(text);
    zip.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  const ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  add(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${List.generate(sheets.length, (i) => '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}</Types>',
  );
  add(
    '_rels/.rels',
    '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  add(
    'xl/workbook.xml',
    '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="$ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${sheets.keys.indexed.map((entry) => '<sheet name="${_xml(entry.$2)}" sheetId="${entry.$1 + 1}" r:id="rId${entry.$1 + 1}"/>').join()}</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${List.generate(sheets.length, (i) => '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>').join()}<Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
  );
  add(
    'xl/styles.xml',
    '<?xml version="1.0"?><styleSheet xmlns="$ns"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF26735D"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="2" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
  );
  for (final entry in sheets.values.indexed) {
    final rows = entry.$2;
    final xmlRows = rows.indexed
        .map(
          (row) =>
              '<row r="${row.$1 + 1}">${row.$2.indexed.map((cell) {
                final ref = '${_column(cell.$1)}${row.$1 + 1}';
                final style = row.$1 == 0
                    ? 1
                    : cell.$2 is double
                    ? 2
                    : 0;
                if (cell.$2 is num) return '<c r="$ref" s="$style"><v>${cell.$2}</v></c>';
                return '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_xml(cell.$2)}</t></is></c>';
              }).join()}</row>',
        )
        .join();
    add(
      'xl/worksheets/sheet${entry.$1 + 1}.xml',
      '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="$ns"><dimension ref="A1:${_column(rows.first.length - 1)}${rows.length}"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="${rows.first.length}" width="22" customWidth="1"/></cols><sheetData>$xmlRows</sheetData><autoFilter ref="A1:${_column(rows.first.length - 1)}${rows.length}"/></worksheet>',
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

Future<void> exportFile(
  BuildContext context,
  Uint8List bytes,
  String name,
  String mime,
) async {
  final file = XFile.fromData(bytes, name: name, mimeType: mime);
  if (kIsWeb) {
    await file.saveTo(name);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    final saved = await const MethodChannel(
      'hynox/files',
    ).invokeMethod<bool>('save', {'bytes': bytes, 'name': name, 'mime': mime});
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File saved.')));
    }
  } else {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [name],
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}
