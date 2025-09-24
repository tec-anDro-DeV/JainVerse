import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class CustomDatePicker extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Function(DateTime) onDateSelected;
  final String dateFormat;
  final Color primaryColor;
  final Color backgroundColor;
  final String title;
  final bool showTitle;
  final String confirmText;
  final String cancelText;
  final double elevation;
  final BorderRadius? borderRadius;
  final String hintText;
  final int? minimumAge;

  const CustomDatePicker({
    super.key,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    required this.onDateSelected,
    this.dateFormat = 'yyyy-MM-dd',
    this.primaryColor = const Color(0xFFEE5533),
    this.backgroundColor = Colors.white,
    this.title = 'Select Date',
    this.showTitle = true,
    this.confirmText = 'OK',
    this.cancelText = 'CANCEL',
    this.elevation = 0,
    this.borderRadius,
    this.hintText = 'Select date',
    this.minimumAge,
  });

  DateTime _calculateMaxAllowedDate() {
    if (minimumAge == null) return lastDate ?? DateTime.now();

    final DateTime today = DateTime.now();
    final DateTime maxAllowedDate = DateTime(
      today.year - minimumAge!,
      today.month,
      today.day,
    );

    if (lastDate != null && lastDate!.isBefore(maxAllowedDate)) {
      return lastDate!;
    }

    return maxAllowedDate;
  }

  static Future<DateTime?> showPicker(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    required Function(DateTime) onDateSelected,
    String dateFormat = 'yyyy-MM-dd',
    Color primaryColor = const Color(0xFFEE5533),
    Color backgroundColor = Colors.white,
    String title = 'Select Date',
    bool showTitle = true,
    String confirmText = 'OK',
    String cancelText = 'CANCEL',
    int? minimumAge,
  }) async {
    DateTime effectiveLastDate;
    if (minimumAge != null) {
      final DateTime today = DateTime.now();
      final DateTime maxAllowedDate = DateTime(
        today.year - minimumAge,
        today.month,
        today.day,
      );

      if (lastDate != null && lastDate.isBefore(maxAllowedDate)) {
        effectiveLastDate = lastDate;
      } else {
        effectiveLastDate = maxAllowedDate;
      }
    } else {
      effectiveLastDate = lastDate ?? DateTime.now();
    }

    DateTime effectiveInitialDate = initialDate ?? DateTime.now();
    if (effectiveInitialDate.isAfter(effectiveLastDate)) {
      effectiveInitialDate = effectiveLastDate;
    }

    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return InteractiveDatePickerDialog(
          initialDate: effectiveInitialDate,
          firstDate: firstDate ?? DateTime(1900),
          lastDate: effectiveLastDate,
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
          title: title,
          confirmText: confirmText,
          cancelText: cancelText,
        );
      },
    );
  }

  @override
  State<CustomDatePicker> createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  late DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        widget.borderRadius ?? BorderRadius.circular(16.r);
    final DateTime effectiveLastDate = widget._calculateMaxAllowedDate();

    return SizedBox(
      height: 70.w,
      child: Material(
        color: widget.backgroundColor,
        child: InkWell(
          onTap: () async {
            DateTime effectiveInitialDate = _selectedDate ?? DateTime.now();
            if (effectiveInitialDate.isAfter(effectiveLastDate)) {
              effectiveInitialDate = effectiveLastDate;
            }

            final result = await CustomDatePicker.showPicker(
              context,
              initialDate: effectiveInitialDate,
              firstDate: widget.firstDate ?? DateTime(1900),
              lastDate: effectiveLastDate,
              onDateSelected: widget.onDateSelected,
              dateFormat: widget.dateFormat,
              primaryColor: widget.primaryColor,
              backgroundColor: widget.backgroundColor,
              title: widget.title,
              showTitle: widget.showTitle,
              confirmText: widget.confirmText,
              cancelText: widget.cancelText,
              minimumAge: widget.minimumAge,
            );

            if (result != null) {
              print(
                "Date selected in CustomDatePicker: $result",
              ); // Debug print
              setState(() {
                _selectedDate = result;
              });
              // Call the parent callback to update the parent state
              widget.onDateSelected(result);
            }
          },
          borderRadius: effectiveBorderRadius,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: effectiveBorderRadius,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.w,
              ), // Already small, keeping same
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 0,
            ), // Increased from 16.w
            child: Row(
              children: [
                // Calendar icon
                Icon(
                  Icons.calendar_today_outlined,
                  size: 22.sp,
                  color: Colors.grey.shade600,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 15.w), // Increased from 12.w
                    child: Text(
                      _selectedDate != null
                          ? DateFormat(widget.dateFormat).format(_selectedDate!)
                          : widget.hintText,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color:
                            _selectedDate != null
                                ? Colors.black87
                                : Colors.grey.shade400,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InteractiveDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color primaryColor;
  final Color backgroundColor;
  final String title;
  final String confirmText;
  final String cancelText;

  const InteractiveDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.primaryColor,
    required this.backgroundColor,
    required this.title,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  State<InteractiveDatePickerDialog> createState() =>
      _InteractiveDatePickerDialogState();
}

class _InteractiveDatePickerDialogState
    extends State<InteractiveDatePickerDialog> {
  late DateTime _selectedDate;
  late TextEditingController _dayController;
  late TextEditingController _monthController;
  late TextEditingController _yearController;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _dayController = TextEditingController(text: _selectedDate.day.toString());
    _monthController = TextEditingController(
      text: _months[_selectedDate.month - 1],
    );
    _yearController = TextEditingController(
      text: _selectedDate.year.toString(),
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateDate() {
    try {
      final int day = int.parse(_dayController.text);
      final int month = _months.indexOf(_monthController.text) + 1;
      final int year = int.parse(_yearController.text);

      final DateTime newDate = DateTime(year, month, day);

      if (newDate.isAfter(widget.lastDate) ||
          newDate.isBefore(widget.firstDate)) {
        return;
      }

      setState(() {
        _selectedDate = newDate;
      });
    } catch (e) {
      // Invalid date input
    }
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder:
          (context) => YearPickerDialog(
            initialYear: _selectedDate.year,
            firstYear: widget.firstDate.year,
            lastYear: widget.lastDate.year,
            primaryColor: widget.primaryColor,
            onYearSelected: (year) {
              _yearController.text = year.toString();
              _updateDate();
            },
          ),
    );
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder:
          (context) => MonthPickerDialog(
            initialMonth: _selectedDate.month,
            primaryColor: widget.primaryColor,
            onMonthSelected: (month) {
              _monthController.text = _months[month - 1];
              _updateDate();
            },
          ),
    );
  }

  void _showDayPicker() {
    final int daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    showDialog(
      context: context,
      builder:
          (context) => DayPickerDialog(
            initialDay: _selectedDate.day,
            daysInMonth: daysInMonth,
            primaryColor: widget.primaryColor,
            onDaySelected: (day) {
              _dayController.text = day.toString();
              _updateDate();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
      child: Padding(
        padding: EdgeInsets.all(30.w), // Increased from 24.w
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: widget.primaryColor,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 30.w), // Increased from 24.w
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _showMonthPicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12.w,
                        horizontal: 8.w,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _monthController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontFamily: 'Poppins',
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w), // Increased from 8.w
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: _showDayPicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 15.w, // Increased from 12.w
                        horizontal: 10.w, // Increased from 8.w
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _dayController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontFamily: 'Poppins',
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w), // Increased from 8.w
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _showYearPicker,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 15.w, // Increased from 12.w
                        horizontal: 10.w, // Increased from 8.w
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        _yearController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontFamily: 'Poppins',
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30.w), // Increased from 24.w
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 16.sp,
                fontFamily: 'Poppins',
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 24.w),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    widget.cancelText,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    widget.confirmText,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
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

class YearPickerDialog extends StatelessWidget {
  final int initialYear;
  final int firstYear;
  final int lastYear;
  final Color primaryColor;
  final Function(int) onYearSelected;

  const YearPickerDialog({
    super.key,
    required this.initialYear,
    required this.firstYear,
    required this.lastYear,
    required this.primaryColor,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: 400.w,
        width: 300.w,
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              'Select Year',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: primaryColor,
              ),
            ),
            SizedBox(height: 16.w),
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: lastYear - firstYear + 1,
                itemBuilder: (context, index) {
                  final year = lastYear - index;
                  final isSelected = year == initialYear;
                  return ListTile(
                    title: Text(
                      year.toString(),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? primaryColor : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: primaryColor.withOpacity(0.1),
                    onTap: () {
                      onYearSelected(year);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthPickerDialog extends StatelessWidget {
  final int initialMonth;
  final Color primaryColor;
  final Function(int) onMonthSelected;

  const MonthPickerDialog({
    super.key,
    required this.initialMonth,
    required this.primaryColor,
    required this.onMonthSelected,
  });

  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: 400.w,
        width: 300.w,
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              'Select Month',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: primaryColor,
              ),
            ),
            SizedBox(height: 16.w),
            Expanded(
              child: ListView.builder(
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == initialMonth;
                  return ListTile(
                    title: Text(
                      _months[index],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? primaryColor : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: primaryColor.withOpacity(0.1),
                    onTap: () {
                      onMonthSelected(month);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DayPickerDialog extends StatelessWidget {
  final int initialDay;
  final int daysInMonth;
  final Color primaryColor;
  final Function(int) onDaySelected;

  const DayPickerDialog({
    super.key,
    required this.initialDay,
    required this.daysInMonth,
    required this.primaryColor,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: 400.w,
        width: 300.w,
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              'Select Day',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: primaryColor,
              ),
            ),
            SizedBox(height: 16.w),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 4.w,
                  mainAxisSpacing: 4.w,
                ),
                itemCount: daysInMonth,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  final isSelected = day == initialDay;
                  return GestureDetector(
                    onTap: () {
                      onDaySelected(day);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color:
                              isSelected ? primaryColor : Colors.grey.shade300,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Example usage with age restriction:
// CustomDatePicker(
//   initialDate: DateTime.now().subtract(Duration(days: 365 * 20)), // 20 years ago
//   minimumAge: 13, // Only allow 13+ years old
//   onDateSelected: (date) {
//     print("Selected date: $date");
//   },
// )

// Or as a dialog with age restriction:
// CustomDatePicker.showPicker(
//   context,
//   minimumAge: 13, // Only allow 13+ years old
//   onDateSelected: (date) {
//     print("Selected date: $date");
//   },
// );
