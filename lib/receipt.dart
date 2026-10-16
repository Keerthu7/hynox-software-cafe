import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'domain.dart';
import 'settings_page.dart';
import 'ui.dart';

String _pdfMoney(int value) => 'INR ${(value / 100).toStringAsFixed(2)}';
String _printable(String text) =>
    text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
Future<pw.ThemeData>? _fontTheme;
Future<pw.ThemeData> receiptTheme() => _fontTheme ??= () async {
  final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final tamilRegular = await rootBundle.load(
    'assets/fonts/NotoSansTamil-Regular.ttf',
  );
  final tamilBold = await rootBundle.load(
    'assets/fonts/NotoSansTamil-Bold.ttf',
  );
  return pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
    fontFallback: [pw.Font.ttf(tamilRegular), pw.Font.ttf(tamilBold)],
  );
}();

Future<Uint8List> buildReceipt(
  CafeOrder order,
  String business, [
  int? templateIndex,
]) async {
  final doc = pw.Document(theme: await receiptTheme());
  final primary = getActiveThemePrimary();
  final accent = PdfColor.fromInt(primary.value);
  final template = (templateIndex ?? pdfTemplateNotifier.value).clamp(0, 2);
  final shopName = _printable(
    order.businessName.isEmpty ? business : order.businessName,
  );

  if (template == 1) {
    // ══════════════════════════════════════════════════════════════════════════
    // TEMPLATE 1: MODERN INVOICE (Executive Branded)
    // ══════════════════════════════════════════════════════════════════════════
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        footer: (_) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Powered by Hynox POS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page 1 of 1', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        build: (_) => [
          // Top accent header band
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      shopName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    if (order.profile.address.isNotEmpty)
                      pw.Text(
                        _printable(order.profile.address),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (order.profile.gstin.isNotEmpty)
                      pw.Text(
                        'GSTIN: ${order.profile.gstin}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // Metadata two-column box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.customer.isNotEmpty ? _printable(order.customer) : 'Walk-in Customer',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      if (order.phone.isNotEmpty)
                        pw.Text('WhatsApp: +91 ${order.phone}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('${order.service}${order.table.isEmpty ? '' : ' · Table ${_printable(order.table)}'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE DETAILS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accent)),
                      pw.SizedBox(height: 4),
                      pw.Text('Invoice No: ${order.id}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${shortDate(order.createdAt)} ${clockTime(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Payment: ${order.paymentMethod ?? 'Paid'}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // Items table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Description', 'Qty', 'Unit Rate', 'Amount'],
            data: List.generate(
              order.lines.length,
              (idx) {
                final line = order.lines[idx];
                return [
                  '${idx + 1}',
                  _printable(line.name),
                  '${line.quantity}',
                  (line.unitPrice / 100).toStringAsFixed(2),
                  (line.total / 100).toStringAsFixed(2),
                ];
              },
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: accent),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 12),
          // Totals box & QR Row
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_printable(order.profile.greeting), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    if (order.profile.reviewUrl.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: order.profile.reviewUrl,
                            width: 50,
                            height: 50,
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text('Scan QR to leave us a Google review!', style: const pw.TextStyle(fontSize: 8)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              pw.Expanded(
                flex: 5,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                    color: PdfColors.grey100,
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(_pdfMoney(order.subtotal), style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                      if (order.discount > 0)
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                            pw.Text('-${_pdfMoney(order.discount)}', style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tax ${(order.taxBasisPoints / 100).toStringAsFixed(2)}%:', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text(_pdfMoney(order.tax), style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                      pw.Divider(color: PdfColors.grey400),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL PAID:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent)),
                          pw.Text(_pdfMoney(order.total), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  } else if (template == 2) {
    // ══════════════════════════════════════════════════════════════════════════
    // TEMPLATE 2: COMPACT THERMAL SLIP (Fast Counter / 58-80mm Slip)
    // ══════════════════════════════════════════════════════════════════════════
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(14),
        footer: (_) => pw.Center(
          child: pw.Text('*** Powered by Hynox POS ***', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ),
        build: (_) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  shopName,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                if (order.profile.address.isNotEmpty)
                  pw.Text(_printable(order.profile.address), style: const pw.TextStyle(fontSize: 8)),
                if (order.profile.phone.isNotEmpty)
                  pw.Text('Tel: ${_printable(order.profile.phone)}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
              ],
            ),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Order: ${order.id}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('${shortDate(order.createdAt)} ${clockTime(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Cust: ${_printable(order.customer.isEmpty ? "Walk-in" : order.customer)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('${order.service}${order.table.isEmpty ? "" : " / T-${order.table}"}', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Price'],
            data: order.lines
                .map((l) => [_printable(l.name), '${l.quantity}', (l.total / 100).toStringAsFixed(2)])
                .toList(),
            border: null,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
            },
          ),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(_pdfMoney(order.subtotal), style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          if (order.discount > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('-${_pdfMoney(order.discount)}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Tax ${(order.taxBasisPoints / 100).toStringAsFixed(2)}%:', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(_pdfMoney(order.tax), style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 6),
          // High-visibility Total Banner
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            color: PdfColors.black,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL PAID (${order.paymentMethod ?? "CASH"}):', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(_pdfMoney(order.total), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(_printable(order.profile.greeting), style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
          ),
          if (order.profile.reviewUrl.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: order.profile.reviewUrl,
                width: 44,
                height: 44,
              ),
            ),
          ],
        ],
      ),
    );
  } else {
    // ══════════════════════════════════════════════════════════════════════════
    // TEMPLATE 0: CLASSIC RECEIPT (Standard Centered)
    // ══════════════════════════════════════════════════════════════════════════
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        footer: (_) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'Powered by Hynox',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (_) => [
          if (order.profile.logo.isNotEmpty) ...[
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(base64Decode(order.profile.logo)),
                width: 56,
                height: 56,
              ),
            ),
            pw.SizedBox(height: 10),
          ],
          pw.Center(
            child: pw.Text(
              shopName,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: accent,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          if (order.profile.address.isNotEmpty)
            pw.Center(
              child: pw.Text(
                _printable(order.profile.address),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          if (order.profile.phone.isNotEmpty)
            pw.Center(
              child: pw.Text(
                _printable(order.profile.phone),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          if (order.profile.gstin.isNotEmpty)
            pw.Center(
              child: pw.Text(
                'GSTIN: ${order.profile.gstin}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              order.payment == PaymentState.refunded
                  ? 'PAYMENT RECEIPT - REFUNDED'
                  : 'PAYMENT RECEIPT',
              style: pw.TextStyle(
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Order: ${order.id}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                '${shortDate(order.createdAt)} ${clockTime(order.createdAt)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          if (order.customer.isNotEmpty)
            pw.Text(
              'Customer: ${_printable(order.customer)} (+91 ${order.phone})',
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.Text(
            '${order.service}${order.table.isEmpty ? '' : ' / Table ${_printable(order.table)}'}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Qty', 'Rate', 'Amount'],
            data: order.lines
                .map(
                  (line) => [
                    _printable(line.name),
                    '${line.quantity}',
                    (line.unitPrice / 100).toStringAsFixed(2),
                    (line.total / 100).toStringAsFixed(2),
                  ],
                )
                .toList(),
            border: null,
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellPadding: const pw.EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 4,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text(
            'Subtotal: ${_pdfMoney(order.subtotal)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (order.discount > 0)
            pw.Text(
              'Discount: -${_pdfMoney(order.discount)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.Text(
            'Tax ${(order.taxBasisPoints / 100).toStringAsFixed(2)}%: ${_pdfMoney(order.tax)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total paid (${order.paymentMethod ?? '-'})',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _pdfMoney(order.total),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
          if (order.refundedAt != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Refund recorded: ${_pdfMoney(order.total)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              _printable(order.profile.greeting),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (order.profile.reviewUrl.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: order.profile.reviewUrl,
                width: 60,
                height: 60,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Scan QR to leave us a review',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  return doc.save();
}

Future<void> exportReceipt(CafeOrder order, String business, [int? templateIndex]) async {
  if (order.payment == PaymentState.unpaid) {
    throw StateError('Record payment before creating a receipt.');
  }
  await Printing.sharePdf(
    bytes: await buildReceipt(order, business, templateIndex),
    filename: '${order.id}-receipt.pdf',
  );
}
