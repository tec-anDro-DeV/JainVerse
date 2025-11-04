# Landscape Video Player

A full-screen landscape video player with YouTube-style controls and modern UX.

## Features

### 🎬 Core Playback

- **Full-screen landscape mode** with automatic orientation lock
- **Responsive video scaling** that adapts to different aspect ratios
- **Smooth playback** with uninterrupted video during screen transitions
- **Auto-play on load** with loading indicator

### 🎨 User Interface

#### Top Bar (always visible)

- Video title (truncated if too long)
- Channel/subtitle name
- Settings button (quality, speed, subtitles)

#### Center Controls (auto-hide)

- **Large Play/Pause button** with smooth animations
- **10-second Rewind** button (left)
- **10-second Forward** button (right)
- Circular buttons with semi-transparent backgrounds
- Loading indicator during buffering

#### Bottom Bar (auto-hide)

- **Scrubba seek bar** with red accent (YouTube-style)
- **Current timestamp** (left)
- **Total duration** (right)
- **Fullscreen exit button** to return to previous screen

### ⚡ Interactions

#### Gesture Controls

- **Tap anywhere** to toggle control visibility
- **Auto-hide after 3 seconds** of inactivity
- **User interaction resets timer** - controls stay visible when actively seeking/tapping

#### System UI

- **Immersive mode** - hides system bars for distraction-free viewing
- **Automatic restoration** of system UI and orientation on exit

### ⚙️ Settings Menu

Bottom sheet with options:

- **Quality selection** (placeholder - ready for implementation)
- **Playback speed** (0.25x to 2.0x with easy picker)
- **Subtitles** (placeholder - ready for implementation)

## Usage

### Basic Launch

```dart
import 'package:jainverse/videoplayer/utils/landscape_video_launcher.dart';

// Launch landscape player
LandscapeVideoLauncher.launch(
  context: context,
  videoUrl: 'https://example.com/video.mp4',
  videoId: 'unique-video-id',
  title: 'Video Title',
  channelName: 'Channel Name',
  thumbnailUrl: 'https://example.com/thumbnail.jpg',
);
```

### Replace Current Screen

```dart
// Replace current route instead of pushing
LandscapeVideoLauncher.replace(
  context: context,
  videoUrl: videoUrl,
  videoId: videoId,
  title: title,
  channelName: channelName,
);
```

### Direct Widget Usage

```dart
import 'package:jainverse/videoplayer/screens/landscape_video_player.dart';

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => LandscapeVideoPlayer(
      videoUrl: 'https://example.com/video.mp4',
      videoId: 'video123',
      title: 'My Video',
      channelName: 'My Channel',
    ),
  ),
);
```

## Architecture

### State Management

- Uses **Riverpod** with the existing `videoPlayerProvider`
- Seamless integration with existing video player infrastructure
- Automatic cleanup and disposal on exit

### Layout Structure

```
Stack
├── Video Player Surface (center-aligned, aspect-ratio preserved)
└── Overlay Controls (animated opacity)
    ├── Top Bar (SafeArea)
    │   ├── Title & Channel
    │   └── Settings Button
    ├── Center Controls
    │   ├── 10s Rewind Button
    │   ├── Play/Pause Button (large)
    │   └── 10s Forward Button
    └── Bottom Bar (SafeArea)
        ├── Seek Bar
        ├── Timestamps
        └── Exit Button
```

### Auto-Hide Timer

- Default: **3 seconds** after last interaction
- Cancels when controls are manually hidden
- Resets on any user interaction (tap, seek, button press)

## Customization

### Change Auto-Hide Duration

Edit `_startHideTimer()` in `landscape_video_player.dart`:

```dart
_hideControlsTimer = Timer(const Duration(seconds: 5), () { // Change to 5 seconds
  if (mounted) {
    setState(() {
      _showControls = false;
    });
  }
});
```

### Customize Colors

The player uses a black background with semi-transparent overlays. To customize:

```dart
// Background
backgroundColor: Colors.black, // Main background

// Seek bar (YouTube-style red)
activeTrackColor: Colors.red,
thumbColor: Colors.red,

// Control overlays
Colors.black.withOpacity(0.7), // Top/bottom gradient
Colors.white.withOpacity(0.2), // Button backgrounds
```

