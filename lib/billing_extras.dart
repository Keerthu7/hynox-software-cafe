import 'package:flutter/material.dart';
import 'domain.dart';

int? parseRupees(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(text)) {
    return null;
  }
  final parts = text.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

class BillingExtraDialog extends StatefulWidget {
  final bool customItem;
  final int maximum;
  final int initial;
  const BillingExtraDialog({
    super.key,
    this.customItem = false,
    this.maximum = 10000000,
    this.initial = 0,
  });
  @override
  State<BillingExtraDialog> createState() => _BillingExtraDialogState();
}

class _BillingExtraDialogState extends State<BillingExtraDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  late final amount = TextEditingController(
    text: widget.customItem ? '' : (widget.initial / 100).toStringAsFixed(2),
  );
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.customItem ? 'Add custom item' : 'Bill discount'),
    content: SizedBox(
      width: 340,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.customItem) ...[
              TextFormField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (v) =>
                    v!.trim().isEmpty ? 'Enter an item name' : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.customItem ? 'Price' : 'Discount amount',
                prefixText: '₹ ',
              ),
              validator: (v) {
                final n = parseRupees(v ?? '');
                return n == null ||
                        n < (widget.customItem ? 1 : 0) ||
                        n > widget.maximum
                    ? 'Enter a valid amount up to ${money(widget.maximum)}'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) {
            return;
          }
          final n = parseRupees(amount.text)!;
          if (widget.customItem) {
            Navigator.pop(
              context,
              MenuItem(
                id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                name: name.text.trim(),
                category: 'Custom',
                price: n,
              ),
            );
          } else {
            Navigator.pop(context, n);
          }
        },
        child: Text(widget.customItem ? 'Add to bill' : 'Apply discount'),
      ),
    ],
  );
}
