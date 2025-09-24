# Media Items Widgets

Specialized Flutter widgets for displaying songs and media content with both visual-first (grid) and text-first (list) layouts.

## Overview

These widgets are designed specifically for music applications where you need to display songs, albums, or playlists in an attractive and functional way. They provide two different layout approaches:

- **MediaGridCard**: Visual-first grid layout optimized for browsing by artwork
- **MediaListCard**: Text-first list layout optimized for quick scanning and search results

## Features

### Common Features

- ✅ Network image loading with fallback placeholders
- ✅ Loading states and error handling
- ✅ Context menu support (long press)
- ✅ Favorite status indicator
- ✅ Playing status with animated indicators
- ✅ Consistent theming support
- ✅ Accessibility support

### MediaGridCard (Grid View)

- 🖼️ **Visual-first design**: Square image with rounded corners fills most of the card
- 📝 **Center-aligned text**: Song title and artist name positioned below image
- 🎨 **Visual emphasis**: Ideal for browsing where artwork helps identify content
- 📱 **Compact layout**: Symmetrical design optimized for grid display
- ✨ **Playing animation**: Subtle scaling effect when song is playing

### MediaListCard (List View)

- 🖼️ **Small thumbnail**: Compact square image aligned to the left (1/4 of space)
- 📝 **Left-aligned text**: Song title and artist name with clear hierarchy
- ➡️ **Navigation indicator**: Right-facing chevron for clear interaction
- 📊 **Animated bars**: Playing indicator with animated equalizer bars
- 📱 **Scannable design**: Optimized for long lists and search results

## Usage

### Basic Implementation

```dart
import 'package:your_app/widgets/media_items/index.dart';

// Grid View
MediaGridCard(
  imagePath: 'https://example.com/song-artwork.jpg',
  songTitle: 'Save Your Tears',
  artistName: 'The Weeknd',
  onTap: () => playSong(),
  sharedPreThemeData: yourThemeData,
  isFavorite: true,
  isPlaying: false,
)

// List View
MediaListCard(
  imagePath: 'https://example.com/song-artwork.jpg',
  songTitle: 'Save Your Tears',
  artistName: 'The Weeknd',
  onTap: () => playSong(),
  sharedPreThemeData: yourThemeData,
  isFavorite: true,
  isPlaying: false,
)
```

### Context Menu Integration

```dart
MediaGridCard(
  // ... basic properties
  onPlay: () => playNow(),
  onDownload: () => downloadSong(),
  onAddToPlaylist: () => showPlaylistDialog(),
  onShare: () => shareSong(),
  onFavorite: () => toggleFavorite(),
)
```

### Integration with AllCategoryByName

The widgets are already integrated into `AllCategoryByName.dart`. The screen automatically switches between grid and list views:

```dart
// In _buildModernCard method
return _isGridView
    ? MediaGridCard(
        imagePath: imageUrl,
        songTitle: displayName,
        artistName: artistName,
        onTap: () => _handleItemNavigation(post),
        sharedPreThemeData: sharedPreThemeData,
      )
    : MediaListCard(
        imagePath: imageUrl,
        songTitle: displayName,
        artistName: artistName,
        onTap: () => _handleItemNavigation(post),
        sharedPreThemeData: sharedPreThemeData,
      );
```

## Properties

### MediaGridCard

| Property             | Type          | Required | Description                              |
| -------------------- | ------------- | -------- | ---------------------------------------- |
| `imagePath`          | String        | ✅       | URL or path to the song/album artwork    |
| `songTitle`          | String        | ✅       | Primary title of the song                |
| `artistName`         | String        | ✅       | Artist or subtitle text                  |
| `onTap`              | VoidCallback  | ✅       | Main tap action (usually play song)      |
| `sharedPreThemeData` | ModelTheme    | ✅       | Theme configuration                      |
| `width`              | double        | ❌       | Card width (default: 150)                |
| `height`             | double        | ❌       | Card height (default: 200)               |
| `isFavorite`         | bool          | ❌       | Show favorite indicator (default: false) |
| `isPlaying`          | bool          | ❌       | Show playing state (default: false)      |
| `onPlay`             | VoidCallback? | ❌       | Context menu play action                 |
| `onDownload`         | VoidCallback? | ❌       | Context menu download action             |
| `onAddToPlaylist`    | VoidCallback? | ❌       | Context menu add to playlist action      |
| `onShare`            | VoidCallback? | ❌       | Context menu share action                |
| `onFavorite`         | VoidCallback? | ❌       | Context menu favorite action             |

### MediaListCard

| Property              | Type          | Required | Description                              |
| --------------------- | ------------- | -------- | ---------------------------------------- |
| `imagePath`           | String        | ✅       | URL or path to the song/album artwork    |
| `songTitle`           | String        | ✅       | Primary title of the song                |
| `artistName`          | String        | ✅       | Artist or subtitle text                  |
| `onTap`               | VoidCallback  | ✅       | Main tap action (usually play song)      |
| `sharedPreThemeData`  | ModelTheme    | ✅       | Theme configuration                      |
| `height`              | double        | ❌       | Row height (default: 70)                 |
| `isFavorite`          | bool          | ❌       | Show favorite indicator (default: false) |
| `isPlaying`           | bool          | ❌       | Show playing state (default: false)      |
| `showNavigationArrow` | bool          | ❌       | Show right chevron (default: true)       |
| `onPlay`              | VoidCallback? | ❌       | Context menu play action                 |
| `onDownload`          | VoidCallback? | ❌       | Context menu download action             |
| `onAddToPlaylist`     | VoidCallback? | ❌       | Context menu add to playlist action      |
| `onShare`             | VoidCallback? | ❌       | Context menu share action                |
| `onFavorite`          | VoidCallback? | ❌       | Context menu favorite action             |

## Animation States

### Playing Indicators

**Grid View**:

- Subtle scaling animation (0.8x to 1.0x scale)
- Gradient overlay with play/pause icon
- Continuous loop while playing

**List View**:

- Animated equalizer bars (3 bars with offset timing)
- Thumbnail scaling effect
- Different animation curves for visual variety

### Interaction States

- **Tap Down**: 95% scale for grid, 98% scale for list
- **Loading**: Circular progress indicator during image load
- **Error**: Fallback music note icon with appropriate styling

## Theming

The widgets respect your app's existing theme system:

- Colors: Uses `appColors()` for consistent color palette
- Typography: Uses 'Poppins' font family with appropriate weights
- Spacing: Uses `AppSizes` for consistent spacing throughout
- Border Radius: Uses `AppSizes.borderRadius` for consistent corner styling

## Demo

Check out `media_cards_demo.dart` for a complete demonstration of both widgets with sample data and interactive features.

## Best Practices

1. **Image Performance**: Use appropriate image sizes and caching for optimal performance
2. **Loading States**: Always handle loading and error states for network images
3. **Accessibility**: Consider adding semantic labels for screen readers
4. **Context Menus**: Implement appropriate context menu actions for your use case
5. **State Management**: Use proper state management for favorite and playing states
6. **Network Handling**: Implement proper error handling for network images

## File Structure

```
lib/widgets/media_items/
├── index.dart                 # Export file
├── media_grid_card.dart       # Grid view card widget
├── media_list_card.dart       # List view card widget
├── media_cards_demo.dart      # Demo implementation
└── README.md                  # This documentation
```
