# Video Player Architecture - Technical Design Document

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     JainVerse Application                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Navigation Stack                           │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │   Main Navigation Scaffold                        │  │    │
│  │  │  ┌────────────────────────────────────────────┐  │  │    │
│  │  │  │   Current Page (Home/Videos/Music/etc)     │  │  │    │
│  │  │  └────────────────────────────────────────────┘  │  │    │
│  │  │                                                   │  │    │
│  │  │  ┌────────────────────────────────────────────┐  │  │    │
│  │  │  │   Mini Player Layer                        │  │  │    │
│  │  │  │  ┌──────────────────────────────────────┐  │  │  │    │
│  │  │  │  │ Mini Music Player (if music active)  │  │  │  │    │
│  │  │  │  └──────────────────────────────────────┘  │  │  │    │
│  │  │  │  ┌──────────────────────────────────────┐  │  │  │    │
│  │  │  │  │ Mini Video Player (if video active)  │  │  │  │    │
│  │  │  │  └──────────────────────────────────────┘  │  │  │    │
│  │  │  └────────────────────────────────────────────┘  │  │    │
│  │  │                                                   │  │    │
│  │  │  ┌────────────────────────────────────────────┐  │  │    │
│  │  │  │   Bottom Navigation Bar                    │  │  │    │
│  │  │  └────────────────────────────────────────────┘  │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │   Full-Screen Players (Modal Routes)             │  │    │
│  │  │  ┌────────────────────────────────────────────┐  │  │    │
│  │  │  │ MusicPlayerView (fullscreenDialog: true)   │  │  │    │
│  │  │  └────────────────────────────────────────────┘  │  │    │
│  │  │  ┌────────────────────────────────────────────┐  │  │    │
│  │  │  │ VideoPlayerView (fullscreenDialog: true)   │  │  │    │
│  │  │  └────────────────────────────────────────────┘  │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎵 Music Player Architecture (Existing - Reference)

```
MusicPlayerView
├── GestureDetector (Pan gestures for dismissal)
│   └── Stack
│       ├── ModernVisualArea
│       │   ├── Blurred Background (from album art)
│       │   ├── AppBar (back, share buttons)
│       │   └── ModernAlbumArt (centered, animated)
│       │
│       └── Positioned (bottom)
│           └── ModernControlPanel
│               ├── TrackInfo (title, artist)
│               ├── SeekBar (position, duration)
│               ├── PlaybackControls (play, pause, skip, etc.)
│               ├── VolumeSlider (Android only)
│               ├── QueueOverlay (animated, collapsible)
│               └── LyricsOverlay (animated, collapsible)
│
├── Services
│   ├── AudioPlayerHandler (audio_service)
│   ├── MusicPlayerThemeService (dynamic theming)
│   └── MusicManager (state management)
│
└── State Management
    └── MusicPlayerStateManager (global visibility control)
```

### Mini Music Player

```
AnimatedMiniMusicPlayer
├── SlideTransition (slide up from bottom)
│   └── Container (90.w height)
│       ├── Album Art Thumbnail (70.w × 70.w)
│       ├── Track Info (title, artist)
│       ├── Play/Pause Button
│       └── Progress Bar (bottom overlay)
│
├── Tap Interaction
│   └── Navigate to MusicPlayerView (fullscreenDialog: true)
│
└── Stream Listeners
    ├── MediaItem stream (for updates)
    ├── Position stream (for progress)
    └── PlaybackState stream (for play/pause)
```

---

## 🎬 Video Player Architecture (New - To Be Implemented)

```
VideoPlayerView (mirrors MusicPlayerView)
├── GestureDetector (Pan gestures for dismissal)
│   └── Stack
│       ├── VideoVisualArea
│       │   ├── Blurred Background (from video thumbnail)
│       │   ├── AppBar (back, share buttons)
│       │   └── Video Player (centered, AspectRatio 16:9)
│       │       └── VideoPlayerWidget
│       │           ├── video_player (core package)
│       │           └── Chewie (controls, if needed)
│       │
│       └── Positioned (bottom)
│           └── VideoControlPanel
│               ├── MediaTrackInfo (video title, channel name)
│               ├── MediaSeekBar (position, duration)
│               ├── MediaPlaybackControls (play, pause, skip, etc.)
│               ├── MediaVolumeSlider (Android only)
│               ├── QueueOverlay (playlist/related videos)
│               └── DescriptionOverlay (video description)
│
├── Services
│   ├── VideoPlayerController (video_player package)
│   ├── VideoPlayerThemeService (dynamic theming)
│   └── VideoPlayerStateManager (state management)
│
└── State Management
    └── VideoPlayerStateManager (global visibility control)
```

