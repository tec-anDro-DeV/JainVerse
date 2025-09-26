import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/UI/CreatePlaylist.dart';

/// Bottom sheet widget for song options (favorite, playlist, share, download)
class SongOptionsBottomSheet extends StatelessWidget {
  final String songId;
  final String tag;
  final String price;
  final String slug;
  final String currentAmount;
  final String currencySym;
  final bool allowDownload;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;

  const SongOptionsBottomSheet({
    super.key,
    required this.songId,
    required this.tag,
    required this.price,
    required this.slug,
    required this.currentAmount,
    required this.currencySym,
    required this.allowDownload,
    required this.onFavoriteToggle,
    this.onShare,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildFavoriteOption(context),
            _buildPlaylistOption(context),
            _buildShareOption(context),
            _buildDownloadOption(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteOption(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      child: InkResponse(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              alignment: Alignment.centerLeft,
              width: 68,
              child: Image.asset(
                'assets/icons/fav2.png',
                color: appColors().primaryColorApp,
              ),
            ),
            Container(
              width: 200,
              alignment: Alignment.centerLeft,
              child: Text(
                'Add/Remove to favorite',
                style: TextStyle(fontSize: 18, color: appColors().colorText),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          onFavoriteToggle();
        },
      ),
    );
  }

  Widget _buildPlaylistOption(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      child: InkResponse(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreatePlaylist(songId)),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/icons/addto.png',
                color: appColors().primaryColorApp,
              ),
            ),
            Container(
              width: 200,
              alignment: Alignment.centerLeft,
              child: Text(
                'Add to playlist',
                style: TextStyle(fontSize: 19, color: appColors().colorText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      child: InkResponse(
        onTap: () {
          Navigator.pop(context);
          onShare?.call();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/icons/share.png',
                color: appColors().primaryColorApp,
              ),
            ),
            Container(
              width: 200,
              alignment: Alignment.centerLeft,
              child: Text(
                'Share Song',
                style: TextStyle(fontSize: 19, color: appColors().colorText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOption(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      child: InkResponse(
        onTap: () {
          Navigator.pop(context);
          onDownload?.call();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/icons/download.png',
                color: appColors().primaryColorApp,
              ),
            ),
            Container(
              width: 200,
              alignment: Alignment.centerLeft,
              child: Text(
                currentAmount.isEmpty ? 'Download Now' : 'Purchase & Download',
                style: TextStyle(fontSize: 18, color: appColors().colorText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static method to show the bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String songId,
    required String tag,
    required String price,
    required String slug,
    required String currentAmount,
    required String currencySym,
    required bool allowDownload,
    required VoidCallback onFavoriteToggle,
    VoidCallback? onShare,
    VoidCallback? onDownload,
  }) {
    return showModalBottomSheet(
      barrierColor: const Color(0x00eae5e5),
      context: context,
      backgroundColor: appColors().colorBackground,
      builder: (ctx) {
        return SongOptionsBottomSheet(
          songId: songId,
          tag: tag,
          price: price,
          slug: slug,
          currentAmount: currentAmount,
          currencySym: currencySym,
          allowDownload: allowDownload,
          onFavoriteToggle: onFavoriteToggle,
          onShare: onShare,
          onDownload: onDownload,
        );
      },
    );
  }
}
