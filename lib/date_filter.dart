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

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: getActiveThemePrimary(),
            ),
          ),
          child: child!,
        );
      },
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
