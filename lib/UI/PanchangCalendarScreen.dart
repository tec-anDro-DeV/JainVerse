import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/services/panchang_service.dart';
import 'package:jainverse/widgets/panchang/panchang_calendar_widget.dart';

class PanchangCalendarScreen extends StatefulWidget {
  const PanchangCalendarScreen({super.key});

  @override
  State<PanchangCalendarScreen> createState() => _PanchangCalendarScreenState();
}

class _PanchangCalendarScreenState extends State<PanchangCalendarScreen> {
  late DateTime selectedDate;
  late PanchangService panchangService;
  Map<String, dynamic>? panchangData;
  bool isLoading = true;
  AudioHandler? _audioHandler;

  // Default location - India (can be made customizable)
  double latitude = 23.0225; // India center
  double longitude = 72.5714;
  double timezone = 5.5; // IST

  @override
  void initState() {
    super.initState();
    // Normalize to midnight to ensure consistent calculations
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    _audioHandler = const MyApp().called();
    _loadPanchangData();
  }

  void _loadPanchangData() {
    setState(() {
      isLoading = true;
    });

    // Create Panchang service with selected date
    panchangService = PanchangService(
      date: selectedDate,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
    );

    // Get Panchang data
    panchangData = panchangService.getPanchang();

    setState(() {
      isLoading = false;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
      _loadPanchangData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColors();

    return Scaffold(
      backgroundColor: colors.white,
      appBar: AppBar(
        backgroundColor: colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primaryColorApp[50]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Panchang Calendar',
          style: TextStyle(
            color: colors.primaryColorApp[50],
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.today, color: colors.primaryColorApp[50]),
            onPressed: () {
              // Normalize to midnight to ensure consistent calculations
              final now = DateTime.now();
              _selectDate(DateTime(now.year, now.month, now.day));
            },
            tooltip: 'Go to Today',
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
                // Calculate proper bottom padding accounting for mini player and navigation
                final hasMiniPlayer = snapshot.hasData;
                final bottomPadding = hasMiniPlayer
                    ? AppSizes.basePadding + AppSizes.miniPlayerPadding + 100.w
                    : AppSizes.basePadding + AppSizes.miniPlayerPadding + 20.w;

                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  child: Column(
                    children: [
                      // Calendar Widget
                      PanchangCalendarWidget(
                        selectedDate: selectedDate,
                        onDateSelected: _selectDate,
                        latitude: latitude,
                        longitude: longitude,
                        timezone: timezone,
                      ),

                      SizedBox(height: 8.w),

                      // Date Header (simple)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 22.w,
                          vertical: 8.w,
                        ),
                        // Place weekday and full date on the same row, left-aligned
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Date first
                            Text(
                              DateFormat('dd MMMM yyyy').format(selectedDate),
                              style: TextStyle(
                                color: colors.colorText[50],
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Separator (comma) between date and day
                            Text(
                              ', ',
                              style: TextStyle(
                                color: colors.colorText[50],
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Day after, same style as date
                            Text(
                              DateFormat('EEEE').format(selectedDate),
                              style: TextStyle(
                                color: colors.colorText[50],
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 2.w),

                      // Panchang Elements
                      // Pass a copy of the tithi data with 'paksha' removed so
                      // the Paksha badge does not render for the Tithi card.
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
                      // Navkarsi & Chauvihar Timing
                      _buildNavkarsiChauviharCard(colors),
                      const SizedBox(height: 16),

                      // Choghadiya Table
                      _buildChoghadiyaCard(colors),

                      const SizedBox(height: 16),

                      // _buildPanchangCard(
                      //   colors,
                      //   'Nakshatra (Lunar Mansion)',
                      //   Icons.star,
                      //   panchangData!['nakshatra'],
                      //   Colors.purple,
                      // ),

                      /*
                      // Yoga card removed per request
                      _buildPanchangCard(
                        colors,
                        'Yoga',
                        Icons.self_improvement,
                        panchangData!['yoga'],
                        Colors.teal,
                      ),

                      // Karana card removed per request
                      _buildPanchangCard(
                        colors,
                        'Karana',
                        Icons.timelapse,
                        panchangData!['karana'],
                        Colors.orange,
                      ),

                      // Rashi card removed per request
                      _buildRashiCard(colors),
                      */
                    ],
                  ),
                );
              },
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
              Icons.wb_twighlight,
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
          // Header
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

          // Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navkarsi Start Time
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

                // Chauvihar End Time
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
          // Header
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

          // Content
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

    // Define color mapping for each Choghadiya type
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
          // Header
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

          // Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Section
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

                // Night Section
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
      columnWidths: const {
        // Give more space to time column (index 1) and keep choghadiya narrower.
        0: FlexColumnWidth(2.5), // Choghadiya (smaller)
        1: FlexColumnWidth(4), // Time (wider)
      },
      border: TableBorder.all(
        color: colors.gray[300]!,
        width: 1.w,
        borderRadius: BorderRadius.circular(8.w),
      ),
      children: [
        // Header row: Choghadiya first, Time next (no Planet column)
        TableRow(
          decoration: BoxDecoration(color: colors.gray[100]),
          children: [
            _buildTableHeaderCell(colors, 'Choghadiya'),
            _buildTableHeaderCell(colors, 'Time'),
          ],
        ),
        // Data rows
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

  /*
  // Rashi card removed per request. Function kept commented for reference.
  Widget _buildRashiCard(appColors colors) {
    Map<String, String> rashi = panchangData!['rashi'];

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
          // Header
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
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
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(10.w),
                  ),
                  child: const Icon(Icons.album, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Rashi (Zodiac Signs)',
                    style: TextStyle(
                      color: colors.colorText[50],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                _buildRashiItem(colors, 'Sun', rashi['sun']!, Icons.wb_sunny),
                SizedBox(height: 12.w),
                Divider(color: colors.gray[300]),
                SizedBox(height: 12.w),
                _buildRashiItem(
                  colors,
                  'Moon',
                  rashi['moon']!,
                  Icons.brightness_3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  */

  /*
  // Rashi item helper commented out per request
  Widget _buildRashiItem(
    appColors colors,
    String celestialBody,
    String rashi,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: colors.primaryColorApp[50], size: 28.w),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                celestialBody,
                style: TextStyle(color: colors.gray[600], fontSize: 14),
              ),
              SizedBox(height: 4.w),
              Text(
                rashi,
                style: TextStyle(
                  color: colors.colorText[50],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  */
}