### Mini Video Player

```
AnimatedMiniVideoPlayer (mirrors MiniMusicPlayer)
├── SlideTransition (slide up from bottom)
│   └── Container (90.w height)
│       ├── Video Thumbnail (70.w × 70.w)
│       │   ├── Thumbnail Image
│       │   └── Play Icon Overlay (if paused)
│       ├── Video Info (title, channel)
│       ├── Play/Pause Button
│       └── Progress Bar (bottom overlay)
│
├── Tap Interaction
│   └── Navigate to VideoPlayerView (fullscreenDialog: true)
│
└── Stream Listeners
    ├── VideoPlayerController.value (for updates)
    └── Position listener (for progress)
```

---

## 🔄 Shared Components Architecture

```
lib/widgets/shared_media_controls/
├── MediaSeekBar
│   ├── Input: position, duration, onSeek
│   ├── Output: Visual seek bar with drag interaction
│   └── Used by: MusicPlayer, VideoPlayer
│
├── MediaPlaybackControls
│   ├── Input: isPlaying, onPlay, onPause, onSkip, etc.
│   ├── Output: Play/pause, skip, shuffle, repeat buttons
│   └── Used by: MusicPlayer, VideoPlayer
│
├── MediaTrackInfo
│   ├── Input: title, subtitle (artist/channel)
│   ├── Output: Styled text display
│   └── Used by: MusicPlayer, VideoPlayer
│
└── MediaVolumeSlider (Android only)
    ├── Input: volume, onVolumeChange
    ├── Output: Volume slider with system integration
    └── Used by: MusicPlayer, VideoPlayer
```

---

## 📊 State Management Flow

### Music Player State

```
MusicPlayerStateManager (ChangeNotifier)
├── Properties
│   ├── _isFullPlayerVisible: bool
│   ├── _shouldHideNavigation: bool
│   ├── _shouldHideMiniPlayer: bool
│   └── _currentPageContext: String
│
├── Methods
│   ├── showFullPlayer()
│   ├── hideFullPlayer()
│   ├── hideMiniPlayerForPage(String)
│   ├── showMiniPlayerForPage(String)
│   └── showMiniPlayerForMusicStart()
│
└── Listeners
    └── UI components rebuild on notifyListeners()
```

### Video Player State (New)

```
VideoPlayerStateManager (ChangeNotifier)
├── Properties
│   ├── _isFullPlayerVisible: bool
│   ├── _shouldHideNavigation: bool
│   ├── _shouldHideMiniPlayer: bool
│   ├── _currentVideoId: String
│   └── _currentVideoItem: VideoItem?
│
├── Methods
│   ├── showFullPlayer()
│   ├── hideFullPlayer()
│   ├── hideMiniPlayerForPage(String)
│   ├── showMiniPlayerForPage(String)
│   └── showMiniPlayerForVideoStart()
│
└── Listeners
    └── UI components rebuild on notifyListeners()
```

### Coordination Logic

```
When user plays music:
1. MusicPlayerStateManager.showMiniPlayerForMusicStart()
2. VideoPlayerStateManager.hideMiniPlayerForPage('music_playing')
3. Pause video if playing
4. Show music mini player

When user plays video:
1. VideoPlayerStateManager.showMiniPlayerForVideoStart()
2. MusicPlayerStateManager.hideMiniPlayerForPage('video_playing')
3. Pause music if playing
4. Show video mini player

When user taps mini player:
1. Hide bottom navigation (both managers)
2. Hide mini player (both managers)
3. Show full player (respective manager)
4. Navigate with fullscreenDialog: true

When user dismisses full player:
1. Show mini player (respective manager)
2. Show bottom navigation (both managers)
3. Pop navigation
```

