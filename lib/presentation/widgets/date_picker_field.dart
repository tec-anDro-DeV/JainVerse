import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class DatePickerField extends StatelessWidget {
  final String? selectedDate;
  final String hintText;
  final VoidCallback onTap;

  const DatePickerField({
    super.key,
    this.selectedDate,
    required this.hintText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
      margin: const EdgeInsets.fromLTRB(22, 10, 22, 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appColors().colorBackEditText,
            appColors().colorBackEditText,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30.0),
        border: Border.all(width: 0.5, color: appColors().colorBorder),
      ),
      child: TextField(
        readOnly: true,
        style: TextStyle(
          color: appColors().colorText,
          fontSize: 17.0,
          fontFamily: 'Poppins',
        ),
        decoration: InputDecoration(
          hintText: selectedDate?.isNotEmpty == true ? selectedDate : hintText,
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17.0,
            color:
                selectedDate?.isNotEmpty == true
                    ? appColors().colorText
                    : appColors().colorHint,
          ),
          suffixIcon: IconButton(
            padding: const EdgeInsets.all(13),
            icon: Icon(Icons.calendar_today, color: appColors().colorText),
            onPressed: onTap,
          ),
          suffixIconConstraints: const BoxConstraints(
            minHeight: 18,
            minWidth: 8,
          ),
          border: InputBorder.none,
        ),
        onTap: onTap,
      ),
    );
  }
}
