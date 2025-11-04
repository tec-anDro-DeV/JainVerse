# Video Player Implementation - Quick Reference Guide

## 🚀 Quick Start

### Files You'll Create (in order)

```
Phase 1: Shared Components
├── lib/widgets/shared_media_controls/media_seek_bar.dart
├── lib/widgets/shared_media_controls/media_playback_controls.dart
├── lib/widgets/shared_media_controls/media_track_info.dart
└── lib/widgets/shared_media_controls/media_volume_slider.dart

Phase 2: Infrastructure
├── lib/videoplayer/managers/video_player_state_manager.dart
└── lib/videoplayer/services/video_player_theme_service.dart

Phase 3: Full-Screen Player
├── lib/videoplayer/screens/video_player_view.dart
├── lib/videoplayer/widgets/video_visual_area.dart
└── lib/videoplayer/widgets/video_control_panel.dart

Phase 4: Mini Player
└── lib/videoplayer/widgets/mini_video_player.dart
```

---

## 📋 Implementation Cheat Sheet

### Copy These Patterns from Music Player

#### 1. State Manager Template

```dart
// From: lib/utils/music_player_state_manager.dart
// To: lib/videoplayer/managers/video_player_state_manager.dart

class VideoPlayerStateManager extends ChangeNotifier {
  static final VideoPlayerStateManager _instance = VideoPlayerStateManager._internal();
  factory VideoPlayerStateManager() => _instance;
  VideoPlayerStateManager._internal();

  bool _isFullPlayerVisible = false;
  bool _shouldHideNavigation = false;
  bool _shouldHideMiniPlayer = false;
  String _currentPageContext = '';

  // Copy methods from MusicPlayerStateManager
  void showFullPlayer() { ... }
  void hideFullPlayer() { ... }
  // ... etc
}
```

#### 2. Mini Player Template

```dart
// From: lib/widgets/music/mini_music_player.dart
// To: lib/videoplayer/widgets/mini_video_player.dart

class MiniVideoPlayer {
  final VideoPlayerController? _videoController;

  static String videoTitle = '';
  static String videoThumbnail = '';
  static String channelName = '';

  Widget buildMiniPlayer(BuildContext context) {
    return AnimatedMiniVideoPlayer(
      videoController: _videoController,
    );
  }
}
```

#### 3. Full Player View Template

```dart
// From: lib/widgets/musicplayer/MusicPlayerView.dart
// To: lib/videoplayer/screens/video_player_view.dart

class VideoPlayerView extends StatefulWidget {
  final String videoUrl;
  final VideoItem? videoItem;
  final VoidCallback onBackPressed;
  // ... similar constructor
}

class _VideoPlayerViewState extends State<VideoPlayerView>
    with TickerProviderStateMixin {
  // Copy gesture handling from MusicPlayerView
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  void _onPanStart(DragStartDetails details) { ... }
  void _onPanUpdate(DragUpdateDetails details) { ... }
  void _onPanEnd(DragEndDetails details) { ... }
}
```

---

## 🎨 UI Component Mapping

### Music → Video Mapping

| Music Component      | Video Equivalent    | Changes                             |
| -------------------- | ------------------- | ----------------------------------- |
| `ModernVisualArea`   | `VideoVisualArea`   | Replace album art with video player |
| `ModernAlbumArt`     | `VideoPlayerWidget` | Use AspectRatio 16:9                |
| `ModernControlPanel` | `VideoControlPanel` | Same, use shared components         |
| `MiniMusicPlayer`    | `MiniVideoPlayer`   | Replace album art with thumbnail    |

---

## 🔧 Common Code Snippets

### 1. Extracting Shared Seek Bar

```dart
// NEW: lib/widgets/shared_media_controls/media_seek_bar.dart
class MediaSeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Function(Duration) onSeek;
  final Color? progressColor;
  final Color? backgroundColor;

  const MediaSeekBar({
    Key? key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.progressColor,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Copy implementation from music player's seek_bar.dart
  }
}
```

### 2. Video Visual Area