---

## 🎨 Theme Service Architecture

### Music Player Theme Service (Existing)

```
MusicPlayerThemeService (ChangeNotifier)
├── Properties
│   ├── _currentColorScheme: ColorScheme?
│   ├── _backgroundAnimation: AnimationController
│   └── _currentMediaItem: MediaItem?
│
├── Methods
│   ├── updateMediaItem(MediaItem?)
│   ├── initializeAnimations(TickerProvider)
│   ├── buildBackgroundDecoration()
│   └── extractColorsFromImage(ImageProvider)
│
└── Color Extraction
    ├── Use palette_generator package
    ├── Extract dominant colors from album art
    └── Generate ColorScheme for theming
```

### Video Player Theme Service (New)

```
VideoPlayerThemeService (ChangeNotifier)
├── Properties
│   ├── _currentColorScheme: ColorScheme?
│   ├── _backgroundAnimation: AnimationController
│   └── _currentVideoItem: VideoItem?
│
├── Methods
│   ├── updateVideoItem(VideoItem?)
│   ├── initializeAnimations(TickerProvider)
│   ├── buildBackgroundDecoration()
│   └── extractColorsFromImage(ImageProvider)
│
└── Color Extraction
    ├── Use palette_generator package
    ├── Extract dominant colors from video thumbnail
    └── Generate ColorScheme for theming
```

---

## 🔌 Integration Points

### 1. Video List Integration

