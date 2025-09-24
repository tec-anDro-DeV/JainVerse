import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/CacheManager.dart';
import 'package:jainverse/widgets/musicplayer/three_dot_options_menu.dart';
import 'package:jainverse/services/favorite_service.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

class RecentSearchCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String pathImage;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final int index;

  const RecentSearchCard({
    super.key,
    required this.item,
    required this.pathImage,
    required this.onTap,
    this.onRemove,
    required this.index,
  });

  @override
  State<RecentSearchCard> createState() => _RecentSearchCardState();
}

class _RecentSearchCardState extends State<RecentSearchCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0.5,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10.w),
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.all(10.w),
            child: Row(
              children: [
                // Album art
                _buildAlbumArt(),
                SizedBox(width: 12.w),

                // Song info
                _buildSongInfo(),

                // Three-dot menu button
                _buildOptionsButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7.w),
      child: SizedBox(
        width: 56.w,
        height: 56.w,
        child: Image.network(
          _getImageUrl(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/song_placeholder.png',
              fit: BoxFit.cover,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: appColors().gray[100],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: appColors().gray[300],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSongInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.item['audio_title'] ?? 'Unknown Title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black87,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.w),
          Text(
            widget.item['artists_name'] ?? 'Unknown Artist',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              color: appColors().gray[500],
              fontFamily: 'Poppins',
            ),
          ),
          SizedBox(height: 2.w),
          Text(
            widget.item['audio_duration']?.toString() ?? '',
            style: TextStyle(
              fontSize: 11.sp,
              color: appColors().gray[400],
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsButton() {
    return ThreeDotMenuButton(
      songId: widget.item['id'].toString(),
      title: widget.item['audio_title'] ?? 'Unknown Title',
      artist: widget.item['artists_name'] ?? 'Unknown Artist',
      songImage: widget.item['image'],
      isFavorite: widget.item['favourite'] == "1",
      onFavoriteToggle: _toggleFavorite,
      onRemoveFromRecent: _removeFromRecent,
      showRemoveFromRecent: true,
      useBottomSheet: false, // Use dialog style for better positioning
      iconColor: appColors().gray[500],
      iconSize: 18.w,
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      final favoriteService = FavoriteService();
      final currentStatus = widget.item['favourite']?.toString() ?? '0';
      final newStatus = await favoriteService.toggleFavorite(
        widget.item['id'].toString(),
        currentStatus,
      );

      // Update the local state
      setState(() {
        widget.item['favourite'] = newStatus;
      });
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<void> _removeFromRecent() async {
    try {
      await CacheManager.removeRecentSearch(widget.item['id'].toString());
      widget.onRemove?.call();
    } catch (e) {
      debugPrint('Error removing recent search: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove item'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getImageUrl() {
    // First try to get from cached data with path
    final cachedImagePath = widget.item['imagePath'] ?? '';
    final imageUrl = widget.item['image'] ?? '';

    if (cachedImagePath.isNotEmpty && imageUrl.isNotEmpty) {
      return AppConstant.ImageUrl + cachedImagePath + imageUrl;
    }

    // Fallback to using provided pathImage
    if (widget.pathImage.isNotEmpty && imageUrl.isNotEmpty) {
      return AppConstant.ImageUrl + widget.pathImage + imageUrl;
    }

    // Last fallback - direct image URL
    if (imageUrl.isNotEmpty) {
      return AppConstant.ImageUrl + imageUrl;
    }

    return '';
  }
}
