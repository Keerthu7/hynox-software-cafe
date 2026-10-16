import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'billing_extras.dart';
import 'bill_message.dart';
import 'receipt.dart';
import 'report_export.dart';
import 'settings_page.dart';

class PosPage extends StatefulWidget {
  final CafeStore store;
  final CafeOrder? existing;
  const PosPage({super.key, required this.store, this.existing});
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final cart = <String, OrderLine>{};
  final customer = TextEditingController();
  final phone = TextEditingController();
  final table = TextEditingController();
  String? customerError;
  String? phoneError;
  String category = 'All';
  String query = '';
  String service = 'Takeaway';
  int activeTab = 0;
  bool saving = false;
  bool dirty = false;
  int discount = 0;
  late int selectedTemplate;
  int get subtotal => cart.values.fold(0, (sum, line) => sum + line.total);
  int get taxRate =>
      widget.existing?.taxBasisPoints ??
      widget.store.data.profile.taxBasisPoints;
  int get tax =>
      ((subtotal - discount).clamp(0, subtotal) * taxRate + 5000) ~/ 10000;
  int get total => subtotal - discount + tax;
  int get count => cart.values.fold(0, (sum, line) => sum + line.quantity);

  @override
  void initState() {
    super.initState();
    selectedTemplate = pdfTemplateNotifier.value.clamp(0, pdfTemplates.length - 1);
    final old = widget.existing;
    if (old != null) {
      for (final line in old.lines) {
        cart[line.itemId] = line;
      }
      customer.text = old.customer;
      phone.text = old.phone;
      table.text = old.table;
      service = old.service;
      discount = old.discount;
    }
  }

  @override
  void dispose() {
    customer.dispose();
    phone.dispose();
    table.dispose();
    super.dispose();
  }

  void add(MenuItem item) {
    final old = cart[item.id];
    if ((old?.quantity ?? 0) >= 99) {
      toast(context, 'Maximum 99 of one item per order.');
      return;
    }
    setState(() {
      dirty = true;
      cart[item.id] = old == null
          ? OrderLine(
              itemId: item.id,
              name: item.name,
              unitPrice: item.price,
              quantity: 1,
            )
          : old.withQuantity(old.quantity + 1);
    });
  }

  void removeOne(MenuItem item) {
    final old = cart[item.id];
    if (old != null) {
      decrement(old);
    }
  }

  void decrement(OrderLine line) => setState(() {
    dirty = true;
    if (line.quantity == 1) {
      cart.remove(line.itemId);
    } else {
      cart[line.itemId] = line.withQuantity(line.quantity - 1);
    }
    if (discount >= subtotal) {
      discount = 0;
    }
  });

  Future<void> customItem() async {
    final item = await showDialog<MenuItem>(
      context: context,
      builder: (_) => const BillingExtraDialog(customItem: true),
    );
    if (item != null && mounted) {
      add(item);
    }
  }

  Future<void> editDiscount() async {
    if (subtotal == 0) {
      return;
    }
    final value = await showDialog<int>(
      context: context,
      builder: (_) =>
          BillingExtraDialog(initial: discount, maximum: subtotal - 1),
    );
    if (value != null && mounted) {
      setState(() {
        discount = value;
        dirty = true;
      });
    }
  }