### Add More Settings

Add to `_showSettingsBottomSheet()`:

```dart
ListTile(
  leading: const Icon(Icons.closed_caption_rounded, color: Colors.white),
  title: const Text('Captions', style: TextStyle(color: Colors.white)),
  onTap: () {
    Navigator.pop(context);
    // Your implementation
  },
),
```

## Integration with Existing Video Player

The landscape player integrates seamlessly with your existing video infrastructure:

1. **Reuses `videoPlayerProvider`** - No duplicate state management
2. **Shares video controller** - Smooth transitions from portrait
3. **Respects existing lifecycle** - Proper cleanup and disposal
4. **Compatible with playlists** - Can be extended for prev/next support

## Platform Support

- ✅ **Android** - Full support with immersive mode
- ✅ **iOS** - Full support with orientation lock
- ⚠️ **Web** - Basic support (no orientation lock)
- ⚠️ **Desktop** - Displays in landscape-like wide format

## Known Limitations

1. **Orientation Lock** - Web/Desktop don't support forced orientation
2. **Quality Switching** - Placeholder UI only; needs backend implementation
3. **Subtitles** - Placeholder UI only; needs subtitle parser
4. **Picture-in-Picture** - Not yet implemented

## Future Enhancements

### Planned Features

- [ ] Gesture-based volume/brightness control (swipe left/right edges)
- [ ] Double-tap left/right for 10s seek (alternative to buttons)
- [ ] Pinch-to-zoom for video surface
- [ ] Picture-in-Picture mode
- [ ] Chromecast support
- [ ] Playlist navigation (prev/next video)
- [ ] Video quality auto-switching based on bandwidth
- [ ] Resume playback from last position
- [ ] Downloadable offline viewing

### Potential Customizations

- [ ] Configurable seek increment (10s, 15s, 30s)
- [ ] Theme variants (light mode, custom accent colors)
- [ ] Adjustable control fade timing
- [ ] Custom control layouts (e.g., Netflix-style)
- [ ] Haptic feedback on interactions

## Troubleshooting

### Controls don't hide

- Check if `_startHideTimer()` is being called after interactions
- Verify timer isn't being cancelled prematurely

### Video doesn't fill screen

- Check device aspect ratio vs video aspect ratio
- Verify `AspectRatio` widget is preserving video dimensions

### Orientation doesn't lock

- Ensure `SystemChrome.setPreferredOrientations()` is called in `initState()`
- Check platform permissions (iOS Info.plist orientation settings)

### Playback interrupted on rotation

- The player prevents rotation interruption by locking orientation
- If still occurring, check `VideoPlayerController` initialization

## Examples

### Example 1: Launch from Video List

```dart
VideoCard(
  video: video,
  onTap: () {
    LandscapeVideoLauncher.launch(
      context: context,
      videoUrl: video.url,
      videoId: video.id,
      title: video.title,
      channelName: video.channel,
      thumbnailUrl: video.thumbnail,
    );
  },
)
```

### Example 2: Fullscreen Toggle from Portrait Player

```dart
IconButton(
  icon: Icon(Icons.fullscreen),
  onPressed: () {
    LandscapeVideoLauncher.launch(
      context: context,
      videoUrl: currentVideoUrl,
      videoId: currentVideoId,
      title: currentTitle,
      channelName: currentChannel,
    );
  },
)
```

### Example 3: Auto-launch Landscape on Rotate

```dart
@override
void didChangeMetrics() {
  super.didChangeMetrics();
  final orientation = MediaQuery.of(context).orientation;

  if (orientation == Orientation.landscape && !_isInLandscapeMode) {
    LandscapeVideoLauncher.launch(
      context: context,
      videoUrl: videoUrl,
      videoId: videoId,
      // ... other params
    );
  }
}
```

## Contributing

When extending the landscape player:

1. Maintain the existing auto-hide timer pattern
2. Keep controls visually consistent with YouTube/modern players
3. Test on both Android and iOS
4. Ensure smooth animations (300ms duration recommended)
5. Handle edge cases (very short videos, network errors, etc.)

## License

Part of the JainVerse application.
