import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated subscribe/unsubscribe button with smooth transitions
class AnimatedSubscribeButton extends StatefulWidget {
  final bool isSubscribed;
  final VoidCallback onPressed;

  const AnimatedSubscribeButton({
    super.key,
    required this.isSubscribed,
    required this.onPressed,
  });

  @override
  State<AnimatedSubscribeButton> createState() =>
      _AnimatedSubscribeButtonState();
}

class _AnimatedSubscribeButtonState extends State<AnimatedSubscribeButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  // Party (particle burst) animation
  late AnimationController _partyController;
  late Random _rand;
  late List<double> _angles;
  late List<Color> _particleColors;
  static const int _particleCount = 12;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Party controller for burst animation
    _partyController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _rand = Random();
    _angles = List.generate(_particleCount, (_) => _rand.nextDouble() * 2 * pi);
    _particleColors = List.generate(
      _particleCount,
      (_) => Colors.primaries[_rand.nextInt(Colors.primaries.length)]
          .withOpacity(0.95),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _partyController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedSubscribeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSubscribed != widget.isSubscribed) {
      // Trigger animation when subscription state changes
      _controller.forward().then((_) => _controller.reverse());

      // If it became subscribed, play the party burst
      if (!oldWidget.isSubscribed && widget.isSubscribed) {
        try {
          _partyController.forward(from: 0);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(20.w),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: widget.isSubscribed
                      ? Colors.grey.shade300
                      : Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20.w),
                  border: Border.all(
                    color: widget.isSubscribed
                        ? Colors.grey.shade400
                        : Theme.of(context).primaryColor,
                    width: 1.w,
                  ),
                  boxShadow: widget.isSubscribed
                      ? []
                      : [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.25),
                            blurRadius: 6.w,
                            offset: Offset(0, 1.5.h),
                          ),
                        ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    key: ValueKey(widget.isSubscribed),
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 3.h,
                    ),
                    child: Text(
                      widget.isSubscribed ? 'Subscribed' : 'Subscribe',
                      style: TextStyle(
                        color: widget.isSubscribed
                            ? Colors.grey.shade700
                            : Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Party particles painted while party controller is animating
              AnimatedBuilder(
                animation: _partyController,
                builder: (context, _) {
                  if (_partyController.value <= 0)
                    return const SizedBox.shrink();
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ParticlePainter(
                          progress: _partyController.value,
                          angles: _angles,
                          colors: _particleColors,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0
  final List<double> angles;
  final List<Color> colors;

  _ParticlePainter({
    required this.progress,
    required this.angles,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final maxDistance = (size.width + size.height) / 4;

    for (int i = 0; i < angles.length; i++) {
      final angle = angles[i];
      final distance =
          Curves.easeOut.transform(progress) *
          maxDistance *
          (0.5 + (i % 4) * 0.2);
      final pos = Offset(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );
      final sizeFactor = (1.0 - progress) * (3 + (i % 3) * 1.5);
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = colors[i % colors.length].withOpacity(opacity);
      canvas.drawCircle(pos, sizeFactor, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.angles != angles;
  }
}
