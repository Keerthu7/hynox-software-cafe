import 'package:flutter/material.dart';
import 'domain.dart';
import 'ui.dart';
import 'report_export.dart';
import 'date_filter.dart';

class ReportsPage extends StatefulWidget {
  final CafeData data;
  const ReportsPage({super.key, required this.data});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateRangeFilter _dateFilter = DateRangeFilter.last7Days();
  bool exporting = false;

  Future<void> exportReports() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final filteredOrders = widget.data.orders
          .where((o) => _dateFilter.matches(o.paidAt ?? o.createdAt))
          .toList();
      final data = CafeData(
        businessName: widget.data.businessName,
        trialStartedAt: widget.data.trialStartedAt,
        menu: widget.data.menu,
        orders: filteredOrders,
        profile: widget.data.profile,
      );
      final date = DateTime.now().toIso8601String().split('T').first;
      await exportFile(
        context,
        buildReportWorkbook(data),
        'Hynox-reports-$date.xlsx',
        spreadsheetMime,
      );
      if (mounted) {
        toast(
          context,
          'Report exported for ${_dateFilter.label} (${filteredOrders.length} orders)',
        );
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = widget.data.orders
        .where((o) => o.paidAt != null && _dateFilter.matches(o.paidAt))
        .toList();
    final refunds = widget.data.orders
        .where((o) => o.refundedAt != null && _dateFilter.matches(o.refundedAt))
        .fold(0, (sum, o) => sum + o.total);
    final gross = paid.fold(0, (sum, o) => sum + o.total);
    final items = <String, int>{};
    for (final o in paid) {
      for (final line in o.lines) {
        items.update(
          line.name,
          (n) => n + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
    }
    final ranked = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'Business reports',
          'Real totals from your saved orders and recorded payments.',
          action: FilledButton.icon(
            onPressed: exporting ? null : exportReports,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(
              exporting ? 'Exporting…' : 'Export Excel',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        DateFilterBar(
          selected: _dateFilter,
          onChanged: (f) => setState(() => _dateFilter = f),
          includeAllTime: true,
        ),
        const SizedBox(height: 24),
        StatGrid(
          children: [
            StatCard(
              label: 'GROSS COLLECTED (${_dateFilter.label.toUpperCase()})',
              value: money(gross),
              note: 'Payments recorded in this period',
              icon: Icons.payments_outlined,
              dark: true,
            ),
            StatCard(
              label: 'REFUNDS (${_dateFilter.label.toUpperCase()})',
              value: money(refunds),
              note: 'Refunds recorded in this period',
              icon: Icons.undo,
            ),
            StatCard(
              label: 'NET COLLECTED (${_dateFilter.label.toUpperCase()})',
              value: money(gross - refunds),
              note: 'Collections less refunds',
              icon: Icons.account_balance_wallet_outlined,
            ),
            StatCard(
              label: 'PAYMENTS (${_dateFilter.label.toUpperCase()})',
              value: '${paid.length}',
              note: 'Successful payment records',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment breakdown (${_dateFilter.label})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              for (final method in ['Cash', 'UPI', 'Card'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Text(method)),
                      Text(
                        money(
                          paid
                              .where((o) => o.paymentMethod == method)
                              .fold(0, (sum, o) => sum + o.total),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Products sold (${_dateFilter.label})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gross units on paid bills in the period, before returns.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              if (ranked.isEmpty)
                const EmptyState(
                  'No paid bills in this period',
                  'Record a payment in this date range to populate this report.',
                ),
              for (final item in ranked)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.key),
                  trailing: Pill('${item.value} sold'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
