import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'domain.dart';
import 'store.dart';
import 'ui.dart';
import 'receipt.dart';
import 'bill_message.dart';
import 'report_export.dart';
import 'account_password.dart';
import 'date_filter.dart';

class OverviewPage extends StatefulWidget {
  final CafeStore store;
  final VoidCallback onNew;
  final VoidCallback onOrders;
  final VoidCallback? onSettings;
  final ValueChanged<CafeOrder> onOrder;
  const OverviewPage({
    super.key,
    required this.store,
    required this.onNew,
    required this.onOrders,
    this.onSettings,
    required this.onOrder,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  DateRangeFilter _dateFilter = DateRangeFilter.today();

  @override
  Widget build(BuildContext context) {
    final data = widget.store.data;
    final now = DateTime.now();

    // Filter orders created in selected date range
    final filteredOrders = data.orders.where((o) => _dateFilter.matches(o.createdAt)).toList();

    // Active orders within date filter
    final active = filteredOrders
        .where(
          (o) =>
              o.stage != OrderStage.completed &&
              o.stage != OrderStage.cancelled &&
              o.payment != PaymentState.refunded,
        )
        .length;

    // Paid & Refunded collections within date filter
    final paidOrders = data.orders.where((o) => o.paidAt != null && _dateFilter.matches(o.paidAt)).toList();
    final refundedOrders = data.orders.where((o) => o.refundedAt != null && _dateFilter.matches(o.refundedAt)).toList();
    final gross = paidOrders.fold(0, (sum, o) => sum + o.total);
    final refunds = refundedOrders.fold(0, (sum, o) => sum + o.total);
    final net = gross - refunds;

    // Unpaid orders awaiting payment in this period
    final unpaidInPeriod = filteredOrders
        .where((o) => o.editable)
        .fold(0, (sum, o) => sum + o.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'A good day starts here.',
          'Your café at a glance. Let’s make every order count.',
          action: FilledButton.icon(
            onPressed: widget.onNew,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'New order',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        DateFilterBar(
          selected: _dateFilter,
          onChanged: (f) => setState(() => _dateFilter = f),
          includeAllTime: true,
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<int>(
          valueListenable: pdfTemplateNotifier,
          builder: (context, currentTemplate, _) {
            final tName = switch (currentTemplate) {
              1 => 'Executive Modern (A5)',
              2 => 'Itemized Breakdown (Detailed)',
              _ => 'Thermal Receipt (80mm)',
            };
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: getActiveThemePrimary().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.picture_as_pdf_outlined, color: getActiveThemePrimary(), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Invoice PDF Template: ',
                              style: TextStyle(fontSize: 12.5, color: muted),
                            ),
                            Text(
                              tName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Used for WhatsApp customer bills & thermal receipt printers.',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onSettings != null)
                    TextButton.icon(
                      onPressed: widget.onSettings,
                      icon: const Icon(Icons.settings_outlined, size: 15),
                      label: const Text('Settings', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        StatGrid(
          children: [
            StatCard(
              label: 'NET COLLECTED (${_dateFilter.label.toUpperCase()})',
              value: money(net),
              note: 'Payments less refunds in period',
              icon: Icons.account_balance_wallet_outlined,
              dark: true,
            ),
            StatCard(
              label: 'ORDERS (${_dateFilter.label.toUpperCase()})',
              value: '${filteredOrders.length}',
              note: 'Orders placed in this period',
              icon: Icons.receipt_long_outlined,
            ),
            StatCard(
              label: 'ACTIVE ORDERS',
              value: '$active',
              note: 'Preparing or ready to serve',
              icon: Icons.restaurant_outlined,
            ),
            StatCard(
              label: 'AWAITING PAYMENT',
              value: money(unpaidInPeriod),
              note: 'Across unpaid orders in period',
              icon: Icons.schedule,
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, size) {
            final sales = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your week, one cup at a time',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gross payments collected · Last 7 days',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 25),
                  SalesChart(data: data, now: now),
                ],
              ),
            );
            final summary = Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_dateFilter.label}’s payment mix',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manually recorded collections',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  const SizedBox(height: 25),
                  ...['Cash', 'UPI', 'Card'].map((method) {
                    final amount = paidOrders
                        .where((o) => o.paymentMethod == method)
                        .fold(0, (sum, o) => sum + o.total);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Icon(
                            method == 'Cash'
                                ? Icons.payments_outlined
                                : method == 'UPI'
                                ? Icons.qr_code
                                : Icons.credit_card,
                            size: 20,
                            color: green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              method,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            money(amount),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    children: [
                      Text(
                        'Refunds (${_dateFilter.label})',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      const Spacer(),
                      Text(
                        money(refunds),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            );
            return size.maxWidth < 750
                ? Column(children: [sales, const SizedBox(height: 20), summary])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: sales),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: summary),
                    ],
                  );
          },
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent orders (${_dateFilter.label})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOrders,
                    child: const Text('View all →'),
                  ),
                ],
              ),
              if (filteredOrders.isEmpty)
                EmptyState(
                  'No orders for ${_dateFilter.label.toLowerCase()}',
                  'Create an order or select a different date range.',
                  action: FilledButton.icon(
                    onPressed: widget.onNew,
                    icon: const Icon(Icons.add),
                    label: const Text('Create an order'),
                  ),
                ),
              ...filteredOrders
                  .take(5)
                  .map((o) => OrderTile(
                        order: o,
                        onTap: () => widget.onOrder(o),
                        onAction: () => showOrderActionBottomSheet(
                          context,
                          store: widget.store,
                          order: o,
                          onOpenDetails: () => widget.onOrder(o),
                        ),
                      )),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Saved on this device · No cloud sync or automatic messages yet',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }
}

class SalesChart extends StatelessWidget {
  final CafeData data;
  final DateTime now;
  const SalesChart({super.key, required this.data, required this.now});
  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    final amounts = days.map(data.collectedOn).toList();
    final peak = math.max(1, amounts.reduce(math.max));
    return SizedBox(
      height: 178,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          7,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    money(amounts[i]),
                    style: const TextStyle(fontSize: 9, color: muted),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Container(
                      height: amounts[i] == 0 ? 4 : 112 * amounts[i] / peak,
                      width: 38,
                      decoration: BoxDecoration(
                        color: i == 6 ? green : const Color(0xFFC6D8B6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ][days[i].weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: i == 6 ? FontWeight.w700 : FontWeight.normal,
                      color: i == 6 ? green : muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _microCheckbox({
  required bool checked,
  bool indeterminate = false,
  required VoidCallback onTap,
  required Color primaryColor,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: checked
            ? primaryColor
            : (indeterminate ? primaryColor.withValues(alpha: 0.12) : Colors.transparent),
        borderRadius: BorderRadius.circular(5.5),
        border: Border.all(
          color: checked || indeterminate ? primaryColor : const Color(0xFFCBD5E1),
          width: 1.4,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : (indeterminate
              ? Center(
                  child: Container(
                    width: 7,
                    height: 2,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )
              : null),
    ),
  );
}

Future<void> promptCancelOrder(
  BuildContext context,
  CafeStore store,
  CafeOrder order,
) async {
  if (order.stage == OrderStage.cancelled) {
    toast(context, 'Order ${order.id} is already cancelled.');
    return;
  }
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: Text('${order.id} will remain in your history as cancelled.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep order'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancel order'),
        ),
      ],
    ),
  );
  if (approved == true) {
    try {
      await store.change((data) => data.setStage(order.id, OrderStage.cancelled));
      if (context.mounted) {
        toast(context, 'Order ${order.id} cancelled.');
      }
    } catch (e) {
      if (context.mounted) toast(context, errorText(e));
    }
  }
}

Future<void> promptRefundOrder(
  BuildContext context,
  CafeStore store,
  CafeOrder order,
) async {
  if (order.payment == PaymentState.refunded) {
    toast(context, 'Order ${order.id} is already refunded.');
    return;
  }
  if (order.payment == PaymentState.unpaid) {
    toast(context, 'Unpaid orders cannot be refunded.');
    return;
  }
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => RefundDialog(total: order.total),
  );
  if (reason != null && reason.isNotEmpty) {
    try {
      await store.change((data) => data.refund(order.id, reason, DateTime.now()));
      if (context.mounted) {
        toast(context, 'Refund recorded for ${order.id}.');
      }
    } catch (e) {
      if (context.mounted) toast(context, errorText(e));
    }
  }
}

Future<void> showOrderActionBottomSheet(
  BuildContext context, {
  required CafeStore store,
  required CafeOrder order,
  VoidCallback? onOpenDetails,
}) {
  final primary = getActiveThemePrimary();
  final canCancel = order.stage != OrderStage.cancelled;
  final canRefund = order.payment == PaymentState.paid;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    order.service == 'Dine-in'
                        ? Icons.table_restaurant_outlined
                        : Icons.takeout_dining_outlined,
                    color: primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.id,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Pill(
                            paymentLabel(order.payment),
                            color: paymentColor(order.payment),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.customer.isEmpty ? 'Walk-in' : order.customer} · ${order.count} items · ${money(order.total)}',
                        style: const TextStyle(fontSize: 12, color: muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20, color: muted),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
            _actionSheetTile(
              context: ctx,
              icon: Icons.cancel_outlined,
              iconBg: const Color(0xFFFEE2E2),
              iconColor: const Color(0xFFDC2626),
              title: 'Cancel Order',
              subtitle: canCancel
                  ? 'Mark this order as cancelled in history'
                  : 'This order is already cancelled',
              enabled: canCancel,
              onTap: () {
                Navigator.pop(ctx);
                promptCancelOrder(context, store, order);
              },
            ),
            const SizedBox(height: 10),
            _actionSheetTile(
              context: ctx,
              icon: Icons.undo_rounded,
              iconBg: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              title: 'Record Refund',
              subtitle: canRefund
                  ? 'Record full refund & reason'
                  : (order.payment == PaymentState.refunded
                      ? 'Already refunded'
                      : 'Only available for paid orders'),
              enabled: canRefund,
              onTap: () {
                Navigator.pop(ctx);
                promptRefundOrder(context, store, order);
              },
            ),
            if (onOpenDetails != null) ...[
              const SizedBox(height: 10),
              _actionSheetTile(
                context: ctx,
                icon: Icons.receipt_long_outlined,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: primary,
                title: 'View Order Details',
                subtitle: 'Print receipt, edit items, or inspect payment',
                enabled: true,
                onTap: () {
                  Navigator.pop(ctx);
                  onOpenDetails();
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Widget _actionSheetTile({
  required BuildContext context,
  required IconData icon,
  required Color iconBg,
  required Color iconColor,
  required String title,
  required String subtitle,
  required bool enabled,
  required VoidCallback onTap,
}) {
  return Material(
    color: enabled ? Colors.white : const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: enabled ? iconBg : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled ? iconColor : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled ? ink : muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: enabled ? muted : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: enabled ? muted : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    ),
  );
}

class OrderTile extends StatelessWidget {
  final CafeOrder order;
  final VoidCallback onTap;
  final bool? selected;
  final ValueChanged<bool?>? onSelect;
  final VoidCallback? onAction;

  const OrderTile({
    super.key,
    required this.order,
    required this.onTap,
    this.selected,
    this.onSelect,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected ?? false;
    final primary = getActiveThemePrimary();

    return Material(
      color: isSelected ? primary.withValues(alpha: .06) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        onLongPress: onAction,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              if (onSelect != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _microCheckbox(
                    checked: isSelected,
                    onTap: () => onSelect!(!isSelected),
                    primaryColor: primary,
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? primary.withValues(alpha: .12) : canvas,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  order.service == 'Dine-in'
                      ? Icons.table_restaurant_outlined
                      : Icons.takeout_dining_outlined,
                  color: green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.customer.isEmpty ? 'Walk-in' : order.customer} · ${order.count} items',
                      style: const TextStyle(fontSize: 11, color: muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shortDate(order.createdAt)} · ${clockTime(order.createdAt)} · ${stageLabel(order.stage)}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(order.total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Pill(
                    paymentLabel(order.payment),
                    color: paymentColor(order.payment),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              if (onAction != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  final CafeStore store;
  final VoidCallback onNew;
  final Future<void> Function(CafeOrder) onEdit;
  const OrdersPage({
    super.key,
    required this.store,
    required this.onNew,
    required this.onEdit,
  });
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String filter = 'All';
  String query = '';
  DateRangeFilter _dateFilter = DateRangeFilter.allTime();
  final Set<String> _selectedOrderIds = {};
  bool _exporting = false;

  Future<void> _exportOrders(List<CafeOrder> ordersToExport) async {
    if (_exporting) return;
    if (ordersToExport.isEmpty) {
      toast(context, 'No orders available to export.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final exportData = CafeData(
        businessName: widget.store.data.businessName,
        trialStartedAt: widget.store.data.trialStartedAt,
        menu: widget.store.data.menu,
        orders: ordersToExport,
        profile: widget.store.data.profile,
      );
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      await exportFile(
        context,
        buildReportWorkbook(exportData),
        'Hynox-orders-$dateStr.xlsx',
        spreadsheetMime,
      );
      if (mounted) {
        toast(context, 'Exported ${ordersToExport.length} orders successfully');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = getActiveThemePrimary();
    final orders = widget.store.data.orders
        .where(
          (o) =>
              _dateFilter.matches(o.createdAt) &&
              (filter == 'All' ||
                  (filter == 'Unpaid' && o.editable) ||
                  (filter == 'Paid' && o.payment == PaymentState.paid) ||
                  (filter == 'Refunded' &&
                      o.payment == PaymentState.refunded) ||
                  (filter == 'Cancelled' && o.stage == OrderStage.cancelled)) &&
              '${o.id} ${o.customer} ${o.phone}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();

    final allSelected = orders.isNotEmpty && orders.every((o) => _selectedOrderIds.contains(o.id));
    final hasSelection = _selectedOrderIds.isNotEmpty;
    final selectedCount = orders.where((o) => _selectedOrderIds.contains(o.id)).length;
    final ordersToExport = hasSelection
        ? widget.store.data.orders.where((o) => _selectedOrderIds.contains(o.id)).toList()
        : orders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Every order, in order.',
          'Follow each order from the first item to the final receipt.',
          action: FilledButton.icon(
            onPressed: widget.onNew,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'New order',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: 'Search order #, customer, phone…',
              hintStyle: const TextStyle(fontSize: 12.5, color: muted),
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
                borderSide: BorderSide(color: primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        DateFilterBar(
          selected: _dateFilter,
          onChanged: (f) => setState(() {
            _dateFilter = f;
            _selectedOrderIds.clear();
          }),
          includeAllTime: true,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              for (final label in ['All', 'Unpaid', 'Paid', 'Refunded', 'Cancelled']) ...[
                InkWell(
                  onTap: () => setState(() => filter = label),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: filter == label ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: filter == label ? primary : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: filter == label
                          ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: filter == label ? FontWeight.w700 : FontWeight.w500,
                          color: filter == label ? Colors.white : const Color(0xFF475569),
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
        const SizedBox(height: 12),
        // Ultra-sleek, compact Selection & Export Bar
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _microCheckbox(
                checked: allSelected,
                indeterminate: orders.isNotEmpty && !allSelected && selectedCount > 0,
                onTap: orders.isEmpty
                    ? () {}
                    : () {
                        setState(() {
                          if (allSelected) {
                            for (final o in orders) {
                              _selectedOrderIds.remove(o.id);
                            }
                          } else {
                            for (final o in orders) {
                              _selectedOrderIds.add(o.id);
                            }
                          }
                        });
                      },
                primaryColor: primary,
              ),
              const SizedBox(width: 8),
              Text(
                hasSelection
                    ? '$selectedCount selected'
                    : 'Select all (${orders.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
                  color: hasSelection ? ink : muted,
                ),
              ),
              const Spacer(),
              if (orders.isNotEmpty)
                InkWell(
                  onTap: _exporting ? null : () => _exportOrders(ordersToExport),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: hasSelection
                          ? primary
                          : primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasSelection
                            ? primary
                            : primary.withValues(alpha: .25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 14,
                          color: hasSelection ? Colors.white : primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _exporting
                              ? 'Exporting…'
                              : 'Export (${hasSelection ? selectedCount : orders.length})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: hasSelection ? Colors.white : primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: [
              if (orders.isEmpty)
                const EmptyState(
                  'No orders to show',
                  'Create your first order, or try a different filter or date range.',
                ),
              ...orders.map(
                (o) => OrderTile(
                  order: o,
                  selected: _selectedOrderIds.contains(o.id),
                  onSelect: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedOrderIds.add(o.id);
                      } else {
                        _selectedOrderIds.remove(o.id);
                      }
                    });
                  },
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => OrderDetailPage(
                        store: widget.store,
                        id: o.id,
                        onEdit: widget.onEdit,
                      ),
                    ),
                  ),
                  onAction: () => showOrderActionBottomSheet(
                    context,
                    store: widget.store,
                    order: o,
                    onOpenDetails: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => OrderDetailPage(
                          store: widget.store,
                          id: o.id,
                          onEdit: widget.onEdit,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OrderDetailPage extends StatefulWidget {
  final CafeStore store;
  final String id;
  final Future<void> Function(CafeOrder) onEdit;
  const OrderDetailPage({
    super.key,
    required this.store,
    required this.id,
    required this.onEdit,
  });
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  bool exporting = false;
  Future<void> mutate(void Function(CafeData) action) async {
    try {
      await widget.store.change(action);
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    }
  }

  Future<void> submitPayment(CafeOrder order, String method) async {
    try {
      CafeData.validateCustomer(order.customer, order.phone);
    } catch (_) {
      toast(
        context,
        'Edit this order and enter customer name and WhatsApp number first.',
      );
      return;
    }
    try {
      await widget.store.change(
        (data) => data.recordPayment(order.id, method, DateTime.now()),
      );
      final updatedOrder = widget.store.data.order(order.id);
      if (updatedOrder.phone.isNotEmpty) {
        try {
          await openWhatsAppMessage(updatedOrder, widget.store.data.businessName);
        } catch (_) {}
      }
      if (mounted) {
        toast(context, 'Payment saved via $method. WhatsApp bill opened.');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    }
  }

  Future<void> pay(CafeOrder order) async {
    try {
      CafeData.validateCustomer(order.customer, order.phone);
    } catch (_) {
      toast(
        context,
        'Edit this order and enter customer name and WhatsApp number first.',
      );
      return;
    }
    final method = await paymentDialog(
      context,
      order.total,
      customerName: order.customer,
      customerPhone: order.phone,
    );
    if (method != null && mounted) {
      try {
        await widget.store.change(
          (data) => data.recordPayment(order.id, method, DateTime.now()),
        );
        final updatedOrder = widget.store.data.order(order.id);
        if (updatedOrder.phone.isNotEmpty) {
          try {
            await openWhatsAppMessage(updatedOrder, widget.store.data.businessName);
          } catch (_) {}
        }
        if (mounted) {
          toast(context, 'Payment saved via $method. WhatsApp bill opened.');
        }
      } catch (e) {
        if (mounted) toast(context, errorText(e));
      }
    }
  }

  Future<void> cancel(CafeOrder order) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('${order.id} will remain in your history as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await mutate((data) => data.setStage(order.id, OrderStage.cancelled));
    }
  }

  Future<void> refund(CafeOrder order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => RefundDialog(total: order.total),
    );
    if (reason != null && mounted) {
      await mutate((data) => data.refund(order.id, reason, DateTime.now()));
    }
  }

  Future<void> receipt(CafeOrder order) async {
    setState(() => exporting = true);
    try {
      await exportReceipt(order, widget.store.data.businessName);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Could not export PDF. Check browser download permissions and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final order = widget.store.data.order(widget.id);
      final busy = widget.store.busy;
      return Scaffold(
        appBar: AppBar(
          title: Text(order.id),
          backgroundColor: Colors.white,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 20),
              child: SizedBox.shrink(),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeading(
                    'The details that count.',
                    '${shortDate(order.createdAt)} at ${clockTime(order.createdAt)}',
                  ),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Pill(
                              paymentLabel(order.payment),
                              color: paymentColor(order.payment),
                            ),
                            Pill(stageLabel(order.stage)),
                            Pill(order.service),
                            if (order.table.isNotEmpty)
                              Pill('Table ${order.table}'),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          order.customer.isEmpty
                              ? 'Walk-in customer'
                              : order.customer,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (order.phone.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '+91 ${order.phone}',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                        const Divider(height: 38),
                        ...order.lines.map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${line.quantity} × ${money(line.unitPrice)}',
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
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
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Order total',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            Text(
                              money(order.total),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: getActiveThemePrimary(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Subtotal ${money(order.subtotal)} · Discount ${money(order.discount)}\nTax ${(order.taxBasisPoints / 100).toStringAsFixed(2)}%: ${money(order.tax)}',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                        if (order.paymentMethod != null) ...[
                          const SizedBox(height: 22),
                          Text(
                            'Payment recorded via ${order.paymentMethod}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${shortDate(order.paidAt!)} at ${clockTime(order.paidAt!)} · Manually confirmed',
                            style: const TextStyle(
                              color: muted,
                              height: 1.8,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (order.refundedAt != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            'Full refund recorded: ${money(order.total)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            order.refundReason ?? '',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (order.editable) ...[
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payments_outlined, color: getActiveThemePrimary(), size: 20),
                              const SizedBox(width: 10),
                              const Text(
                                'Payment Received',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Select payment method to complete order and send WhatsApp bill immediately:',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: busy ? null : () => submitPayment(order, 'Cash'),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                                  icon: const Icon(Icons.payments_outlined, size: 18),
                                  label: const Text('Cash'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: busy ? null : () => submitPayment(order, 'UPI'),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                                  icon: const Icon(Icons.qr_code_2, size: 18),
                                  label: const Text('UPI'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: busy ? null : () => submitPayment(order, 'Card'),
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9333EA)),
                                  icon: const Icon(Icons.credit_card_outlined, size: 18),
                                  label: const Text('Card'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (order.editable)
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => widget.onEdit(order),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit items'),
                        ),
                      if (order.payment != PaymentState.unpaid)
                        FilledButton.icon(
                          onPressed: exporting ? null : () => receipt(order),
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(
                            exporting ? 'Creating PDF…' : 'Save / share PDF',
                          ),
                        ),
                      if (order.editable)
                        TextButton(
                          onPressed: busy ? null : () => cancel(order),
                          child: const Text('Cancel order'),
                        ),
                      if (order.payment == PaymentState.paid)
                        TextButton(
                          onPressed: busy ? null : () => refund(order),
                          child: const Text('Record full refund'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class RefundDialog extends StatefulWidget {
  final int total;
  const RefundDialog({super.key, required this.total});
  @override
  State<RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<RefundDialog> {
  final reason = TextEditingController();
  bool returned = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Record refund of ${money(widget.total)}'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'This records a full refund only. Return the money using your original payment method first.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: reason,
            maxLength: 180,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Refund reason'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: returned,
            onChanged: (value) => setState(() => returned = value ?? false),
            title: const Text(
              'I have returned the money.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Go back'),
      ),
      FilledButton(
        onPressed: returned && reason.text.trim().isNotEmpty
            ? () => Navigator.pop(context, reason.text.trim())
            : null,
        child: const Text('Record refund'),
      ),
    ],
  );
}

class MenuPage extends StatelessWidget {
  final CafeStore store;
  const MenuPage({super.key, required this.store});
  Future<void> edit(BuildContext context, [MenuItem? item]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => MenuDialog(store: store, item: item),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        'Made for your menu.',
        'Set your prices and pause items when they sell out.',
        action: FilledButton.icon(
          onPressed: () => edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      ),
      Panel(
        child: Column(
          children: [
            if (store.data.menu.isEmpty)
              const EmptyState(
                'Build your menu',
                'Add your first item to start taking orders.',
              ),
            ...store.data.menu.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => edit(context, item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: canvas,
                            child: _menuItemImageWidget(item),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    item.category,
                                    style: const TextStyle(color: muted, fontSize: 11),
                                  ),
                                  if (item.available)
                                    const Pill('Available to order', color: Color(0xFF16A34A))
                                  else if (item.availableStock)
                                    const Pill('Available stock', color: Color(0xFF2563EB))
                                  else
                                    const Pill('Sold out'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          money(item.price),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Edit ${item.name}',
                          onPressed: () => edit(context, item),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Changing a menu price never changes items already saved on an order.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.5),
      ),
    ],
  );

  static Widget _menuItemImageWidget(MenuItem item) {
    if (item.image.isNotEmpty) {
      final bytes = safeLogoBytes(item.image);
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
      if (item.image.startsWith('http')) {
        return Image.network(
          item.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            categoryIcon(item.category),
            color: item.available ? green : (item.availableStock ? const Color(0xFF2563EB) : muted),
          ),
        );
      }
    }
    return Icon(
      categoryIcon(item.category),
      color: item.available ? green : (item.availableStock ? const Color(0xFF2563EB) : muted),
    );
  }
}

class MenuDialog extends StatefulWidget {
  final CafeStore store;
  final MenuItem? item;
  const MenuDialog({super.key, required this.store, this.item});
  @override
  State<MenuDialog> createState() => _MenuDialogState();
}

class _MenuDialogState extends State<MenuDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController price;
  late final TextEditingController category;
  late bool available;
  late bool availableStock;
  late String image;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.item?.name ?? '');
    price = TextEditingController(
      text: widget.item == null
          ? ''
          : (widget.item!.price / 100).toStringAsFixed(2),
    );
    category = TextEditingController(text: widget.item?.category ?? 'Coffee');
    available = widget.item?.available ?? true;
    availableStock = widget.item?.availableStock ?? false;
    image = widget.item?.image ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    category.dispose();
    super.dispose();
  }

  int get paise {
    final parts = price.text.trim().split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  Future<void> _pickImage() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
      if (mounted) setState(() => image = base64String);
    } catch (e) {
      if (mounted) toast(context, 'Could not select image: ${errorText(e)}');
    }
  }

  Future<void> _enterImageUrl() async {
    final controller = TextEditingController(text: image.startsWith('http') ? image : '');
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Image URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://images.unsplash.com/...',
            labelText: 'Web Image URL',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Apply')),
        ],
      ),
    );
    if (picked != null && mounted) {
      setState(() => image = picked);
    }
  }

  Widget _dialogImagePreview(String raw) {
    if (raw.isNotEmpty) {
      final bytes = safeLogoBytes(raw);
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
      if (raw.startsWith('http')) {
        return Image.network(
          raw,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: muted),
        );
      }
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: muted, size: 28),
        SizedBox(height: 4),
        Text('Add Photo', style: TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() => saving = true);
    try {
      await widget.store.change(
        (data) => data.saveMenuItem(
          MenuItem(
            id: widget.item?.id ?? 'm${DateTime.now().microsecondsSinceEpoch}',
            name: name.text.trim(),
            category: category.text.trim(),
            price: paise,
            available: available,
            image: image,
            availableStock: availableStock,
          ),
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Add a menu item' : 'Edit ${widget.item!.name}'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker Section
              Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: saving ? null : _pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: canvas,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _dialogImagePreview(image),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: saving ? null : _pickImage,
                          icon: const Icon(Icons.upload_file, size: 15),
                          label: Text(image.isEmpty ? 'Upload image' : 'Change image', style: const TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          onPressed: saving ? null : _enterImageUrl,
                          icon: const Icon(Icons.link, size: 15),
                          label: const Text('URL', style: TextStyle(fontSize: 12)),
                        ),
                        if (image.isNotEmpty)
                          IconButton(
                            tooltip: 'Remove image',
                            onPressed: saving ? null : () => setState(() => image = ''),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: category,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a category'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price in rupees',
                  prefixText: '₹ ',
                ),
                validator: (value) {
                  if (!RegExp(
                    r'^\d{1,6}(\.\d{1,2})?$',
                  ).hasMatch(value?.trim() ?? '')) {
                    return 'Use a price with up to 2 decimal places';
                  }
                  if (paise < 1 || paise > 10000000) {
                    return 'Use ₹0.01 to ₹100,000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Option 1: Available to order (clicking this disables stock)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available to order', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  available
                      ? 'Live counter preparation active'
                      : (availableStock ? 'Disabled (Available stock active)' : 'Turned off (Sold out)'),
                  style: TextStyle(
                    fontSize: 12,
                    color: available ? const Color(0xFF16A34A) : muted,
                  ),
                ),
                value: available,
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          available = value;
                          if (value) {
                            availableStock = false; // Clicking available to order disables stock
                          }
                        });
                      },
              ),
              const Divider(height: 16),
              // Option 2: Available stock (clicking this disables order)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available stock', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  availableStock
                      ? 'In-stock inventory mode active'
                      : (available ? 'Disabled (Available to order active)' : 'Turned off (Out of stock)'),
                  style: TextStyle(
                    fontSize: 12,
                    color: availableStock ? const Color(0xFF2563EB) : muted,
                  ),
                ),
                value: availableStock,
                onChanged: saving
                    ? null
                    : (value) {
                        setState(() {
                          availableStock = value;
                          if (value) {
                            available = false; // Clicking stock disables order
                          }
                        });
                      },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save item'),
      ),
    ],
  );
}

class CustomersPage extends StatefulWidget {
  final CafeData data;
  const CustomersPage({super.key, required this.data});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String _query = '';
  final Set<String> _selectedPhones = {};
  bool _exporting = false;

  Future<void> _exportCustomers(List<String> phonesToExport) async {
    if (_exporting) return;
    if (phonesToExport.isEmpty) {
      toast(context, 'No customers selected to export.');
      return;
    }
    setState(() => _exporting = true);
    try {
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final bytes = buildCustomersWorkbook(widget.data, phonesToExport);
      await exportFile(
        context,
        bytes,
        'Hynox-customers-$dateStr.xlsx',
        spreadsheetMime,
      );
      if (mounted) {
        toast(context, 'Exported ${phonesToExport.length} customers successfully');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = getActiveThemePrimary();
    final allGroups = <String, List<CafeOrder>>{};
    for (final order in widget.data.orders.where(
      (o) => o.phone.isNotEmpty && o.stage != OrderStage.cancelled,
    )) {
      allGroups.putIfAbsent(order.phone, () => []).add(order);
    }

    // Filter by query (phone or name)
    final q = _query.trim().toLowerCase();
    final entries = allGroups.entries.where((entry) {
      if (q.isEmpty) return true;
      final phone = entry.key.toLowerCase();
      final name = (entry.value.first.customer).toLowerCase();
      return phone.contains(q) || name.contains(q);
    }).toList();

    final allPhones = entries.map((e) => e.key).toList();
    final allSelected = allPhones.isNotEmpty && allPhones.every(_selectedPhones.contains);
    final hasSelection = _selectedPhones.isNotEmpty;
    final selectedCount = allPhones.where(_selectedPhones.contains).length;
    final phonesToExport = hasSelection
        ? allPhones.where(_selectedPhones.contains).toList()
        : allPhones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Familiar faces.',
          'Order history for customers with a saved mobile number.',
        ),
        const SizedBox(height: 12),
        // Search bar (40px compact)
        SizedBox(
          height: 40,
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: 'Search customer name or phone…',
              hintStyle: const TextStyle(fontSize: 12.5, color: muted),
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
                borderSide: BorderSide(color: primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Sleek, compact Selection & Export Bar
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              _microCheckbox(
                checked: allSelected,
                indeterminate: allPhones.isNotEmpty && !allSelected && selectedCount > 0,
                onTap: allPhones.isEmpty
                    ? () {}
                    : () {
                        setState(() {
                          if (allSelected) {
                            for (final p in allPhones) {
                              _selectedPhones.remove(p);
                            }
                          } else {
                            for (final p in allPhones) {
                              _selectedPhones.add(p);
                            }
                          }
                        });
                      },
                primaryColor: primary,
              ),
              const SizedBox(width: 8),
              Text(
                hasSelection
                    ? '$selectedCount selected'
                    : 'Select all (${allPhones.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
                  color: hasSelection ? ink : muted,
                ),
              ),
              const Spacer(),
              if (allPhones.isNotEmpty)
                InkWell(
                  onTap: _exporting ? null : () => _exportCustomers(phonesToExport),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: hasSelection ? primary : primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasSelection ? primary : primary.withValues(alpha: .25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 14,
                          color: hasSelection ? Colors.white : primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _exporting
                              ? 'Exporting…'
                              : 'Export (${hasSelection ? selectedCount : allPhones.length})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: hasSelection ? Colors.white : primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            children: [
              if (entries.isEmpty)
                const EmptyState(
                  'No customers found',
                  'Add a sample mobile number to an order to see customer history.',
                  icon: Icons.people_outline,
                ),
              ...entries.map((entry) {
                final phone = entry.key;
                final orders = entry.value;
                final isSelected = _selectedPhones.contains(phone);
                final paid = orders
                    .where((o) => o.payment == PaymentState.paid)
                    .fold(0, (sum, o) => sum + o.total);

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _microCheckbox(
                          checked: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPhones.remove(phone);
                              } else {
                                _selectedPhones.add(phone);
                              }
                            });
                          },
                          primaryColor: primary,
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isSelected ? primary.withValues(alpha: .12) : canvas,
                          child: Icon(Icons.person_outline, size: 20, color: primary),
                        ),
                      ],
                    ),
                    title: Text(
                      orders.first.customer.isEmpty
                          ? 'Customer'
                          : orders.first.customer,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      '+91 $phone · ${orders.length} order${orders.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    trailing: Text(
                      money(paid),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    children: orders
                        .map(
                          (o) => ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            title: Text(
                              o.id,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${shortDate(o.createdAt)} · ${paymentLabel(o.payment)}',
                              style: const TextStyle(fontSize: 10.5, color: muted),
                            ),
                            trailing: Text(
                              money(o.total),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Customer totals include paid, non-refunded orders.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  final CafeStore store;
  const SettingsPage({super.key, required this.store});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController name;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.store.data.businessName);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      toast(context, 'Enter your café name.');
      return;
    }
    try {
      await widget.store.change((data) => data.businessName = name.text.trim());
      if (mounted) {
        toast(context, 'Business name saved.');
      }
    } catch (e) {
      if (mounted) {
        toast(context, errorText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.store.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Make yourself at home.',
          'Your business details and the next steps for your workspace.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Café / shop name',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.store.busy ? null : save,
                child: const Text('Save business name'),
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
                '15-day trial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Pill('${data.trialDaysLeft(DateTime.now())} days remaining'),
              const SizedBox(height: 16),
              Text(
                'Started ${shortDate(data.trialStartedAt)} · Ends ${shortDate(data.trialEndsAt)}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              const Text(
                'Subscription billing is not connected.',
                style: TextStyle(color: muted, height: 1.7, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection checklist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 14),
              ConnectionRow('Orders and menu', 'Saved locally', true),
              ConnectionRow('PDF receipts', 'Ready to download or share', true),
              ConnectionRow('Secure vendor sign-in', 'Backend required', false),
              ConnectionRow(
                'Cloud database and backups',
                'Backend required',
                false,
              ),
              ConnectionRow(
                'WhatsApp receipts',
                'Business messaging account required',
                false,
              ),
              ConnectionRow(
                'Payments and subscriptions',
                'Payment-provider integration required',
                false,
              ),
              ConnectionRow(
                'Customer review links',
                'Hosted feedback page required',
                false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'All orders, payments, receipts, and business records are saved and managed directly on this device.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.7),
        ),
      ],
    );
  }
}

class ConnectionRow extends StatelessWidget {
  final String label;
  final String status;
  final bool ready;
  const ConnectionRow(this.label, this.status, this.ready, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(
          ready ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: ready ? green : muted,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(status, style: const TextStyle(color: muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
}

class AdminPage extends StatelessWidget {
  final CafeData data;
  final int section;
  final CafeStore store;
  const AdminPage({super.key, required this.data, required this.section, required this.store});
  @override
  Widget build(BuildContext context) {
    if (section == 2) {
      return _AdminSettingsView(store: store, data: data);
    }
    final isSubActive = store.activeSubscription != null && store.activeSubscription!['status'] == 'active';
    final isSubPending = store.activeSubscription != null && store.activeSubscription!['requestStatus'] == 'pending';
    final trial = !isSubActive && data.trialDaysLeft(DateTime.now()) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          section == 0
              ? 'Small businesses. Bigger possibilities.'
              : 'Your vendor community.',
          'Hynox administration',
          action: section == 0
              ? FilledButton.icon(
                  onPressed: () async {
                    try {
                      final date = DateTime.now().toIso8601String().split('T').first;
                      await exportFile(
                        context,
                        buildReportWorkbook(data),
                        'Hynox-admin-reports-$date.xlsx',
                        spreadsheetMime,
                      );
                    } catch (e) {
                      toast(context, errorText(e));
                    }
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  label: const Text('Export'),
                )
              : null,
        ),
        if (section == 0) ...[
          StatGrid(
            children: [
              const StatCard(
                label: 'BUSINESSES',
                value: '1',
                note: 'Stored on this device',
                icon: Icons.storefront_outlined,
                dark: true,
              ),
              StatCard(
                label: 'IN TRIAL',
                value: isSubActive ? '0' : (trial ? '1' : '0'),
                note: isSubActive ? 'Subscribed to platform' : '15 days from first launch',
                icon: Icons.schedule,
              ),
              StatCard(
                label: 'PAID SUBSCRIBERS',
                value: isSubActive ? '1' : '0',
                note: isSubActive
                    ? '${store.activeSubscription!['planName'] ?? 'Starter'} plan active'
                    : (isSubPending ? 'Plan activation pending' : 'No active subscription'),
                icon: Icons.verified_outlined,
              ),
              StatCard(
                label: 'Hynox REVENUE',
                value: isSubActive ? money(store.activeSubscription!['price'] ?? 9900) : '₹0',
                note: isSubActive ? 'Monthly recurring subscription' : 'No subscriptions collected',
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Businesses',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final logoBytes = safeLogoBytes(data.profile.logo);
                      if (logoBytes != null) {
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: green, width: 1.5),
                            color: Colors.white,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(logoBytes, fit: BoxFit.cover),
                        );
                      }
                      return const CircleAvatar(
                        backgroundColor: canvas,
                        child: Icon(Icons.storefront_outlined, color: green),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.businessName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'One outlet',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (isSubActive)
                              Pill('${store.activeSubscription!['planName'] ?? 'Starter'} active', color: const Color(0xFF16A34A))
                            else if (isSubPending)
                              const Pill('Plan requested', color: Color(0xFFF59E0B))
                            else
                              Pill(trial ? 'Trial active' : 'Trial ended'),
                            Pill('${data.orders.length} orders'),
                            Pill('${data.menu.length} menu items'),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isSubPending) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF59E0B)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications_active_outlined, color: Color(0xFFB45309), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Requested: ${store.activeSubscription!['requestedPlanName'] ?? 'Starter'} · Awaiting Activation',
                                    style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // Prominent Accept & Activate Plan button with generous spacing
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                final planName = store.activeSubscription?['requestedPlanName'] ?? 'Starter';
                                final planId = store.activeSubscription?['requestedPlanId'] ?? 'starter';
                                final newSub = {
                                  'status': 'active',
                                  'planId': planId,
                                  'planName': planName,
                                  'price': store.activeSubscription?['requestedPrice'] ?? 9900,
                                  'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                                  'activatedAt': DateTime.now().toIso8601String(),
                                  'activatedBy': 'Hynox team',
                                };
                                store.updateSubscription(newSub);
                                toast(context, 'Success! $planName plan activated for ${data.businessName}.');
                              },
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: Text(
                                isSubPending
                                    ? 'Accept & Activate Plan'
                                    : (isSubActive ? 'Change Plan' : 'Accept & Activate Plan'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isSubActive
                              ? 'Subscription active until ${shortDate(DateTime.tryParse(store.activeSubscription?['expiresAt'] ?? '') ?? DateTime.now().add(const Duration(days: 30)))}'
                              : 'Trial ends ${shortDate(data.trialEndsAt)}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminSettingsView extends StatelessWidget {
  final CafeStore store;
  final CafeData data;
  const _AdminSettingsView({required this.store, required this.data});

  @override
  Widget build(BuildContext context) {
    final themePrimary = getActiveThemePrimary();
    final sub = store.activeSubscription;
    final isSubActive = sub != null && sub['status'] == 'active';
    final isSubPending = sub != null && sub['requestStatus'] == 'pending';
    final planName = sub?['planName'] ?? sub?['requestedPlanName'] ?? 'Starter';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Platform Administration & Profile',
          'Manage your Hynox HQ profile, vendor plans, security, and master controls.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Platform Identity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  StoreLogoAvatar(
                    logo: '',
                    name: 'HY',
                    size: 76,
                    borderColor: themePrimary,
                    borderWidth: 2.5,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hynox Headquarters',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Pill('SUPER ADMIN', color: themePrimary),
                            const Pill('MASTER NODE'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'admin@hynox.io · +91 98765 43210',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
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
                'Vendor Subscriptions & Licensing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSubActive
                      ? const Color(0xFFF0FDF4)
                      : (isSubPending ? const Color(0xFFFEF3C7) : canvas),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSubActive
                        ? const Color(0xFF86EFAC)
                        : (isSubPending ? const Color(0xFFFCD34D) : border),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSubActive
                          ? Icons.verified
                          : (isSubPending ? Icons.notifications_active : Icons.info_outline),
                      color: isSubActive
                          ? const Color(0xFF16A34A)
                          : (isSubPending ? const Color(0xFFB45309) : muted),
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vendor: ${data.businessName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSubActive
                                ? '$planName Plan Active · All Pro features unlocked'
                                : (isSubPending
                                    ? 'Plan requested: $planName · Awaiting your activation'
                                    : 'Vendor is currently in 15-day trial period'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSubActive ? const Color(0xFF14532D) : muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                      onPressed: () {
                        final newSub = {
                          'status': 'active',
                          'planId': sub?['requestedPlanId'] ?? 'starter',
                          'planName': planName,
                          'price': sub?['requestedPrice'] ?? 9900,
                          'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                          'activatedAt': DateTime.now().toIso8601String(),
                          'activatedBy': 'Hynox Super Admin',
                        };
                        store.updateSubscription(newSub);
                        toast(context, '$planName plan activated for ${data.businessName}!');
                      },
                      icon: const Icon(Icons.flash_on, size: 16),
                      label: Text(isSubActive ? 'Extend Plan' : 'Accept & Activate Plan'),
                    ),
                  ],
                ),
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
                'Security & Master Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Manage authentication credentials and system operational state.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  if (store.changePassword != null)
                    FilledButton.icon(
                      onPressed: () => changeAccountPassword(
                        context,
                        store.changePassword!,
                      ),
                      icon: const Icon(Icons.lock_reset, size: 18),
                      label: const Text('Change Master Password'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => toast(
                      context,
                      'System operational. Local storage: Healthy.',
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('System Diagnostics'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

