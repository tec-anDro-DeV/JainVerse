import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
// removed unused dart:math import; rotation uses RotationTransition instead
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/app_padding.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/panchang_service.dart';
import 'package:jainverse/widgets/panchang/panchang_calendar_widget.dart';

class PanchangCalendarScreen extends StatefulWidget {
  const PanchangCalendarScreen({super.key});

  @override
  State<PanchangCalendarScreen> createState() => _PanchangCalendarScreenState();
}

class _PanchangCalendarScreenState extends State<PanchangCalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime selectedDate;
  late PanchangService panchangService;
  Map<String, dynamic>? panchangData;
  bool isLoading = true;
  AudioHandler? _audioHandler;

  // Key to access calendar state so we can programmatically change the
  // displayed month even when the selected date hasn't changed.
  final GlobalKey _calendarKey = GlobalKey();

  // Scroll detection
  late ScrollController _scrollController;
  bool _isCompact = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  // track drag distance (vertical) for intentional expand gesture
  double _verticalDragDistance = 0.0;
  // Guard to avoid double-handling of tap when using onTapDown
  bool _didExpandFromTapDown = false;

  // Default location - India (can be made customizable)
  double latitude = 23.0225;
  double longitude = 72.5714;
  double timezone = 5.5;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    _audioHandler = const MyApp().called();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _loadPanchangData();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final offset = _scrollController.offset;
      // Only auto-collapse into compact mode when user scrolls down far enough.
      // Do NOT auto-expand when user scrolls up slightly — expansion should
      // be explicit (tap) or a deliberate upward drag. This avoids the
      // annoying behavior where trying to scroll content back up immediately
      // re-opens the full calendar.
      const collapseThreshold = 120.0;
      if (offset > collapseThreshold && !_isCompact) {
        setState(() {
          _isCompact = true;
          _animationController.forward();
        });
      }
    }
  }

  void _toggleCalendarView() {
    setState(() {
      _isCompact = !_isCompact;
      if (_isCompact) {
        _animationController.forward();
      } else {
        _animationController.reverse();
        // NOTE: remove automatic scroll-to-top so taps open the calendar
        // immediately and are not intercepted by a scroll animation.
      }
    });
  }

  void _loadPanchangData() {
    setState(() {
      isLoading = true;
    });

    panchangService = PanchangService(
      date: selectedDate,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );

    panchangData = panchangService.getPanchang();

    setState(() {
      isLoading = false;
    });
  }

  void _selectDate(DateTime date) {
    // Avoid redundant reload when the same date is selected. If caller
    // needs the calendar UI to jump to a different month while the
    // selection is already the same date, use the calendar key to call
    // `showMonth` directly (done by the "Today" handler below).
    if (date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day) {
      return;
    }

    setState(() {
      selectedDate = date;
    });

    _loadPanchangData();
  }

  void _changeDay(int days) {
    final newDate = selectedDate.add(Duration(days: days));
    _selectDate(newDate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Returns the active Choghadiya label for today (or null if none).
  /// Uses `panchangData['choghadiya']` which contains `day` and `night`
  /// slot lists with `start` and `end` times in "hh:mm AM/PM" format.
  String? _getActiveChoghadiyaForToday() {
    if (panchangData == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    if (sel != today) return null; // only for today's date

    final choghadiya = panchangData!['choghadiya'];
    if (choghadiya == null) return null;

    List<dynamic> daySlots = List<dynamic>.from(choghadiya['day'] ?? []);
    List<dynamic> nightSlots = List<dynamic>.from(choghadiya['night'] ?? []);

    DateTime _parse(String timeStr, DateTime baseDate) {
      try {
        final parts = timeStr.split(' ');
        final hm = parts[0].split(':');
        int hour = int.parse(hm[0]);
        final minute = int.parse(hm[1]);
        final period = parts.length > 1 ? parts[1] : 'AM';
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          hour,
          minute,
        );
      } catch (e) {
        // fallback: return baseDate at midnight so comparisons fail safely
        return DateTime(baseDate.year, baseDate.month, baseDate.day);
      }
    }

    // Check day slots (sunrise..sunset) on the same day
    for (final slot in daySlots) {
      final start = _parse(slot['start'] ?? '', today);
      var end = _parse(slot['end'] ?? '', today);
      if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
        end = end.add(const Duration(days: 1));
      }
      if (now.isAfter(start) && now.isBefore(end) ||
          now.isAtSameMomentAs(start)) {
        return slot['choghadiya']?.toString();
      }
    }

    // Check night slots (sunset..next sunrise) - may cross midnight
    for (final slot in nightSlots) {
      final start = _parse(slot['start'] ?? '', today);
      var end = _parse(slot['end'] ?? '', today);
      if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
        end = end.add(const Duration(days: 1));
      }
      if (now.isAfter(start) && now.isBefore(end) ||
          now.isAtSameMomentAs(start)) {
        return slot['choghadiya']?.toString();
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors();

    return Scaffold(
      backgroundColor: colors.white,
      appBar: AppBar(
        backgroundColor: colors.white,
        automaticallyImplyLeading: false,
        title: Text(
          'Panchang Calendar',
          style: TextStyle(
            color: colors.primaryColorApp[50],
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        actions: [
          Tooltip(
            message: 'Go to Today',
            child: TextButton.icon(
              onPressed: () {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                // Always make the calendar view jump back to the current
                // month (so today becomes visible). If the currently
                // selected date is different, update selection and reload
                // data; if it's the same, avoid redundant reload but still
                // force the month to be displayed.
                try {
                  // call showMonth on the calendar state (use dynamic to
                  // avoid referencing private state type across files)
                  (_calendarKey.currentState as dynamic)?.showMonth(
                    today,
                    animate: true,
                  );
                } catch (_) {}

                if (!(selectedDate.year == today.year &&
                    selectedDate.month == today.month &&
                    selectedDate.day == today.day)) {
                  _selectDate(today);
                }
              },
              icon: Icon(Icons.today, color: colors.primaryColorApp[50]),
              label: Text(
                'Today',
                style: TextStyle(color: colors.primaryColorApp[50]),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                minimumSize: Size(0, 40.w),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colors.primaryColorApp[50],
              ),
            )
          : StreamBuilder<MediaItem?>(
              stream: _audioHandler?.mediaItem,
              builder: (context, snapshot) {
                final bottomPadding = AppPadding.bottom(context, extra: 100.w);

                return Column(
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return _isCompact
                            ? _buildCompactDateSelector(colors)
                            : _buildFullCalendar();
                      },
                    ),

                    // Scrollable Content
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        child: Column(
                          children: [
                            SizedBox(height: 8.w),

                            // Panchang Elements
                            _buildPanchangCard(
                              colors,
                              'Tithi (Lunar Day)',
                              Icons.brightness_3,
                              Map<String, dynamic>.from(panchangData!['tithi'])
                                ..remove('paksha'),
                              Colors.indigo,
                            ),

                            const SizedBox(height: 16),
                            _buildSunTimesCard(colors),

                            const SizedBox(height: 16),
                            _buildNavkarsiChauviharCard(colors),

                            const SizedBox(height: 16),
                            _buildChoghadiyaCard(colors),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildFullCalendar() {
    return PanchangCalendarWidget(
      key: _calendarKey,
      selectedDate: selectedDate,
      onDateSelected: _selectDate,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );
  }

  Widget _buildCompactDateSelector(appColors colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.w),
      decoration: BoxDecoration(
        color: colors.white[50],
        border: Border.all(color: colors.primaryColorApp),
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: colors.gray[300]!.withOpacity(0.5),
            blurRadius: 10.w,
            offset: Offset(0.w, 3.w),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Day Button
          // Previous day (larger hit target)
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: colors.primaryColorApp[50],
              size: 28.w,
            ),
            onPressed: () => _changeDay(-1),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.w),
          ),

          // Date Display
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // onTap will toggle view; onTapDown expands immediately
              onTapDown: (details) {
                if (_isCompact) {
                  // Expand instantly (before any layout/scroll changes)
                  setState(() {
                    _isCompact = false;
                    _animationController.reverse();
                  });
                  _didExpandFromTapDown = true;
                }
              },
              onTap: () {
                // If we already expanded in onTapDown, avoid toggling back.
                if (_didExpandFromTapDown) {
                  _didExpandFromTapDown = false;
                  return;
                }
                _toggleCalendarView();
              },
              onVerticalDragUpdate: (details) {
                // accumulate upward drag distance; require a deliberate drag
                // (approx 40 logical pixels) to expand the calendar.
                if (details.delta.dy < 0) {
                  _verticalDragDistance += -details.delta.dy;
                  if (_verticalDragDistance > 40 && _isCompact) {
                    setState(() {
                      _isCompact = false; // expand
                      _animationController.reverse();
                    });
                    _verticalDragDistance = 0;
                  }
                }
              },
              onVerticalDragEnd: (details) {
                _verticalDragDistance = 0;
              },
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(selectedDate),
                    style: TextStyle(
                      color: colors.gray[600],
                      fontSize: 12.w,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.w),
                  Text(
                    DateFormat('dd MMM yyyy').format(selectedDate),
                    style: TextStyle(
                      color: colors.colorText[50],
                      fontSize: 18.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.w),
                  // Show active Choghadiya only for today's date
                  Builder(
                    builder: (context) {
                      final active = _getActiveChoghadiyaForToday();
                      if (active == null) return SizedBox(height: 4.w);

                      final chogColors = {
                        'Amrit': Colors.green,
                        'Shubh': Colors.green,
                        'Labh': Colors.green,
                        'Chal': Colors.green,
                        'Rog': Colors.red,
                        'Udveg': Colors.red,
                        'Kaal': Colors.red,
                      };

                      final Color color =
                          chogColors[active] ?? colors.gray[500]!;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 6.w),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.w,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16.w),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                active,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12.w,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12.w,
                        color: colors.primaryColorApp[50],
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'View Full Calendar',
                        style: TextStyle(
                          color: colors.primaryColorApp[50],
                          fontSize: 12.w,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      RotationTransition(
                        turns: Tween(begin: 0.0, end: -0.5).animate(_animation),
                        child: Icon(
                          Icons.expand_more,
                          size: 16.w,
                          color: colors.primaryColorApp[50],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Next day (larger hit target)
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: colors.primaryColorApp[50],
              size: 28.w,
            ),
            onPressed: () => _changeDay(1),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 40.w, minHeight: 40.w),
          ),
        ],
      ),
    );
  }

  Widget _buildSunTimesCard(appColors colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.white[50],
        borderRadius: BorderRadius.circular(15.w),
        boxShadow: [
          BoxShadow(
            color: colors.gray[300]!.withOpacity(0.5),
            blurRadius: 10.w,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSunTimeItem(
              colors,
              'Sunrise',
              panchangData!['sunrise'],
              Icons.wb_sunny,
              Colors.orange,
            ),
          ),
          Container(width: 1.w, height: 60.w, color: colors.gray[300]),
          Expanded(
            child: _buildSunTimeItem(
              colors,
              'Sunset',
              panchangData!['sunset'],
              Icons.wb_twilight,
              Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavkarsiChauviharCard(appColors colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.w),
      decoration: BoxDecoration(
        color: colors.white[50],
        borderRadius: BorderRadius.circular(15.w),
        boxShadow: [
          BoxShadow(
            color: colors.gray[300]!.withOpacity(0.5),
            blurRadius: 10.w,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.w),
                topRight: Radius.circular(15.w),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10.w),
                  ),
                  child: Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Navkarsi & Chauvihar',
                    style: TextStyle(
                      color: colors.colorText[50],
                      fontSize: 18.w,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNavkarsiTimeItem(
                  colors,
                  'Navkarsi',
                  panchangData!['navkarsi_start'],
                  Icons.access_time_filled,
                  Colors.green,
                ),
                SizedBox(height: 16.w),
                Divider(color: colors.gray[300]),
                SizedBox(height: 16.w),
                _buildNavkarsiTimeItem(
                  colors,
                  'Chauvihar',
                  panchangData!['chauvihar_end'],
                  Icons.schedule,
                  Colors.blue,
                ),
                SizedBox(height: 12.w),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavkarsiTimeItem(
    appColors colors,
    String label,
    String time,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.w),
          ),
          child: Icon(icon, color: iconColor, size: 20.w),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.gray[800],
                  fontSize: 13.w,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2.w),
              Text(
                time,
                style: TextStyle(
                  color: colors.colorText[50],
                  fontSize: 17.w,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSunTimeItem(
    appColors colors,
    String label,
    String time,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 32.w),
        SizedBox(height: 8.w),
        Text(
          label,
          style: TextStyle(
            color: colors.gray[700],
            fontSize: 14.w,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.w),
        Text(
          time,
          style: TextStyle(
            color: colors.colorText[50],
            fontSize: 18.w,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPanchangCard(
    appColors colors,
    String title,
    IconData icon,
    Map<String, dynamic> data,
    Color accentColor,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.w),
      decoration: BoxDecoration(
        color: colors.white[50],
        borderRadius: BorderRadius.circular(15.w),
        boxShadow: [
          BoxShadow(
            color: colors.gray[300]!.withOpacity(0.5),
            blurRadius: 10.w,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.w),
                topRight: Radius.circular(15.w),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(10.w),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.colorText[50],
                      fontSize: 16.w,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['name'],
                      style: TextStyle(
                        color: colors.colorText[50],
                        fontSize: 18.w,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (data.containsKey('paksha'))
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.w,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.w),
                        ),
                        child: Text(
                          data['paksha'] + ' Paksha',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12.w,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 2.w),
                if (data.containsKey('lord'))
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.w),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_circle,
                          color: colors.gray[600],
                          size: 16.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Lord: ${data['lord']}',
                          style: TextStyle(
                            color: colors.gray[700],
                            fontSize: 14.w,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoghadiyaCard(appColors colors) {
    Map<String, dynamic> choghadiya = panchangData!['choghadiya'];
    List<Map<String, dynamic>> daySlots = List<Map<String, dynamic>>.from(
      choghadiya['day'],
    );
    List<Map<String, dynamic>> nightSlots = List<Map<String, dynamic>>.from(
      choghadiya['night'],
    );

    final chogColors = {
      'Amrit': Colors.green,
      'Shubh': Colors.green,
      'Labh': Colors.green,
      'Chal': Colors.green,
      'Rog': Colors.red,
      'Udveg': Colors.red,
      'Kaal': Colors.red,
    };

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.w),
      decoration: BoxDecoration(
        color: colors.white[50],
        borderRadius: BorderRadius.circular(15.w),
        boxShadow: [
          BoxShadow(
            color: colors.gray[300]!.withOpacity(0.5),
            blurRadius: 10.w,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15.w),
                topRight: Radius.circular(15.w),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(10.w),
                  ),
                  child: Icon(Icons.schedule, color: Colors.white, size: 24.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Choghadiya (Auspicious Times)',
                    style: TextStyle(
                      color: colors.colorText[50],
                      fontSize: 17.w,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day (Sunrise to Sunset)',
                  style: TextStyle(
                    color: colors.colorText[50],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.w),
                _buildChoghadiyaTable(colors, daySlots, chogColors),
                SizedBox(height: 20.w),
                Divider(color: colors.gray[300], thickness: 2),
                SizedBox(height: 20.w),
                Text(
                  'Night (Sunset to Sunrise)',
                  style: TextStyle(
                    color: colors.colorText[50],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12.w),
                _buildChoghadiyaTable(colors, nightSlots, chogColors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoghadiyaTable(
    appColors colors,
    List<Map<String, dynamic>> slots,
    Map<String, Color> chogColors,
  ) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(2.5), 1: FlexColumnWidth(4)},
      border: TableBorder.all(
        color: colors.gray[300]!,
        width: 1.w,
        borderRadius: BorderRadius.circular(8.w),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.gray[100]),
          children: [
            _buildTableHeaderCell(colors, 'Choghadiya'),
            _buildTableHeaderCell(colors, 'Time'),
          ],
        ),
        ...slots.map((slot) {
          String chogName = slot['choghadiya'];
          Color chogColor = chogColors[chogName] ?? colors.gray[500]!;

          return TableRow(
            children: [
              _buildTableCell(colors, chogName, color: chogColor, isBold: true),
              _buildTableCell(
                colors,
                '${slot['start']} - ${slot['end']}',
                isTime: true,
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeaderCell(appColors colors, String text) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.colorText[50],
          fontSize: 14.w,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    appColors colors,
    String text, {
    Color? color,
    bool isBold = false,
    bool isTime = false,
  }) {
    return Padding(
      padding: EdgeInsets.all(8.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? colors.colorText[50],
          fontSize: isTime ? 13.w : 14.w,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}
