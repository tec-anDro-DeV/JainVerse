import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:animations/animations.dart';

class AppHeader extends StatefulWidget {
  static const double defaultScrollUpThreshold = 15.0;
  static const double defaultScrollDownThreshold = 8.0;

  final String title;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final bool showBackButton;
  final bool showProfileIcon;
  final VoidCallback? onBackPressed;
  final VoidCallback? onProfileTap;
  final Widget? leadingWidget;
  final Widget? trailingWidget;
  final ScrollController? scrollController;
  final bool scrollAware;
  final double elevation;
  final bool showGridToggle;
  final VoidCallback? onGridToggle;
  final bool? isGridView;
  final double scrollUpThreshold;
  final double scrollDownThreshold;

  const AppHeader({
    super.key,
    required this.title,
    this.backgroundColor,
    this.titleStyle,
    this.showBackButton = false,
    this.showProfileIcon = true,
    this.onBackPressed,
    this.onProfileTap,
    this.leadingWidget,
    this.trailingWidget,
    this.scrollController,
    this.scrollAware = false,
    this.elevation = 0,
    this.showGridToggle = false,
    this.onGridToggle,
    this.isGridView,
    this.scrollUpThreshold = defaultScrollUpThreshold,
    this.scrollDownThreshold = defaultScrollDownThreshold,
  }) : assert(
         !(showBackButton && leadingWidget != null),
         'Cannot show both back button and leading widget',
       ),
       assert(
         !(showGridToggle && trailingWidget != null),
         'Cannot show both grid toggle and trailing widget',
       );

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader>
    with SingleTickerProviderStateMixin {
  bool _isVisible = true;
  double _lastScrollPosition = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Keep track of whether we actually added the listener
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupScrollListener();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _setupScrollListener() {
    if (widget.scrollController != null && widget.scrollAware) {
      widget.scrollController!.addListener(_scrollListener);
      _listenerAdded = true;
    }
  }

  @override
  void didUpdateWidget(AppHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle scroll controller changes
    if (oldWidget.scrollController != widget.scrollController ||
        oldWidget.scrollAware != widget.scrollAware) {
      _removeScrollListener(oldWidget.scrollController);
      _setupScrollListener();
    }
  }

  @override
  void dispose() {
    _removeScrollListener(widget.scrollController);
    _animationController.dispose();
    super.dispose();
  }

  void _removeScrollListener(ScrollController? controller) {
    if (_listenerAdded && controller != null) {
      controller.removeListener(_scrollListener);
      _listenerAdded = false;
    }
  }

  void _scrollListener() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients || !mounted) {
      return;
    }

    final currentPosition = controller.position.pixels;
    final scrollDelta = currentPosition - _lastScrollPosition;

    // Only hide header when scrolling down (positive delta)
    if (scrollDelta > widget.scrollUpThreshold && _isVisible) {
      _hideHeader();
    }
    // Show header when scrolling up (negative delta) OR when at the top
    else if ((scrollDelta < -widget.scrollDownThreshold ||
            currentPosition <= 100) &&
        !_isVisible) {
      _showHeader();
    }

