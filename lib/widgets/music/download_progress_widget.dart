import 'package:flutter/material.dart';
import 'package:jainverse/ThemeMain/appColors.dart';

/// Download progress indicator widget for showing download status
class DownloadProgressWidget extends StatelessWidget {
  final String progressString;
  final String downloadStatus; // 'Not', 'Started', 'Done', 'Failed'

  const DownloadProgressWidget({
    super.key,
    required this.progressString,
    required this.downloadStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (downloadStatus.contains('Not')) {
      return const SizedBox.shrink();
    }

    return Container(
      height: _getHeight(),
      color: appColors().colorBackground,
      alignment: Alignment.center,
      child: _buildContent(),
    );
  }

  double _getHeight() {
    if (downloadStatus.contains('Started')) {
      return 75;
    } else {
      return 60;
    }
  }

  Widget _buildContent() {
    if (downloadStatus.contains('Started')) {
      return _buildDownloadingContent();
    } else if (downloadStatus.contains('Done')) {
      return _buildSuccessContent();
    } else {
      return _buildFailedContent();
    }
  }

  Widget _buildDownloadingContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          LinearProgressIndicator(color: appColors().primaryColorApp),
          const SizedBox(height: 12.5),
          Text(
            "Downloading : $progressString",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Text(
      'Downloaded Successfully!!',
      style: TextStyle(color: appColors().white),
    );
  }

  Widget _buildFailedContent() {
    return Text(
      'Failed Downloading !!',
      style: TextStyle(color: appColors().white),
    );
  }
}

/// Download status indicator for showing if a song is already downloaded
class DownloadStatusIndicator extends StatelessWidget {
  final bool isDownloaded;
  final VoidCallback? onTap;

  const DownloadStatusIndicator({
    super.key,
    required this.isDownloaded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      margin: const EdgeInsets.all(1),
      child: InkResponse(
        onTap: onTap,
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
                isDownloaded ? 'Downloaded !' : 'Download',
                style: TextStyle(fontSize: 18, color: appColors().colorText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular loading indicator with custom styling
class CustomLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const CustomLoadingIndicator({
    super.key,
    this.size = 50.0,
    this.color,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? appColors().primaryColorApp,
        ),
        strokeWidth: strokeWidth,
      ),
    );
  }
}
