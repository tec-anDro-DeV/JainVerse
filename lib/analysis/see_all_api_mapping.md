# See All API Mapping and Data Expectations

## How "See All" Works

When user taps "See All" from `MusicSectionHeader`, it navigates to `AllCategoryByName` which calls `CatSubcatMusicPresenter().getMusicCategory()`

## API Endpoint Used for All "See All" Sections

- **Base URL**: `${AppConstant.BaseUrl}${AppConstant.API_GETMUSIC}`
- **Full URL**: `http://143.244.213.49/heargod-staging/public/api/getMusic`
- **Method**: POST
- **Headers**:
  - `Accept: application/json`
  - `authorization: Bearer {token}`

## Parameters for Each Section

### 1. Featured Playlist

- **type**: "Featured Albums"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 2. Featured Songs

- **type**: "Featured Songs"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 3. New Albums and EP's

- **type**: "New Albums"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 4. New Songs

- **type**: "New Songs"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 5. Popular Artist

- **type**: "Trending Artists"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 6. Popular Songs

- **type**: "Trending Songs"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 7. Popular Albums

- **type**: "Trending Albums"
- **page**: 1 (increments for pagination)
- **limit**: 30

### 8. Trending Genres

- **type**: "Trending Genres"
- **page**: 1 (increments for pagination)
- **limit**: 30

## Expected Response Data Structure

All sections expect the same response structure following `ModelAllCat`:

```json
{
  "status": true,
  "msg": "Success message",
  "imagePath": "images/audio/thumb/",
  "sub_category": [
    {
      "id": 1,
      "name": "Item Name",
      "slug": "item-slug",
      "image": "item-image.jpg",
      "is_featured": 0,
      "is_trending": 1,
      "is_recommended": 0
    }
  ]
}
```

## UI Data Expectations

### Grid Layout

- **Cross Axis Count**: 2 items per row
- **Cross Axis Spacing**: 5.0
- **Main Axis Spacing**: 5.0
- **Item Width**: 163
- **Item Height**: 120
- **Text Width**: 135 (for title below image)

### Navigation Behavior Based on Type

1. **Albums/Artists/Genres**: Navigate to `MusicList`
   - Parameters: `(audioHandler, id, type, name)`
2. **Songs/Other**: Navigate to `Music`
   - Parameters: `(audioHandler, id, type, [], "", 0, false, '')`

### Image Handling

- **Image URL Format**: `${AppConstant.ImageUrl}${imagePath}${item.image}`
- **Base Image URL**: `http://143.244.213.49/heargod-staging/public/`
- **Common Image Paths**:
  - Audio thumbnails: `images/audio/thumb/`
  - Playlist images: `images/playlist/`
  - Album covers: `images/audio/thumb/`
- **URL Construction Issues**:
  - **CRITICAL**: Server returns `imagePath` values inconsistently
  - Some paths missing `/public/` prefix: `images/playlist/` → should be `public/images/playlist/`
  - Results in 404 errors: `heargod-staging/images/playlist/` instead of `heargod-staging/public/images/playlist/`
- **URL Normalization Required**:
  - Always ensure `/public/` is included in the final URL
  - Check if `imagePath` already contains `public/`, if not prepend it
  - Use helper function to normalize image URLs consistently
- **Error Handling Required**:
  - Implement `errorBuilder` for NetworkImage widgets
  - Fallback to placeholder on 404 errors
  - Use `CachedNetworkImage` with error handling instead of raw NetworkImage
- **Placeholder**: `assets/images/song_placeholder.png` (when image is empty or fails to load)
- **Fit**: `BoxFit.cover`
- **Alignment**: `Alignment.topCenter`

### URL Normalization Function

```dart
// Helper function to normalize image URLs
static String normalizeImageUrl(String imagePath, String imageFileName) {
  if (imageFileName.isEmpty) return '';

  // Ensure imagePath starts with 'public/' if it doesn't already
  String normalizedPath = imagePath;
  if (!normalizedPath.startsWith('public/') && !normalizedPath.contains('public/')) {
    normalizedPath = 'public/$imagePath';
  }

  // Ensure path ends with '/'
  if (!normalizedPath.endsWith('/')) {
    normalizedPath = '$normalizedPath/';
  }

  return '${AppConstant.SiteUrl}$normalizedPath$imageFileName';
}
```

### Recommended Image Widget Implementation

```dart
// Use CachedNetworkImage with error handling and URL normalization
CachedNetworkImage(
  imageUrl: normalizeImageUrl(imagePath, item.image),
  fit: BoxFit.cover,
  alignment: Alignment.topCenter,
  placeholder: (context, url) => Image.asset('assets/images/song_placeholder.png'),
  errorWidget: (context, url, error) => Image.asset('assets/images/song_placeholder.png'),
)

// Or use NetworkImage with errorBuilder and URL normalization
Image.network(
  normalizeImageUrl(imagePath, item.image),
  fit: BoxFit.cover,
  alignment: Alignment.topCenter,
  errorBuilder: (context, error, stackTrace) {
    return Image.asset('assets/images/song_placeholder.png');
  },
)
```

### Pagination

- **Items per request**: 30
- **Trigger point**: 3 items before end of list
- **Auto-load**: When user scrolls near bottom
- **Pull-to-refresh**: Resets to page 1

### Error Handling

- **Connection timeout**: Show retry dialog
- **Empty response**: Show "No data" message
- **Network error**: Show error dialog with retry option
- **Image 404 errors**: Automatically fallback to placeholder image
- **Loading states**: CircularProgressIndicator

### Text Styling

- **Font size**: 12
- **Max lines**: 1
- **Text align**: Center
- **Color**: Theme-based (AppSettings.colorText or appColors().colorText)
- **Overflow**: Handled by maxLines

## Additional Notes

- All requests use FormData encoding
- Pagination starts from page 1
- Response is parsed as `ModelAllCat.fromJson()`
- Images are cached and loaded via NetworkImage
- Error states show placeholder with retry functionality
