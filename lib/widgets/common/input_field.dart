import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/CountryModel.dart';
import 'package:jainverse/ThemeMain/appColors.dart'; // Add this import

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String labelText;
  final bool enabled;
  final bool obscureText;
  final TextInputType keyboardType;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Function()? onEditingComplete;
  final Function(String)? onSubmitted;
  final Function(String)? onChanged; // Add onChanged callback
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters; // Add this line
  final String? errorText; // Add error text support

  const InputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.labelText = '',
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
    this.onChanged, // Add onChanged callback
    this.maxLength,
    this.inputFormatters, // Add this line
    this.errorText, // Add error text support
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          errorText != null
              ? 90.w
              : 70.w, // Increase height when error is present
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onEditingComplete: onEditingComplete,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged, // Add onChanged callback
        enabled: enabled,
        maxLength: maxLength,
        inputFormatters: inputFormatters, // Add this line
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText.isEmpty ? null : labelText,
          errorText: errorText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16.sp),
          prefixIcon:
              prefixIcon != null
                  ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: Icon(
                      prefixIcon,
                      size: 22.sp,
                      color: Colors.grey.shade600,
                    ),
                  )
                  : null,
          suffixIcon:
              suffixIcon != null
                  ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: Icon(
                      suffixIcon,
                      size: 22.sp,
                      color: Colors.grey.shade700,
                    ),
                  )
                  : null,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade300,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 20.w, // Changed from .w to .w
          ),
          counterText: maxLength != null ? '' : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.w),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: appColors().primaryColorApp,
              width: 1.5.w,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: appColors().primaryColorApp,
              width: 1.w,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: appColors().primaryColorApp,
              width: 1.5.w,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.w),
          ),
        ),
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey.shade600,
          fontSize: 16.sp,
        ),
      ),
    );
  }
}

class PasswordInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Function()? onEditingComplete;
  final Function(String)? onSubmitted;

  const PasswordInputField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
  });

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70.w, // Changed from .w to .w
      child: TextFormField(
        controller: widget.controller,
        obscureText: !_passwordVisible,
        focusNode: widget.focusNode,
        textInputAction: widget.textInputAction,
        onEditingComplete: widget.onEditingComplete,
        onFieldSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16.sp),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w),
            child: Icon(
              Icons.lock_outline,
              size: 22.sp,
              color: Colors.grey.shade600,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 22.sp,
              color: Colors.grey.shade600,
            ),
            onPressed: () {
              setState(() {
                _passwordVisible = !_passwordVisible;
              });
            },
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 20.w, // Changed from .w to .w
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.w),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: appColors().primaryColorApp,
              width: 1.5.w,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: appColors().primaryColorApp,
              width: 1.w,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r),
            borderSide: BorderSide(
              color: appColors().primaryColorApp,
              width: 1.5.w,
            ),
          ),
        ),
        style: TextStyle(color: Colors.black87, fontSize: 16.sp),
      ),
    );
  }
}

class DropdownInputField<T> extends StatelessWidget {
  final String hintText;
  final String labelText;
  final T value;
  final List<T> items;
  final Function(T?) onChanged;
  final IconData prefixIcon;
  final bool enabled;
  final String Function(T)? displayTextBuilder;

  const DropdownInputField({
    super.key,
    required this.hintText,
    this.labelText = '',
    required this.value,
    required this.items,
    required this.onChanged,
    required this.prefixIcon,
    this.enabled = true,
    this.displayTextBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.w, // Changed from .w to .w
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300, width: 1.w),
      ),
      child: DropdownButtonFormField<T>(
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Icon(prefixIcon, size: 22.sp, color: Colors.grey.shade600),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 16.w, // Changed from .w to .w
            horizontal: 16.w,
          ),
          hintText: hintText,
          labelText: labelText.isEmpty ? null : labelText,
        ),
        value: value,
        isExpanded: true,
        icon: Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey.shade600,
            size: 24.sp,
          ),
        ),
        onChanged: enabled ? onChanged : null,
        items:
            items.map<DropdownMenuItem<T>>((T item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  displayTextBuilder != null
                      ? displayTextBuilder!(item)
                      : item.toString(),
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }).toList(),
        dropdownColor: Colors.white,
      ),
    );
  }
}

class GenderInputField extends StatelessWidget {
  final String? value;
  final Function(String?) onChanged;
  final bool enabled;

  const GenderInputField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  static const List<String> genderOptions = ['Male', 'Female', 'Other'];

  @override
  Widget build(BuildContext context) {
    // If value is null, we should not try to set it as the dropdown value
    final String? dropdownValue = value;

    return Container(
      height: 56.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300, width: 1.w),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Icon(
              Icons.person_outline,
              size: 22.sp,
              color: Colors.grey.shade600,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 16.w,
            horizontal: 16.w,
          ),
          hintText: 'Select Gender',
        ),
        value: dropdownValue,
        isExpanded: true,
        icon: Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey.shade600,
            size: 24.sp,
          ),
        ),
        onChanged: enabled ? onChanged : null,
        items:
            genderOptions.map<DropdownMenuItem<String>>((String gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(
                  gender,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }).toList(),
        dropdownColor: Colors.white,
        hint: Text(
          'Select Gender',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey.shade400,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

class CountryInputField extends StatelessWidget {
  final Country? value; // Changed to Country object
  final Function(Country?) onChanged;
  final List<Country> countries; // Accept dynamic country list
  final bool enabled;

  const CountryInputField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.countries, // Required countries list
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300, width: 1.w),
      ),
      child: DropdownButtonFormField<Country>(
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Icon(
              Icons.language,
              size: 22.sp,
              color: Colors.grey.shade600,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 16.w,
            horizontal: 16.w,
          ),
          hintText: 'Select Country',
        ),
        value: value,
        isExpanded: true,
        icon: Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey.shade600,
            size: 24.sp,
          ),
        ),
        onChanged: enabled ? onChanged : null,
        items:
            countries.map<DropdownMenuItem<Country>>((Country country) {
              return DropdownMenuItem<Country>(
                value: country,
                child: Text(
                  country.nicename,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }).toList(),
        dropdownColor: Colors.white,
        hint: Text(
          'Select Country',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey.shade400,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}
