import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'domain.dart';
import 'store.dart';
import 'ui.dart';

class BusinessSettings extends StatefulWidget {
  final CafeStore store;
  const BusinessSettings({super.key, required this.store});
  @override
  State<BusinessSettings> createState() => _BusinessSettingsState();
}

class _BusinessSettingsState extends State<BusinessSettings> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late String logo;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.store.data.profile;
    logo = p.logo;
    fields = {
      'name': widget.store.data.businessName,
      'phone': p.phone,
      'address': p.address,
      'gstin': p.gstin,
      'prefix': p.invoicePrefix,
      'greeting': p.greeting,
      'review': p.reviewUrl,
      'tax': (p.taxBasisPoints / 100).toStringAsFixed(2),
    }.map((key, value) => MapEntry(key, TextEditingController(text: value)));
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();
  Future<void> pickLogo() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Business logo',
            extensions: ['png', 'jpg', 'jpeg'],
            mimeTypes: ['image/png', 'image/jpeg'],
          ),
        ],
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > 2000000) {
        throw StateError('Choose an image smaller than 2 MB.');
      }
      final decoded = img.decodeImage(bytes);
      if (decoded == null || decoded.width * decoded.height > 12000000) {
        throw StateError(
          'Choose a valid PNG or JPEG logo up to 12 megapixels.',
        );
      }
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 200 : null,
        height: decoded.height > decoded.width ? 200 : null,
      );
      final encoded = img.encodePng(resized);
      if (encoded.length > 100000) {
        throw StateError('Use a simpler logo with a smaller file size.');
      }
      if (mounted) {
        setState(() => logo = base64Encode(encoded));
      }
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.store.change((data) {
        data.businessName = value('name');
        data.profile = BusinessProfile(
          phone: value('phone'),
          address: value('address'),
          gstin: value('gstin').toUpperCase(),
          invoicePrefix: value('prefix').toUpperCase(),
          greeting: value('greeting'),
          reviewUrl: value('review'),
          logo: logo,
          taxBasisPoints: (double.parse(value('tax')) * 100).round(),
        );
      });
      if (mounted) {
        toast(
          context,
          'Business and receipt settings saved. New orders will use these details.',
        );
      }
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    int max = 100,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      maxLength: max,
      maxLines: lines,
      validator: validate,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Business settings',
          'Your identity, billing preferences and customer greeting.',
          action: FilledButton.icon(
            onPressed: busy ? null : save,
            icon: const Icon(Icons.check),
            label: Text(busy ? 'Saving…' : 'Save changes'),
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business details',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: canvas,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: logo.isEmpty
                        ? const Icon(
                            Icons.storefront_outlined,
                            color: green,
                            size: 32,
                          )
                        : Image.memory(base64Decode(logo)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : pickLogo,
                          icon: const Icon(Icons.upload_outlined),
                          label: const Text('Upload logo'),
                        ),
                        if (logo.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => logo = ''),
                            child: const Text('Remove'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              field(
                'name',
                'Business name',
                max: 60,
                validate: (v) =>
                    v!.trim().isEmpty ? 'Enter a business name' : null,
              ),
              field('phone', 'Business phone', max: 25),
              field('address', 'Business address', max: 240, lines: 3),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tax & billing',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              field(
                'gstin',
                'GSTIN (optional)',
                max: 15,
                validate: (v) =>
                    v!.isNotEmpty &&
                        !RegExp(
                          r'^[0-9]{2}[A-Za-z]{5}[0-9]{4}[A-Za-z][A-Za-z0-9]Z[A-Za-z0-9]$',
                        ).hasMatch(v)
                    ? 'Enter a valid 15-character GSTIN'
                    : null,
              ),
              field(
                'tax',
                'Tax rate (%) — added after discount',
                max: 6,
                validate: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null ||
                          !n.isFinite ||
                          n < 0 ||
                          n > 100 ||
                          !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v!)
                      ? 'Enter 0–100 with up to 2 decimals'
                      : null;
                },
              ),
              field(
                'prefix',
                'Invoice prefix',
                max: 10,
                validate: (v) =>
                    !RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(v ?? '')
                    ? 'Use 1–10 letters or digits'
                    : null,
              ),
              const Text(
                'Existing orders retain their original tax rate and business details.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Greeting & reviews',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              field(
                'greeting',
                'Thank-you greeting on the PDF',
                max: 250,
                lines: 3,
                validate: (v) => v!.trim().isEmpty ? 'Enter a greeting' : null,
              ),
              field(
                'review',
                'Review link (Google review or your feedback page)',
                max: 1000,
                validate: (v) {
                  if (v!.trim().isEmpty) {
                    return null;
                  }
                  final uri = Uri.tryParse(v.trim());
                  return uri == null ||
                          uri.scheme != 'https' ||
                          uri.host.isEmpty ||
                          uri.userInfo.isNotEmpty
                      ? 'Use a valid HTTPS review link'
                      : null;
                },
              ),
              const Text(
                'The PDF includes your greeting, review link, and QR code. Connect WhatsApp Business for automatic delivery.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
