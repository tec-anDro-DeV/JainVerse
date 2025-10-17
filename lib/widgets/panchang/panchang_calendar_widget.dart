import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/services/panchang_service.dart';

class PanchangCalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final double latitude;
  final double longitude;
  final double timezone;

  const PanchangCalendarWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.latitude = 23.033863, // India center
    this.longitude = 72.585022,
    this.timezone = 5.5, // IST
  });

  @override
  State<PanchangCalendarWidget> createState() => _PanchangCalendarWidgetState();
}

class _PanchangCalendarWidgetState extends State<PanchangCalendarWidget> {
  late DateTime displayedMonth;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    displayedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      1,
    );
    _pageController = PageController(initialPage: 0);
  }

  @override
  void didUpdateWidget(covariant PanchangCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the parent selectedDate changed (for example when tapping "Today"
    // in the parent), update the displayed month so the calendar shows the
    // correct month. We only update when the month or year differs to avoid
    // resetting state unnecessarily.
    if (widget.selectedDate.year != oldWidget.selectedDate.year ||
        widget.selectedDate.month != oldWidget.selectedDate.month) {
      setState(() {
        displayedMonth = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          1,
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      displayedMonth = DateTime(
        displayedMonth.year,
        displayedMonth.month + 1,
        1,
      );
    });
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;

    List<DateTime> days = [];

    // Add previous month's trailing days
    final firstWeekday = firstDay.weekday;
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final daysInPreviousMonth = DateTime(month.year, month.month, 0).day;

    for (int i = firstWeekday - 1; i > 0; i--) {
      days.add(
        DateTime(
          previousMonth.year,
          previousMonth.month,
          daysInPreviousMonth - i + 1,
        ),
      );
    }

    // Add current month's days
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    // Add next month's leading days
    final remainingDays = 42 - days.length; // 6 weeks * 7 days
    for (int i = 1; i <= remainingDays; i++) {
      days.add(DateTime(month.year, month.month + 1, i));
    }

    return days;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return date.year == widget.selectedDate.year &&
        date.month == widget.selectedDate.month &&
        date.day == widget.selectedDate.day;
  }

  bool _isCurrentMonth(DateTime date) {
    return date.month == displayedMonth.month;
  }

  /// Get Tithi data for a specific date
  /// Returns a map with keys: 'name' (String) and 'number' (int)
  Map<String, dynamic>? _getTithiForDate(DateTime date) {
    try {
      // Normalize to midnight for consistent calculations
      final normalizedDate = DateTime(date.year, date.month, date.day);

      final panchangService = PanchangService(
        date: normalizedDate,
        latitude: widget.latitude,
        longitude: widget.longitude,
        timezone: widget.timezone,
      );

      final tithiData = panchangService.getTithi();
      return {'name': tithiData['name'] ?? '', 'number': tithiData['number']};
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors();
    final days = _getDaysInMonth(displayedMonth);

    return Container(
      margin: EdgeInsets.all(12.w),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: colors.white[50],
        border: Border.all(color: colors.primaryColorApp),
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [
          BoxShadow(
            color: colors.gray[300]!.withOpacity(0.5),
            blurRadius: 15.w,
            offset: Offset(0.w, 5.w),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month and year header with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: colors.primaryColorApp[50],
                ),
                onPressed: _previousMonth,
              ),
              Text(
                DateFormat('MMMM yyyy').format(displayedMonth),
                style: TextStyle(
                  color: colors.colorText[50],
                  fontSize: 18.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: colors.primaryColorApp[50],
                ),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: colors.gray[600],
                              fontSize: 12.w,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final isToday = _isToday(date);
              final isSelected = _isSelected(date);
              final isCurrentMonth = _isCurrentMonth(date);
              final tithi = _getTithiForDate(date);

              return GestureDetector(
                onTap: () => widget.onDateSelected(date),
                child: Container(
                  // Make each cell fill the grid cell with no inner padding
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colors.primaryColorApp[50]
                            : isToday
                            ? colors.primaryColorApp[50]!.withOpacity(0.2)
                            : Colors.transparent,
                    // Remove rounded corners so borders meet cleanly
                    borderRadius: BorderRadius.zero,
                    // Add thin internal border for contiguous grid look
                    border: Border.all(
                      color: appColors().primaryColorApp.withOpacity(0.5),
                      width: 0.5.w,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color:
                                isSelected
                                    ? colors.white[50]
                                    : isCurrentMonth
                                    ? colors.colorText[50]
                                    : colors.gray[400],
                            fontSize: 14.w,
                            fontWeight:
                                isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        if (tithi != null &&
                            tithi['name'] != null &&
                            tithi['name'].toString().isNotEmpty &&
                            isCurrentMonth)
                          Padding(
                            padding: EdgeInsets.only(top: 2.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tithi['name'].toString(),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? colors.white[50]!.withOpacity(0.8)
                                            : colors.primaryColorApp[50],
                                    fontSize: 10.w,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                if (tithi['number'] != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 1.w),
                                    child: Builder(
                                      builder: (context) {
                                        // Show tithi number within the paksha (1..15)
                                        final numVal =
                                            tithi['number'] is int
                                                ? tithi['number'] as int
                                                : int.tryParse(
                                                      tithi['number']
                                                          .toString(),
                                                    ) ??
                                                    0;
                                        final displayNumber =
                                            (numVal > 15)
                                                ? (numVal - 15)
                                                : numVal;
                                        return Text(
                                          displayNumber > 0
                                              ? displayNumber.toString()
                                              : '',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 9.w,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