```dart
// In video_card.dart or video list screens
onTap: () async {
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

### 2. Music List Integration

```dart
// In music_card.dart or music list screens
onTap: () async {
  // 1. Pause video if playing
  final videoStateManager = VideoPlayerStateManager();
  if (videoStateManager.isFullPlayerVisible) {
    // Video controller pause logic
  }

  // 2. Hide video mini player
  videoStateManager.hideMiniPlayerForPage('music_playing');

  // 3. Play music
  await audioHandler.skipToQueueItem(index);
  await audioHandler.play();

  // 4. Show music mini player
  MusicPlayerStateManager().showMiniPlayerForMusicStart();
}
```

### 3. Main Navigation Integration

```dart
// In main navigation scaffold
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [
        // Main content
        _buildCurrentPage(),

        // Mini players overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Music mini player
              ListenableBuilder(
                listenable: MusicPlayerStateManager(),
                builder: (context, _) {
                  final musicState = MusicPlayerStateManager();
                  if (musicState.shouldHideMiniPlayer) {
                    return const SizedBox.shrink();
                  }
                  return StreamBuilder<MediaItem?>(
                    stream: audioHandler.mediaItem,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return MiniMusicPlayer(audioHandler).buildMiniPlayer(context);
                    },
                  );
                },
              ),

              // Video mini player
              ListenableBuilder(
                listenable: VideoPlayerStateManager(),
                builder: (context, _) {
                  final videoState = VideoPlayerStateManager();
                  if (videoState.shouldHideMiniPlayer) {
                    return const SizedBox.shrink();
                  }
                  if (videoState.currentVideoItem == null) {
                    return const SizedBox.shrink();
                  }
                  return MiniVideoPlayer(
                    videoController: _videoController,
                  ).buildMiniPlayer(context);
                },
              ),

              // Bottom navigation
              ListenableBuilder(
                listenable: Listenable.merge([
                  MusicPlayerStateManager(),
                  VideoPlayerStateManager(),
                ]),
                builder: (context, _) {
                  final musicState = MusicPlayerStateManager();
                  final videoState = VideoPlayerStateManager();

                  // Hide navigation if either full player is visible
                  if (musicState.shouldHideNavigation ||
                      videoState.shouldHideNavigation) {
                    return const SizedBox.shrink();
                  }

                  return BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onNavigationTap,
                    items: _navigationItems,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

---

## 🎯 Data Flow Diagrams

### Music Playback Flow

```
User taps music item
    ↓
MusicCard.onTap()
    ↓
Check if video playing → Pause video
    ↓
audioHandler.skipToQueueItem(index)
    ↓
audioHandler.play()
    ↓
MusicPlayerStateManager.showMiniPlayerForMusicStart()
    ↓
MiniMusicPlayer becomes visible
    ↓
StreamBuilder updates UI with MediaItem
    ↓
User sees playing music in mini player

User taps mini player
    ↓
Navigator.push(MusicPlayerView)
    ↓
MusicPlayerStateManager.showFullPlayer()
    ↓
Hide mini player + bottom navigation
    ↓
Show full-screen MusicPlayerView
    ↓
User interacts with full player

User swipes down or taps back
    ↓
MusicPlayerView.onBackPressed()
    ↓
Navigator.pop()
    ↓
MusicPlayerStateManager.hideFullPlayer()
    ↓
Show mini player + bottom navigation
```

### Video Playback Flow

```
User taps video item
    ↓
VideoCard.onTap()
    ↓
Check if music playing → Pause music
    ↓
Navigator.push(VideoPlayerView)
    ↓
VideoPlayerView.initState()
    ↓
Initialize VideoPlayerController
    ↓
Load video from URL
    ↓
VideoPlayerStateManager.showMiniPlayerForVideoStart()
    ↓
MiniVideoPlayer becomes visible
    ↓
VideoController updates UI with position/duration
    ↓
User sees playing video in full player

User dismisses full player
    ↓
VideoPlayerView.onBackPressed()
    ↓
Navigator.pop()
    ↓
Video continues in mini player
    ↓
User sees video thumbnail + progress

User taps mini video player
    ↓
Navigator.push(VideoPlayerView)
    ↓
Resume at previous position
    ↓
Full player shows again
```

---

## 🧩 Component Breakdown

### Full-Screen Player Components

#### Visual Area (Top Half)

**Music:**

```
ModernVisualArea
├── Blurred background (from album art)
├── App bar (back, share)
└── Centered album art (animated rotation)
```

**Video:**

```
VideoVisualArea
├── Blurred background (from thumbnail)
├── App bar (back, share)
└── Centered video player (AspectRatio 16:9)
    └── VideoPlayerWidget
        ├── Chewie controls (optional)
        └── Double-tap skip overlay
```

#### Control Panel (Bottom Half)

**Both use shared components:**

```
MediaTrackInfo
├── Title (large, bold)
└── Subtitle (artist/channel, gray)

MediaSeekBar
├── Slider with drag interaction
├── Current position (left)
└── Total duration (right)

MediaPlaybackControls
├── Shuffle button (optional)
├── Previous button
├── Play/Pause button (large, centered)
├── Next button
└── Repeat button (optional)

MediaVolumeSlider (Android only)
├── Volume icon
└── Slider with system integration
```

### Mini Player Components

**Music:**

```
Container (90.w height)
├── Album Art (70.w × 70.w, rounded corners)
├── Column (Expanded)
│   ├── Title (bold, ellipsis)
│   └── Artist (gray, ellipsis)
├── Play/Pause Button (56.w circle)
└── Progress Bar (5.w height, bottom overlay)
```

**Video:**

```
Container (90.w height)
├── Video Thumbnail (70.w × 70.w, rounded corners)
│   ├── Thumbnail Image
│   └── Play Icon Overlay (if paused)
├── Column (Expanded)
│   ├── Title (bold, ellipsis)
│   └── Channel (gray, ellipsis)
├── Play/Pause Button (56.w circle)
└── Progress Bar (5.w height, bottom overlay)
```

---

## 🔐 State Isolation

### Preventing Conflicts

```
MusicPlayerStateManager
├── Only controls music-related UI
├── Independent lifecycle
└── Can coexist with VideoPlayerStateManager

VideoPlayerStateManager
├── Only controls video-related UI
├── Independent lifecycle
└── Can coexist with MusicPlayerStateManager

Coordination Layer (in navigation scaffold)
├── Listens to both managers
├── Ensures mutual exclusivity
└── Handles transitions between media types
```

### Example: Switching from Music to Video

```
1. User playing music
   - MusicPlayerStateManager.isFullPlayerVisible = false
   - MusicPlayerStateManager.shouldHideMiniPlayer = false
   - VideoPlayerStateManager.isFullPlayerVisible = false
   - VideoPlayerStateManager.shouldHideMiniPlayer = true

2. User taps video
   - Pause music: audioHandler.pause()
   - Hide music mini: MusicPlayerStateManager.hideMiniPlayerForPage('video')
   - Show video full: Navigator.push(VideoPlayerView)
   - Update video state: VideoPlayerStateManager.showFullPlayer()

3. New state
   - MusicPlayerStateManager.isFullPlayerVisible = false
   - MusicPlayerStateManager.shouldHideMiniPlayer = true
   - VideoPlayerStateManager.isFullPlayerVisible = true
   - VideoPlayerStateManager.shouldHideMiniPlayer = true

4. User dismisses video
   - Hide video full: Navigator.pop()
   - Update video state: VideoPlayerStateManager.hideFullPlayer()
   - Show video mini: VideoPlayerStateManager.showMiniPlayerForVideoStart()

5. Final state
   - MusicPlayerStateManager.isFullPlayerVisible = false
   - MusicPlayerStateManager.shouldHideMiniPlayer = true
   - VideoPlayerStateManager.isFullPlayerVisible = false
   - VideoPlayerStateManager.shouldHideMiniPlayer = false
```

---

## 📱 Platform-Specific Considerations

### Android

```
Features:
✅ Volume slider in control panel
✅ System volume integration
✅ Material design ripple effects
✅ Hardware back button support
✅ Picture-in-Picture (future enhancement)

Constraints:
- Must handle system volume events
- Must respect audio focus
- Must handle interruptions (calls, notifications)
```

### iOS

```
Features:
✅ No volume slider (system controls)
✅ Cupertino-style haptic feedback
✅ iOS-specific gestures
✅ SwiftUI interop (future)

Constraints:
- Must respect silent mode
- Must handle interruptions (calls, FaceTime)
- Must integrate with Control Center
```

---

## ⚡ Performance Optimizations

### 1. Image Loading

```dart
// Use SmartImageWidget for efficient caching
SmartImageWidget(
  imageUrl: mediaItem.artUri.toString(),
  width: size,
  height: size,
  fit: BoxFit.cover,
  placeholder: _buildPlaceholder(),
  errorWidget: _buildErrorWidget(),
)
```

### 2. Animation Performance

```dart
// Use RepaintBoundary for isolated repaints
RepaintBoundary(
  child: ModernAlbumArt(...),
)

// Use const constructors where possible
const MediaTrackInfo(...)
```

### 3. State Updates

```dart
// Debounce frequent updates (seek bar)
Timer? _debounceTimer;

void _onSeekUpdate(Duration position) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(
    const Duration(milliseconds: 100),
    () => _updatePosition(position),
  );
}
```

### 4. Memory Management

```dart
// Dispose controllers properly
@override
void dispose() {
  _videoController.dispose();
  _themeService.dispose();
  _animationController.dispose();
  super.dispose();
}

// Pause video when not visible
if (appLifecycleState == AppLifecycleState.paused) {
  _videoController.pause();
}
```

---

## 🧪 Testing Strategy

### Unit Tests

```dart
// Test state managers
test('VideoPlayerStateManager hides mini player when full player shown', () {
  final manager = VideoPlayerStateManager();
  manager.showFullPlayer();

  expect(manager.isFullPlayerVisible, true);
  expect(manager.shouldHideMiniPlayer, true);
});

// Test shared components
testWidgets('MediaSeekBar responds to drag gestures', (tester) async {
  Duration? seekedTo;

  await tester.pumpWidget(
    MaterialApp(
      home: MediaSeekBar(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 180),
        onSeek: (pos) => seekedTo = pos,
      ),
    ),
  );

  // Simulate drag
  await tester.drag(find.byType(Slider), Offset(100, 0));
  await tester.pumpAndSettle();

  expect(seekedTo, isNotNull);
});
```

### Integration Tests

```dart
// Test navigation flow
testWidgets('Tapping video card opens full player', (tester) async {
  await tester.pumpWidget(MyApp());

  // Find and tap video card
  await tester.tap(find.byType(VideoCard).first);
  await tester.pumpAndSettle();

  // Verify full player is shown
  expect(find.byType(VideoPlayerView), findsOneWidget);
  expect(find.byType(BottomNavigationBar), findsNothing);
});

// Test switching between music and video
testWidgets('Playing video pauses music', (tester) async {
  // Setup: music is playing
  final musicManager = MusicManager();
  await musicManager.play();

  // Tap video card
  await tester.tap(find.byType(VideoCard).first);
  await tester.pumpAndSettle();

  // Verify music is paused
  expect(musicManager.isPlaying, false);

  // Verify video mini player is visible
  expect(find.byType(MiniVideoPlayer), findsOneWidget);
  expect(find.byType(MiniMusicPlayer), findsNothing);
});
```

### Manual Testing Checklist

```
Music Player:
[ ] Play music from list
[ ] Music mini player appears
[ ] Tap mini player → full player opens
[ ] All controls work (play, pause, skip, etc.)
[ ] Swipe down → returns to mini player
[ ] Mini player shows progress
[ ] Play video → music pauses, mini player hides

Video Player:
[ ] Play video from list
[ ] Video mini player appears
[ ] Tap mini player → full player opens
[ ] All controls work (play, pause, seek, etc.)
[ ] Swipe down → returns to mini player
[ ] Mini player shows thumbnail + progress
[ ] Play music → video pauses, mini player hides

Integration:
[ ] Switch music → video → music
[ ] Navigation bar hides/shows correctly
[ ] No memory leaks
[ ] No performance issues
[ ] Handles interruptions (calls, etc.)
```

---

## 🚀 Future Enhancements

### Phase 2 (Post-MVP)

1. **Picture-in-Picture (PiP)**

   - Android native PiP support
   - Floating video window
   - Minimal controls

2. **Casting Support**

   - Chromecast integration
   - AirPlay support
   - Cast controls in player

3. **Playlist/Queue Management**

   - Video playlists
   - Auto-play next video
   - Queue reordering

4. **Advanced Controls**

   - Playback speed control
   - Quality selection
   - Subtitle support

5. **Analytics**
   - Watch time tracking
   - Engagement metrics
   - Error logging

---

## 📚 Dependencies

### Core Packages

```yaml
dependencies:
  # Video playback
  video_player: ^2.8.1
  chewie: ^1.7.4

  # Audio playback (existing)
  audio_service: ^0.18.12
  just_audio: ^0.9.36

  # UI
  flutter_screenutil: ^5.9.0
  cached_network_image: ^3.3.0

  # State management
  provider: ^6.1.1 # or existing state solution

  # Utilities
  rxdart: ^0.27.7
  palette_generator: ^0.3.3+3
```

---

## 🔍 Code Organization

```
lib/
├── videoplayer/
│   ├── screens/
│   │   ├── video_player_view.dart              # NEW: Main full-screen player
│   │   └── common_video_player_screen.dart     # EXISTING: Legacy (keep for compatibility)
│   ├── widgets/
│   │   ├── video_player_widget.dart            # EXISTING: Core playback
│   │   ├── mini_video_player.dart              # NEW: Mini player
│   │   ├── video_visual_area.dart              # NEW: Top visual section
│   │   └── video_control_panel.dart            # NEW: Bottom controls
│   ├── managers/
│   │   └── video_player_state_manager.dart     # NEW: Global state
│   └── services/
│       └── video_player_theme_service.dart     # NEW: Dynamic theming
│
├── widgets/
│   ├── shared_media_controls/                  # NEW: Shared UI components
│   │   ├── media_seek_bar.dart
│   │   ├── media_playback_controls.dart
│   │   ├── media_track_info.dart
│   │   └── media_volume_slider.dart
│   └── musicplayer/
│       ├── MusicPlayerView.dart                # EXISTING: Refactor to use shared
│       ├── control_panel.dart                  # EXISTING: Refactor to use shared
│       └── ...other existing files...
│
└── utils/
    └── music_player_state_manager.dart         # EXISTING: Keep separate
```

---

_Document Version: 1.0_
_Last Updated: November 3, 2025_
_Status: Ready for Review & Implementation_
