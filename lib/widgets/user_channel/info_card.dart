import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class InfoCard extends StatelessWidget {
  final Map<String, String> items; // label -> value
  final Map<String, IconData> icons;

  const InfoCard({super.key, required this.items, required this.icons});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.w),
      child: Column(
        children: items.entries.map((entry) {
          final label = entry.key;
          final value = entry.value;
          final icon = icons[label] ?? Icons.info_outline;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: appColors().primaryColorApp.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                      child: Icon(
                        icon,
                        size: 20.w,
                        color: appColors().primaryColorApp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: appColors().colorTextHead,
                            ),
                          ),
                          SizedBox(height: 4.w),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: appColors().colorTextHead,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            ],
          );
        }).toList(),
      ),
    );
  }
}