```dart
// NEW: lib/videoplayer/widgets/video_visual_area.dart
class VideoVisualArea extends StatelessWidget {
  final VideoItem? videoItem;
  final VideoPlayerController videoController;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred background from thumbnail
        _buildBlurredBackground(),

        // App bar + video player
        Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoPlayerWidget(
                    videoUrl: videoItem?.videoUrl ?? '',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

### 3. Mini Video Player Thumbnail

```dart
Widget _buildVideoThumbnail() {
  return Container(
    width: 70.w,
    height: 70.w,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16.w),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16.w),
      child: Stack(
        children: [
          // Thumbnail image
          SmartImageWidget(
            imageUrl: MiniVideoPlayer.videoThumbnail,
            fit: BoxFit.cover,
          ),

          // Play icon overlay (if paused)
          if (!_videoController.value.isPlaying)
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(8.w),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24.w,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
```

### 4. Coordination Logic

```dart
// When user plays video
void _onVideoCardTap(VideoItem videoItem) async {
  // 1. Pause music if playing
  final musicManager = MusicManager();
  if (musicManager.isPlaying) {
    await musicManager.pause();
  }

  // 2. Hide music mini player
  MusicPlayerStateManager().hideMiniPlayerForPage('video_playing');

  // 3. Show video player
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => VideoPlayerView(
        videoUrl: videoItem.videoUrl,
        videoItem: videoItem,
        onBackPressed: () {
          Navigator.pop(context);
          // Restore music mini player if music was playing
          if (musicManager.getCurrentMediaItem() != null) {
            MusicPlayerStateManager().showMiniPlayerForPage('video_playing');
          }
        },
      ),
      fullscreenDialog: true,
    ),
  );

  // 4. Update video state
  VideoPlayerStateManager().showMiniPlayerForVideoStart();
}
```

---

## 🐛 Common Pitfalls & Solutions

### Pitfall 1: Video Plays in Mini Player

**Problem**: Trying to play video in mini player causes lag
**Solution**: Always show thumbnail, never live video

```dart
// ❌ DON'T DO THIS
child: VideoPlayer(_videoController), // In mini player

// ✅ DO THIS INSTEAD
child: Stack(
  children: [
    Image(image: getThumbnail()),
    if (!isPlaying) Icon(Icons.play_arrow),
  ],
)
```

### Pitfall 2: State Conflicts

**Problem**: Music and video both playing
**Solution**: Always pause one before starting the other

```dart
// ✅ Always check and pause
if (musicManager.isPlaying) {
  await musicManager.pause();
}
// Then start video
```

### Pitfall 3: Memory Leaks

**Problem**: Controllers not disposed
**Solution**: Always dispose in dispose()

```dart
@override
void dispose() {
  _videoController.dispose();
  _slideController.dispose();
  _themeService.dispose();
  super.dispose();
}
```

### Pitfall 4: Gesture Conflicts

**Problem**: Swipe gesture doesn't work
**Solution**: Use same pattern as music player

```dart
// Copy gesture detection from MusicPlayerView
GestureDetector(
  onPanStart: _onPanStart,
  onPanUpdate: _onPanUpdate,
  onPanEnd: _onPanEnd,
  behavior: HitTestBehavior.translucent,
  child: ...,
)
```

---

## 📐 Size Constants (Consistent Across Both)

```dart
// Mini Player
static const double miniPlayerHeight = 90.0; // Using .w
static const double albumArtSize = 70.0;     // Using .w
static const double playButtonSize = 56.0;   // Using .w
static const double progressBarHeight = 5.0; // Using .w

// Full Player
static const double appBarHeight = 56.0;     // Using .w
static const double borderRadius = 12.0;     // Using .w
static const double padding = 16.0;          // Using .w
```

---

## 🎯 Testing Checklist

### After Each Phase

```
Phase 1: Shared Components
[ ] Music player still works with new components
[ ] Seek bar responds to drag
[ ] Play/pause button works
[ ] Volume slider works (Android)

Phase 2: Infrastructure
[ ] VideoPlayerStateManager methods work
[ ] State changes notify listeners
[ ] No conflicts with MusicPlayerStateManager

Phase 3: Full-Screen Player
[ ] Video plays correctly
[ ] Swipe down gesture dismisses
[ ] All controls work
[ ] Theme updates based on thumbnail

