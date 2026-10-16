import 'package:flutter/material.dart';
import 'domain.dart';
import 'ui.dart';

enum DateFilterPreset {
  today,
  yesterday,
  last7Days,
  thisMonth,
  allTime,
  custom,
}

class DateRangeFilter {
  final DateFilterPreset preset;
  final DateTime start;
  final DateTime end;
  final String label;

  const DateRangeFilter({
    required this.preset,
    required this.start,
    required this.end,
    required this.label,
  });

  bool matches(DateTime? date) {
    if (date == null) return false;
    return !date.isBefore(start) && !date.isAfter(end);
  }

  static DateRangeFilter today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return DateRangeFilter(
      preset: DateFilterPreset.today,
      start: start,
      end: end,
      label: 'Today',
    );
  }

  static DateRangeFilter yesterday() {
    final now = DateTime.now();
    final y = now.subtract(const Duration(days: 1));
    final start = DateTime(y.year, y.month, y.day);
    final end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
    return DateRangeFilter(
      preset: DateFilterPreset.yesterday,
      start: start,
      end: end,
      label: 'Yesterday',
    );
  }

  static DateRangeFilter last7Days() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return DateRangeFilter(
      preset: DateFilterPreset.last7Days,
      start: start,
      end: end,
      label: 'Last 7 Days',
    );
  }

  static DateRangeFilter thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return DateRangeFilter(
      preset: DateFilterPreset.thisMonth,
      start: start,
      end: end,
      label: 'This Month',
    );
  }

  static DateRangeFilter allTime() {
    return DateRangeFilter(
      preset: DateFilterPreset.allTime,
      start: DateTime(2020),
      end: DateTime(2100),
      label: 'All Time',
    );
  }

  static DateRangeFilter custom(DateTime start, DateTime end) {
    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    return DateRangeFilter(
      preset: DateFilterPreset.custom,
      start: cleanStart,
      end: cleanEnd,
      label: '${shortDate(start)} – ${shortDate(end)}',
    );
  }
}

class DateFilterBar extends StatelessWidget {
  final DateRangeFilter selected;
  final ValueChanged<DateRangeFilter> onChanged;
  final bool includeAllTime;

  const DateFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.includeAllTime = true,
  });

  Future<void> _pickCustomRange(BuildContext context) async {
    final initialDateRange = DateTimeRange(
      start: selected.preset == DateFilterPreset.custom
          ? selected.start
          : DateTime.now().subtract(const Duration(days: 7)),
      end: selected.preset == DateFilterPreset.custom
          ? selected.end
          : DateTime.now(),
    );

    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) => _CustomDateRangeDialog(
        initialRange: initialDateRange,
      ),
    );

    if (picked != null) {
      onChanged(DateRangeFilter.custom(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = getActiveThemePrimary();
    final presets = [
      (preset: DateFilterPreset.today, label: 'Today', filter: DateRangeFilter.today()),
      (preset: DateFilterPreset.yesterday, label: 'Yesterday', filter: DateRangeFilter.yesterday()),
      (preset: DateFilterPreset.last7Days, label: 'Last 7 Days', filter: DateRangeFilter.last7Days()),
      (preset: DateFilterPreset.thisMonth, label: 'This Month', filter: DateRangeFilter.thisMonth()),
      if (includeAllTime)
        (preset: DateFilterPreset.allTime, label: 'All Time', filter: DateRangeFilter.allTime()),
    ];

    final isCustom = selected.preset == DateFilterPreset.custom;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          // Sleek Custom Range Capsule
          InkWell(
            onTap: () => _pickCustomRange(context),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCustom ? primary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCustom ? primary : const Color(0xFFD1D5DB),
                  width: 1.2,
                ),
                boxShadow: isCustom
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: isCustom ? Colors.white : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isCustom ? selected.label : 'Custom',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCustom ? FontWeight.w700 : FontWeight.w600,
                      color: isCustom ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          for (final p in presets) ...[
            Builder(
              builder: (context) {
                final isSelected = selected.preset == p.preset;
                return InkWell(
                  onTap: () => onChanged(p.filter),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? primary : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CustomDateRangeDialog extends StatefulWidget {
  final DateTimeRange initialRange;
  const _CustomDateRangeDialog({required this.initialRange});

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange.start;
    _endDate = widget.initialRange.end;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: getActiveThemePrimary(),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: getActiveThemePrimary(),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _applyPreset(int days) {
    final now = DateTime.now();
    setState(() {
      _startDate = now.subtract(Duration(days: days));
      _endDate = now;
    });
  }

  void _applyMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = getActiveThemePrimary();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Row(
        children: [
          Icon(Icons.calendar_month_outlined, color: primary, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Custom Date Range',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20, color: muted),
            visualDensity: VisualDensity.compact,
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
              'QUICK SELECT',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip('Last 7 Days', () => _applyPreset(6)),
                _chip('Last 14 Days', () => _applyPreset(13)),
                _chip('Last 30 Days', () => _applyPreset(29)),
                _chip('This Month', _applyMonth),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'DATE RANGE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dateBox(
                    label: 'From Date',
                    date: _startDate,
                    onTap: _selectStartDate,
                    primary: primary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: muted),
                ),
                Expanded(
                  child: _dateBox(
                    label: 'To Date',
                    date: _endDate,
                    onTap: _selectEndDate,
                    primary: primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(
              context,
              DateTimeRange(start: _startDate, end: _endDate),
            );
          },
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Apply Range', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: muted),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    shortDate(date),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