  Future<void> proceedWithWhatsAppBill() async {
    if (cart.isEmpty) {
      toast(context, 'Please add menu items to the order first.');
      return;
    }
    final nameVal = customer.text.trim();
    final phoneVal = phone.text.trim();
    if (nameVal.isEmpty || !RegExp(r'^\d{10}$').hasMatch(phoneVal)) {
      final filled = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final nameCtrl = TextEditingController(text: customer.text);
          final phoneCtrl = TextEditingController(text: phone.text);
          String? localErr;
          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Color(0xFF16A34A), size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customer WhatsApp Details',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter customer details to send the bill and selected PDF receipt to WhatsApp.',
                      style: TextStyle(fontSize: 12.5, color: muted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: '10-digit WhatsApp Number *',
                        prefixText: '+91 ',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        isDense: true,
                      ),
                    ),
                    if (localErr != null) ...[
                      const SizedBox(height: 10),
                      Text(localErr!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final n = nameCtrl.text.trim();
                    final p = phoneCtrl.text.trim();
                    if (n.isEmpty) {
                      setDlgState(() => localErr = 'Customer name is required.');
                      return;
                    }
                    if (!RegExp(r'^\d{10}$').hasMatch(p)) {
                      setDlgState(() => localErr = 'Enter a valid 10-digit WhatsApp number.');
                      return;
                    }
                    customer.text = n;
                    phone.text = p;
                    Navigator.pop(ctx, true);
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Continue to Payment'),
                ),
              ],
            ),
          );
        },
      );
      if (filled != true) return;
    }
    await save(pay: true);
  }

  Future<void> save({required bool pay}) async {
    if (cart.isEmpty || saving) {
      return;
    }
    if (discount < 0 || discount >= subtotal) {
      toast(context, 'Discount must be less than the subtotal.');
      return;
    }
    final nameVal = customer.text.trim();
    final phoneVal = phone.text.trim();
    bool hasValidationError = false;
    if (nameVal.isEmpty) {
      customerError = 'Customer name is mandatory';
      hasValidationError = true;
    } else {
      customerError = null;
    }
    if (phoneVal.isEmpty) {
      phoneError = 'WhatsApp mobile number is mandatory';
      hasValidationError = true;
    } else if (!RegExp(r'^\d{10}$').hasMatch(phoneVal)) {
      phoneError = 'Enter a valid 10-digit number';
      hasValidationError = true;
    } else {
      phoneError = null;
    }
    if (hasValidationError) {
      setState(() {});
      toast(context, 'Customer name and 10-digit WhatsApp number are mandatory.');
      return;
    }
    FocusScope.of(context).unfocus();
    final method = pay
        ? await paymentDialog(
            context,
            total,
            customerName: nameVal,
            customerPhone: phoneVal,
          )
        : null;
    if (pay && method == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => saving = true);
    String? savedId;
    try {
      await widget.store.change((data) {
        final old = widget.existing;
        if (old == null) {
          savedId = data
              .createOrder(
                lines: cart.values.toList(),
                now: DateTime.now(),
                customer: nameVal,
                phone: phoneVal,
                service: service,
                table: table.text,
                paymentMethod: method,
                discount: discount,
              )
              .id;
        } else {
          savedId = old.id;
          data.updateCustomer(old.id, nameVal, phoneVal);
          data.updateLines(old.id, cart.values.toList(), discount: discount);
          if (method != null) {
            data.recordPayment(old.id, method, DateTime.now());
          }
        }
      });
      String delivery = 'Order saved.';
      if (method != null) {
        final savedOrder = widget.store.data.order(savedId!);
        try {
          final pdfBytes = await buildReceipt(savedOrder, widget.store.data.businessName, selectedTemplate);
          if (mounted) {
            await exportFile(context, pdfBytes, '${savedOrder.id}-receipt.pdf', 'application/pdf');
          }
        } catch (_) {}
        try {
          await openWhatsAppMessage(
            savedOrder,
            widget.store.data.businessName,
            selectedTemplate: selectedTemplate,
          );
          delivery = 'Payment saved via $method. Selected template sent as PDF & WhatsApp bill opened.';
        } catch (_) {
          delivery = 'Payment saved via $method. PDF invoice generated.';
        }
      }
      if (mounted) {
        setState(() {
          dirty = false;
          saving = false;
        });
        Navigator.pop(context);
        toast(
          context,
          method == null ? 'Order saved. Payment is pending.' : delivery,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, errorText(error));
      }
    }
  }

  Future<void> leave() async {
    if (saving) {
      return;
    }
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text(
            'Your changes to this order have not been saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) {
        return;
      }
    }
    if (mounted) {
      setState(() => dirty = false);
      Navigator.pop(context);
    }
  }

  Widget menuPanel() {
    final activePrimary = getActiveThemePrimary();
    final menu = widget.store.data.menu
        .where(
          (e) =>
              (e.available || e.availableStock) &&
              (category == 'All' || e.category == category) &&
              e.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final categories = [
      'All',
      ...widget.store.data.menu.map((e) => e.category).toSet(),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Menu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 16, color: activePrimary),
                      const SizedBox(width: 6),
                      const Text(
                        'Template: ',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted),
                      ),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedTemplate,
                            isDense: true,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink),
                            items: [
                              for (int i = 0; i < pdfTemplates.length; i++)
                                DropdownMenuItem<int>(
                                  value: i,
                                  child: Text(
                                    pdfTemplates[i].name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => selectedTemplate = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: saving ? null : customItem,
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Custom',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Option to proceed to payment via WhatsApp bill directly above menu
          Material(
            color: cart.isNotEmpty ? const Color(0xFF16A34A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: cart.isNotEmpty ? 2 : 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: saving ? null : proceedWithWhatsAppBill,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cart.isNotEmpty ? const Color(0xFF16A34A) : border,
                  ),
                  gradient: cart.isNotEmpty
                      ? const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: cart.isNotEmpty
                            ? Colors.white.withValues(alpha: 0.25)
                            : const Color(0xFF16A34A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cart.isNotEmpty ? '$count items · ${money(total)}' : '0 items',
                        style: TextStyle(
                          color: cart.isNotEmpty ? Colors.white : const Color(0xFF16A34A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cart.isNotEmpty
                            ? 'Proceed to payment via WhatsApp bill'
                            : 'Add items to send WhatsApp bill & PDF receipt',
                        style: TextStyle(
                          color: cart.isNotEmpty ? Colors.white : muted,
                          fontWeight: cart.isNotEmpty ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: cart.isNotEmpty ? Colors.white : muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                hintText: 'Search the menu…',
                hintStyle: const TextStyle(fontSize: 12.5, color: muted),
                prefixIcon: const Icon(Icons.search, size: 18),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: activePrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final c in categories) ...[
                  InkWell(
                    onTap: () => setState(() => category = c),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: category == c ? activePrimary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: category == c ? activePrimary : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: category == c
                            ? [
                                BoxShadow(
                                  color: activePrimary.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: category == c ? FontWeight.w700 : FontWeight.w500,
                            color: category == c ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (menu.isEmpty)
            const EmptyState(
              'No matching items',
              'Try another search or add items in Menu.',
              icon: Icons.restaurant_menu,
            ),
          LayoutBuilder(
            builder: (context, size) {
              final columns = (size.maxWidth / 170).floor().clamp(2, 6);
              const gap = 10.0;
              final itemWidth = math.max(0.0, (size.maxWidth - (columns - 1) * gap) / columns - 0.2);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: menu
                    .map(
                      (item) {
                        final inCart = cart.containsKey(item.id);
                        final qty = inCart ? cart[item.id]!.quantity : 0;
                        return SizedBox(
                          width: itemWidth,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: inCart ? activePrimary.withValues(alpha: .04) : Colors.white,
                                border: Border.all(
                                  color: inCart ? activePrimary : const Color(0xFFE2E8F0),
                                  width: inCart ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (item.image.isNotEmpty) ...[
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            height: 80,
                                            width: double.infinity,
                                            child: _buildItemImage(item),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                height: 1.2,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          if (inCart)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: activePrimary,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$qty',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            money(item.price),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: inCart ? activePrimary : ink,
                                            ),
                                          ),
                                          if (item.availableStock) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'STOCK',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (inCart) ...[
                                        InkWell(
                                          onTap: saving ? null : () => removeOne(item),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: activePrimary, width: 1.2),
                                            ),
                                            child: Icon(Icons.remove, size: 15, color: activePrimary),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$qty',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                      InkWell(
                                        onTap: saving ? null : () => add(item),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          height: 28,
                                          padding: EdgeInsets.symmetric(horizontal: inCart ? 7 : 12),
                                          decoration: BoxDecoration(
                                            color: activePrimary,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.add, size: 15, color: Colors.white),
                                              if (!inCart) ...[
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'Add',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(MenuItem item) {
    if (item.image.isNotEmpty) {
      final bytes = safeLogoBytes(item.image);
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
      if (item.image.startsWith('http')) {
        return Image.network(
          item.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1F5F9),
            child: Icon(categoryIcon(item.category), color: muted, size: 28),
          ),
        );
      }
    }
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Icon(categoryIcon(item.category), color: muted, size: 28),
    );
  }

  Widget cartPanel() {
    final activePrimary = getActiveThemePrimary();
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Current order',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Pill('$count items'),
              ],
            ),
            const SizedBox(height: 20),
            if (cart.isEmpty)
              const EmptyState(
                'A fresh start',
                'Choose items from the menu to begin.',
                icon: Icons.shopping_bag_outlined,
              ),
            ...cart.values.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          money(line.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${money(line.unitPrice)} each',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Remove one ${line.name}',
                          visualDensity: VisualDensity.compact,
                          onPressed: saving ? null : () => decrement(line),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 21,
                          ),
                        ),
                        Text(
                          '${line.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add one ${line.name}',
                          visualDensity: VisualDensity.compact,
                          onPressed: saving || line.quantity >= 99
                              ? null
                              : () => setState(() {
                                  dirty = true;
                                  cart[line.itemId] = line.withQuantity(
                                    line.quantity + 1,
                                  );
                                }),
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: activePrimary,
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 28),
            const Text(
              'CUSTOMER INFORMATION',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: customer,
              enabled: !saving,
              maxLength: 80,
              onChanged: (_) {
                dirty = true;
                if (customerError != null) {
                  setState(() => customerError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Customer name *',
                prefixIcon: const Icon(Icons.person_outline),
                counterText: '',
                errorText: customerError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              enabled: !saving,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (_) {
                dirty = true;
                if (phoneError != null) {
                  setState(() => phoneError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'WhatsApp mobile number *',
                prefixIcon: const Icon(Icons.chat_bubble_outline),
                prefixText: '+91 ',
                errorText: phoneError,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        money(total),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: activePrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Subtotal ${money(subtotal)} · Discount ${money(discount)}\nTax ${(taxRate / 100).toStringAsFixed(2)}%: ${money(tax)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: muted,
                      height: 1.6,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: subtotal == 0 || saving ? null : editDiscount,
                      child: Text(discount == 0 ? 'Add discount' : 'Edit discount'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, size: 18, color: activePrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'PDF Template:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                    ),
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedTemplate,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink),
                      items: [
                        for (int i = 0; i < pdfTemplates.length; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text(pdfTemplates[i].name),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedTemplate = val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: cart.isEmpty || saving
                    ? null
                    : proceedWithWhatsAppBill,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  saving ? 'Processing…' : 'Proceed to payment · WhatsApp bill',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: cart.isEmpty || saving
                    ? null
                    : () => save(pay: false),
                child: Text(
                  widget.existing == null
                      ? 'Save order · Pay later'
                      : 'Save changes',
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        leave();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: saving ? null : leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.existing == null ? 'New order' : 'Edit ${widget.existing!.id}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, size) {
            if (size.maxWidth >= 900) {
              final cartWidth = (size.maxWidth * 0.32).clamp(360.0, 420.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: menuPanel(),
                      ),
                    ),
                  ),
                  SizedBox(width: cartWidth, child: cartPanel()),
                ],
              );
            }
            final activePrimary = getActiveThemePrimary();
            return Column(
              children: [
                // Top Custom Header Tabs
                Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: activeTab == 0 ? activePrimary : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Menu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: activeTab == 0 ? activePrimary : muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: activeTab == 1 ? activePrimary : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Bill / Order',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: activeTab == 1 ? activePrimary : muted,
                                    ),
                                  ),
                                  if (cart.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: activePrimary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: activeTab == 0 ? menuPanel() : cartPanel(),
                ),
                // Prominent Floating Bottom Bar when items are selected on Menu tab
                if (activeTab == 0 && cart.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: saving ? null : proceedWithWhatsAppBill,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF16A34A).withValues(alpha: .35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    money(total),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Row(
                                    children: [
                                      Icon(Icons.send_rounded, size: 15, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'WhatsApp Bill →',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'View detailed order bill',
                          onPressed: () => setState(() => activeTab = 1),
                          icon: const Icon(Icons.receipt_long_outlined),
                          style: IconButton.styleFrom(
                            backgroundColor: canvas,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
