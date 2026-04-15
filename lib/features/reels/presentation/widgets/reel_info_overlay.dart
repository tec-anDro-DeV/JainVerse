import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/features/reels/data/models/reel_item.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/videoplayer/screens/channel_detail_screen.dart';
import 'package:jainverse/videoplayer/services/subscription_service.dart';

/// Bottom-left overlay showing channel avatar, name, subscribe button,
/// reel title, and description (with tappable #hashtags).
class ReelInfoOverlay extends StatelessWidget {
  final ReelItem reel;

  const ReelInfoOverlay({super.key, required this.reel});

  void _goToChannel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelVideosScreen(
          channelId: reel.channelId,
          channelName: reel.channelName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Channel row: avatar + name (tappable) + subscribe button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {}, // absorbs tap so parent mute-toggle doesn't fire
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _goToChannel(context),
                child: _Avatar(url: reel.channelImageUrl),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: GestureDetector(
                  onTap: () => _goToChannel(context),
                  child: Text(
                    reel.channelName.isNotEmpty
                        ? reel.channelName
                        : reel.channelHandle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
              if (reel.isOwn != 1) ...[
                SizedBox(width: 8.w),
                _SubscribeButton(
                  channelId: reel.channelId,
                  initialSubscribed: reel.subscribed,
                ),
              ],
            ],
          ),
        ),

        if (reel.title.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Text(
            reel.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ],

        if (reel.description != null && reel.description!.isNotEmpty) ...[
          SizedBox(height: 4.h),
          _HashtagText(text: reel.description!),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Subscribe button
// ---------------------------------------------------------------------------

class _SubscribeButton extends StatefulWidget {
  final int channelId;
  final int initialSubscribed;

  const _SubscribeButton({
    required this.channelId,
    required this.initialSubscribed,
  });

  @override
  State<_SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<_SubscribeButton> {
  late bool _isSubscribed;
  bool _isLoading = false;
  final SubscriptionService _service = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _isSubscribed =
        SubscriptionStateManager().getSubscriptionState(widget.channelId) ??
            (widget.initialSubscribed == 1);
    SubscriptionStateManager().addListener(_onSubscriptionChanged);
  }

  @override
  void dispose() {
    SubscriptionStateManager().removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    final updated =
        SubscriptionStateManager().getSubscriptionState(widget.channelId);
    if (updated != null && updated != _isSubscribed) {
      if (mounted) setState(() => _isSubscribed = updated);
    }
  }

  Future<void> _toggle() async {
    if (_isLoading) return;
    final next = !_isSubscribed;
    setState(() {
      _isSubscribed = next;
      _isLoading = true;
    });
    SubscriptionStateManager().updateSubscriptionState(widget.channelId, next);
    try {
      if (next) {
        await _service.subscribeChannel(channelId: widget.channelId);
      } else {
        await _service.unsubscribeChannel(channelId: widget.channelId);
      }
    } catch (_) {
      // Rollback
      if (mounted) setState(() => _isSubscribed = !next);
      SubscriptionStateManager().updateSubscriptionState(widget.channelId, !next);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 26.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: _isSubscribed ? Colors.white24 : Colors.transparent,
          border: Border.all(
            color: _isSubscribed ? Colors.white38 : Colors.white,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(
                  width: 10.w,
                  height: 10.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 1.5,
                  ),
                )
              : Text(
                  _isSubscribed ? '✓ Following' : '+ Subscribe',
                  style: TextStyle(
                    color: _isSubscribed ? Colors.white60 : Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hashtag-aware text
// ---------------------------------------------------------------------------

class _HashtagText extends StatefulWidget {
  final String text;

  const _HashtagText({required this.text});

  @override
  State<_HashtagText> createState() => _HashtagTextState();
}

class _HashtagTextState extends State<_HashtagText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dispose old recognizers before rebuilding
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final tokens = widget.text.split(RegExp(r'(\s+)'));
    final spans = <InlineSpan>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.startsWith('#') && token.length > 1) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            // Future: navigate to hashtag feed
          };
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: const Color(0xFF90CAF9),
            fontSize: 12.sp,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(
          text: token,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.sp,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ));
      }
      // Re-add whitespace between tokens
      if (i < tokens.length - 1) {
        spans.add(TextSpan(
          text: ' ',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12.sp,
          ),
        ));
      }
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16.r,
      backgroundColor: Colors.white24,
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Icon(
                  Icons.person,
                  color: Colors.white70,
                  size: 18.w,
                ),
              )
            : Icon(Icons.person, color: Colors.white70, size: 18.w),
      ),
    );
  }
}
