import 'package:flutter/foundation.dart';

import '../../controllers/download_controller.dart';
import '../../models/downloaded_music.dart';
import '../../services/audio/common/audio_logger.dart';

/// Keeps the audio stack informed about download completion/cancellation
/// so preloaded items can upgrade their source to a local file path.
class DownloadStateLinker {
  DownloadStateLinker(this._downloadController);

  final DownloadController _downloadController;
  VoidCallback? _listener;

  void start(void Function(List<DownloadedMusic>) onDownloads) {
    if (_listener != null) {
      _downloadController.removeListener(_listener!);
    }
    _listener = () {
      final downloads = _downloadController.downloadedTracks;
      AudioLogger.log(
        '[DEBUG][DownloadStateLinker] Downloads updated: ${downloads.length}',
      );
      onDownloads(downloads);
    };
    _downloadController.addListener(_listener!);
    _listener!.call();
  }

  void dispose() {
    if (_listener != null) {
      _downloadController.removeListener(_listener!);
      _listener = null;
    }
  }
}
