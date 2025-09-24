import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class AuthTabBar extends StatefulWidget {
  final String selectedRole;
  final Function(String) onRoleChanged;
  final List<String>? options; // Optional custom options

  const AuthTabBar({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
    this.options, // Add optional options parameter
  });

  @override
  State<AuthTabBar> createState() => _AuthTabBarState();
}

class _AuthTabBarState extends State<AuthTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Define the available roles - use custom options if provided
  List<String> get _roles => widget.options ?? ['Listener', 'Artist'];

  @override
  void initState() {
    super.initState();

    // Initialize animation controller with initial position
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _getAnimationValue(widget.selectedRole),
    );
  }

  // Helper method to get animation value based on selected role
  double _getAnimationValue(String selectedRole) {
    final index = _roles.indexOf(selectedRole);
    return index == -1 ? 0.0 : index.toDouble() / (_roles.length - 1);
  }

  @override
  void didUpdateWidget(AuthTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRole != widget.selectedRole) {
      _animationController.animateTo(_getAnimationValue(widget.selectedRole));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Stack(
        children: [
          // Animated indicator that slides between tabs
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                left:
                    _animationController.value *
                        (MediaQuery.of(context).size.width - 60.w - 8.r) /
                        2 +
                    4.r,
                top: 4.r,
                bottom: 4.r,
                // Fixed width that takes exactly half of available space minus margins
                width: (MediaQuery.of(context).size.width - 60.w - 8.r) / 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEE5533),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              );
            },
          ),

          // Tab options row
          Row(
            children:
                _roles.map((role) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => widget.onRoleChanged(role),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          color: Colors.transparent,
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color:
                                  widget.selectedRole == role
                                      ? Colors.white
                                      : appColors().black,
                              fontSize: 16.sp,
                              fontWeight:
                                  widget.selectedRole == role
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                              fontFamily: 'Poppins',
                            ),
                            child: Text(role),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
