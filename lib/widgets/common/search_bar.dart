import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import '../../ThemeMain/sizes.dart';

class CommonSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;
  final VoidCallback? onClear;
  final bool showClearButton;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? backgroundColor;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const CommonSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.showClearButton = true,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.backgroundColor,
    this.height,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? AppSizes.inputHeight,
      margin:
          margin ??
          EdgeInsets.fromLTRB(AppSizes.paddingS, 0, AppSizes.paddingS, 10.w),
      padding:
          padding ??
          EdgeInsets.fromLTRB(AppSizes.paddingS, 0, AppSizes.paddingS, 0),
      decoration: BoxDecoration(
        color: backgroundColor ?? appColors().gray[100],
        borderRadius: BorderRadius.circular(AppSizes.borderRadius + 10.w),
      ),
      child: Row(
        children: [
          // Prefix icon (search icon by default)
          prefixIcon ??
              Icon(
                Icons.search,
                color: appColors().gray[500],
                size: AppSizes.iconSize + 4.w,
              ),
          SizedBox(width: AppSizes.paddingS + 6.w),

          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontNormal,
                  color: appColors().gray[600],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: AppSizes.fontNormal,
                color: Colors.black87,
              ),
            ),
          ),

          // Clear button or custom suffix icon
          if (showClearButton && controller.text.isNotEmpty)
            InkWell(
              onTap:
                  onClear ??
                  () {
                    controller.clear();
                    onChanged('');
                  },
              child: Container(
                padding: EdgeInsets.all(AppSizes.paddingXS),
                child: Icon(
                  Icons.clear,
                  color: appColors().gray[600],
                  size: AppSizes.iconSize - 2.w,
                ),
              ),
            )
          else if (suffixIcon != null)
            suffixIcon!,
        ],
      ),
    );
  }
}

// Animated version with focus states
class AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String) onChanged;
  final VoidCallback? onClear;
  final bool showClearButton;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? backgroundColor;
  final Color? focusedBorderColor;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AnimatedSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.showClearButton = true,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.backgroundColor,
    this.focusedBorderColor,
    this.height,
    this.margin,
    this.padding,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: widget.height ?? AppSizes.inputHeight,
      margin:
          widget.margin ??
          EdgeInsets.fromLTRB(AppSizes.paddingS, 0, AppSizes.paddingS, 10.w),
      padding:
          widget.padding ??
          EdgeInsets.fromLTRB(AppSizes.paddingM, 0, AppSizes.paddingM, 0),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? appColors().gray[100],
        borderRadius: BorderRadius.circular(AppSizes.borderRadius + 10.w),
        boxShadow:
            _isFocused
                ? [
                  BoxShadow(
                    color: appColors().black.withOpacity(0.1),
                    // blurRadius: AppSizes.paddingS,
                    // spreadRadius: 2.w,
                  ),
                ]
                : null,
      ),
      child: Row(
        children: [
          // Animated prefix icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child:
                widget.prefixIcon ??
                Icon(
                  Icons.search,
                  color:
                      _isFocused
                          ? appColors().primaryColorApp
                          : appColors().gray[500],
                  size: AppSizes.iconSize + 4.w,
                ),
          ),
          SizedBox(width: AppSizes.paddingS + 6.w),

          // Text field
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: AppSizes.fontNormal,
                  color: appColors().gray[400],
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: AppSizes.fontNormal,
                color: Colors.black87,
              ),
            ),
          ),

          // Animated clear button or custom suffix icon
          if (widget.showClearButton && widget.controller.text.isNotEmpty)
            AnimatedScale(
              scale: 1.0,
              duration: const Duration(milliseconds: 150),
              child: InkWell(
                onTap:
                    widget.onClear ??
                    () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                child: Container(
                  padding: EdgeInsets.all(AppSizes.paddingXS),
                  child: Icon(
                    Icons.clear,
                    color: appColors().gray[400],
                    size: AppSizes.iconSize - 2.w,
                  ),
                ),
              ),
            )
          else if (widget.suffixIcon != null)
            widget.suffixIcon!,
        ],
      ),
    );
  }
}