    _lastScrollPosition = currentPosition;
  }

  void _hideHeader() {
    if (!mounted) return;
    setState(() => _isVisible = false);
    _animationController.forward();
  }

  void _showHeader() {
    if (!mounted) return;
    setState(() => _isVisible = true);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return widget.scrollAware ? _buildAnimatedHeader() : _buildHeaderContent();
  }

  Widget _buildAnimatedHeader() {
    return SlideTransition(
      position: _slideAnimation,
      child: _buildHeaderContent(),
    );
  }

  Widget _buildHeaderContent() {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? Colors.transparent;
    final layoutType = _determineLayoutType();

    return Container(
      width: double.infinity,
      color: bgColor,
      child: Material(
        color: bgColor,
        elevation: widget.elevation,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 5.w, 14.w, 5.w),
          child: _buildRowContent(layoutType, theme),
        ),
      ),
    );
  }

  _LayoutType _determineLayoutType() {
    if (widget.leadingWidget == null &&
        !widget.showBackButton &&
        widget.trailingWidget == null &&
        !widget.showGridToggle &&
        widget.showProfileIcon) {
      return _LayoutType.titleAndProfile;
    }
    return _LayoutType.standard;
  }

  Widget _buildRowContent(_LayoutType layoutType, ThemeData theme) {
    switch (layoutType) {
      case _LayoutType.titleAndProfile:
        return Padding(
          padding: EdgeInsets.only(left: 12.0.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_buildTitle(TextAlign.left), _buildProfileIcon()],
          ),
        );
      case _LayoutType.standard:
        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildLeadingWidget(),
            _buildTitle(TextAlign.center),
            _buildTrailingWidget(),
          ],
        );
    }
  }

  Widget _buildTitle(TextAlign textAlign) {
    return Expanded(
      child: Text(
        widget.title,
        textAlign: textAlign,
        style: widget.titleStyle ?? _getDefaultTitleStyle(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: 'Header: ${widget.title}',
      ),
    );
  }

  TextStyle _getDefaultTitleStyle() {
    return TextStyle(
      fontSize: AppSizes.fontH2,
      fontWeight: FontWeight.w600,
      color: appColors().colorText,
    );
  }

  Widget _buildLeadingWidget() {
    if (widget.leadingWidget != null) {
      return widget.leadingWidget!;
    } else if (widget.showBackButton) {
      return _buildBackButton();
    } else {
      return SizedBox(width: 46.w);
    }
  }

  Widget _buildBackButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_outlined,
          color: widget.titleStyle?.color ?? appColors().colorText,
          size: AppSizes.iconSize,
        ),
        onPressed: widget.onBackPressed ?? () => Navigator.of(context).pop(),
        constraints: BoxConstraints(minWidth: 46.w, minHeight: 46.w),
        tooltip: 'Go back',
      ),
    );
  }

  Widget _buildTrailingWidget() {
    if (widget.trailingWidget != null) {
      return widget.trailingWidget!;
    } else if (widget.showGridToggle) {
      return _buildGridToggle();
    } else if (widget.showProfileIcon) {
      return _buildProfileIcon();
    } else {
      return SizedBox(width: 46.w);
    }
  }

  Widget _buildGridToggle() {
    // If callback is null, show a disabled button
    final bool isEnabled = widget.onGridToggle != null;
    final bool currentGridState = widget.isGridView ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          // If grid view is active, show list icon (angle=pi), else show grid icon (angle=0)
          begin: widget.isGridView == true ? 1.0 : 0.0,
          end: widget.isGridView == true ? 1.0 : 0.0,
        ),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutBack,
        builder: (context, value, child) {
          final double angle = value * 3.1416;
          Widget iconWidget;
          if (angle <= 3.1416 / 2) {
            iconWidget = SvgPicture.asset(
              'assets/icons/grid.svg',
              width: AppSizes.iconSize,
              height: AppSizes.iconSize,
              colorFilter: ColorFilter.mode(
                isEnabled
                    ? appColors().primaryColorApp
                    : appColors().primaryColorApp.withOpacity(0.5),
                BlendMode.srcIn,
              ),
            );
            return Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
              child: IconButton(
                icon: iconWidget,
                onPressed: isEnabled ? widget.onGridToggle : null,
                constraints: BoxConstraints(minWidth: 46.w, minHeight: 46.w),
                tooltip:
                    widget.isGridView == true
                        ? 'Switch to list view'
                        : 'Switch to grid view',
              ),
            );
          } else {
            iconWidget = SvgPicture.asset(
              'assets/icons/list.svg',
              width: AppSizes.iconSize,
              height: AppSizes.iconSize,
              colorFilter: ColorFilter.mode(
                isEnabled
                    ? appColors().primaryColorApp
                    : appColors().primaryColorApp.withOpacity(0.5),
                BlendMode.srcIn,
              ),
            );
            return Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle)
                    ..rotateY(3.1416), // flip back horizontally
              child: IconButton(
                icon: iconWidget,
                onPressed: isEnabled ? widget.onGridToggle : null,
                constraints: BoxConstraints(minWidth: 46.w, minHeight: 46.w),
                tooltip:
                    widget.isGridView == true
                        ? 'Switch to list view'
                        : 'Switch to grid view',
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileIcon() {
    return GestureDetector(
      onTap: widget.onProfileTap,
      child: Semantics(
        button: true,
        label: 'Profile',
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          width: 46.w,
          height: 46.w,
          padding: EdgeInsets.all(10.w),
          child: SvgPicture.asset(
            'assets/images/profile_inactive.svg',
            width: 24.w,
            height: 24.w,
            colorFilter: ColorFilter.mode(
              appColors().colorTextHead,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

enum _LayoutType { titleAndProfile, standard }