Phase 4: Mini Player
[ ] Slide-up animation works
[ ] Thumbnail displays correctly
[ ] Play overlay appears when paused
[ ] Progress bar updates
[ ] Tapping opens full player

Phase 5: Integration
[ ] Switching music → video → music works
[ ] Navigation bar hides/shows correctly
[ ] Only one mini player visible
[ ] No memory leaks
```

---

## 🔍 Debug Tips

### Enable Logging

```dart
// Add to video player
debugPrint('[VideoPlayer] State: ${_videoController.value.isPlaying}');
debugPrint('[VideoPlayer] Position: ${_videoController.value.position}');

// Add to state manager
void showFullPlayer() {
  debugPrint('[VideoState] Showing full player');
  _isFullPlayerVisible = true;
  notifyListeners();
}
```

### Monitor Performance

```dart
// Check frame rate
import 'dart:developer' as developer;

void _monitorPerformance() {
  Timeline.startSync('video_render');
  // Your rendering code
  Timeline.finishSync();
}
```

### Check Memory Usage

```dart
// In Chrome DevTools or Android Studio
// Look for:
// - Growing memory usage
// - Undisposed controllers
// - Leaked listeners
```

---

## 📚 Key Files Reference

### Music Player (Study These)

```
lib/widgets/musicplayer/MusicPlayerView.dart        // Main structure
lib/widgets/music/mini_music_player.dart            // Mini player
lib/widgets/musicplayer/control_panel.dart          // Controls
lib/widgets/musicplayer/visual_area.dart            // Visual layout
lib/utils/music_player_state_manager.dart           // State management
```

### Video Player (Create These)

```
lib/videoplayer/screens/video_player_view.dart      // Mirror of MusicPlayerView
lib/videoplayer/widgets/mini_video_player.dart      // Mirror of MiniMusicPlayer
lib/videoplayer/widgets/video_control_panel.dart    // Mirror of ModernControlPanel
lib/videoplayer/widgets/video_visual_area.dart      // Mirror of ModernVisualArea
lib/videoplayer/managers/video_player_state_manager.dart // Mirror of MusicPlayerStateManager
```

---

## 🎨 Color Schemes

### Extract from Music Player

```dart
// From MusicPlayerThemeService
ColorScheme currentColorScheme;

// Use in video player
VideoPlayerThemeService.currentColorScheme;
```

### Default Colors (Fallback)

```dart
ColorScheme(
  primary: Color(0xFFFF6B6B),
  secondary: Color(0xFF4ECDC4),
  background: Colors.black,
  surface: Colors.white,
  // ... etc
);
```

---

## ⏱️ Animation Timings

```dart
// Match music player
const Duration animationDuration = Duration(milliseconds: 300);
const Duration slideInDuration = Duration(milliseconds: 400);
const Curve animationCurve = Curves.easeOutCubic;
const Curve slideInCurve = Curves.easeOutCubic;
```

---

## 🚨 Error Handling

### Video Loading Errors

```dart
if (_videoController.value.hasError) {
  return _buildErrorWidget(
    'Unable to load video',
    onRetry: () => _initializeVideo(),
  );
}
```

### Network Errors

```dart
try {
  await _videoController.initialize();
} on TimeoutException {
  _showError('Network timeout. Please check your connection.');
} catch (e) {
  _showError('Failed to load video: $e');
}
```

---

## 📱 Platform-Specific Code

```dart
// Volume slider (Android only)
if (Platform.isAndroid) {
  MediaVolumeSlider(...);
}

// Different padding
final bottomPadding = Platform.isAndroid ? 20.w : 10.w;

// Different controls
final controls = Platform.isAndroid
  ? androidControls
  : iosControls;
```

---

## 🔗 Quick Links

- **Implementation Plan**: `docs/VIDEO_PLAYER_IMPLEMENTATION_PLAN.md`
- **Architecture**: `docs/VIDEO_PLAYER_ARCHITECTURE.md`
- **Summary**: `docs/PROJECT_SUMMARY.md`

---

## ☎️ Need Help?

1. Check the detailed docs first
2. Review music player code
3. Use debugPrint() liberally
4. Test on real device, not just emulator
5. Ask for help if stuck for >30 minutes

---

**Happy Coding! 🎉**

_Quick Reference v1.0 - Updated: Nov 3, 2025_
