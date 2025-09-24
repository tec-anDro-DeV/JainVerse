import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/UI/CreatePlaylist.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';
import 'package:jainverse/utils/performance_debouncer.dart';
import 'package:jainverse/services/favorite_service.dart';

class SearchMusicCard extends StatelessWidget {
  final DataMusic item;
  final String pathImage;
  final VoidCallback onTap;
  final VoidCallback? onActionCompleted;

  const SearchMusicCard({
    super.key,
    required this.item,
    required this.pathImage,
    required this.onTap,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final GlobalKey buttonKey = GlobalKey();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSizes.paddingXS),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0.5.w,
            blurRadius: 4.w,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.w),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.w),
                  child: SizedBox(
                    width: 60.w,
                    height: 60.w,
                    child: Image.network(
                      AppConstant.ImageUrl + pathImage + item.image,
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
                              strokeWidth: 1.5.w,
                              color: appColors().primaryColorApp,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(width: 12.w),
                // Song info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.audio_title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSizes.fontNormal,
                          color: Colors.black87,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.w),
                      Text(
                        item.artists_name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSizes.fontSmall,
                          color: appColors().gray[500],
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 2.w),
                      Text(
                        item.audio_duration.trim(),
                        style: TextStyle(
                          fontSize: 12.w,
                          color: appColors().gray[400],
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),

                // Options button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: buttonKey,
                    borderRadius: BorderRadius.circular(20.w),
                    onTap: () => _showOptionsDialog(context, buttonKey),
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      child: Icon(
                        Icons.more_vert,
                        color: appColors().gray[500],
                        size: 20.w,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, GlobalKey buttonKey) {
    final RenderBox renderBox =
        buttonKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder:
          (context) => Stack(
            children: [
              // Invisible barrier to close dialog when tapping outside
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  color: Colors.transparent,
                ),
              ),
              // Positioned dialog below the three-dot button
              Positioned(
                left: position.dx - 130.w,
                top: position.dy + size.height + 4.w,
                child: Material(
                  elevation: 8.w,
                  borderRadius: BorderRadius.circular(12.w),
                  color: Colors.white,
                  child: Container(
                    width: 200.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.w),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10.w,
                          spreadRadius: 2.w,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildOptionItem(
                          context: context,
                          icon:
                              item.favourite == "1"
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                          text:
                              item.favourite == "1"
                                  ? 'Remove Favorite'
                                  : 'Add to Favorite',
                          iconColor:
                              item.favourite == "1"
                                  ? Colors.red
                                  : Colors.grey[600]!,
                          onTap: () async {
                            Navigator.pop(context);
                            await _toggleFavorite();
                          },
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        _buildOptionItem(
                          context: context,
                          icon: Icons.playlist_add,
                          text: 'Add to Playlist',
                          iconColor: Colors.grey[600]!,
                          onTap: () {
                            Navigator.pop(context);
                            PerformanceDebouncer.safePush(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        CreatePlaylist(item.id.toString()),
                                settings: const RouteSettings(
                                  name: '/search_card_to_create_playlist',
                                ),
                              ),
                              navigationKey: 'search_card_to_create_playlist',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.w, horizontal: 16.w),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: AppSizes.fontSmall,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      final favoriteService = FavoriteService();
      final newStatus = await favoriteService.toggleFavorite(
        item.id.toString(),
        item.favourite,
      );

      // Update the item's favorite status for immediate UI feedback
      item.favourite = newStatus;

      onActionCompleted?.call();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }
}
