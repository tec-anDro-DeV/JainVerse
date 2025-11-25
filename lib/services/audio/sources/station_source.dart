import '../../../Model/ModelMusicList.dart';
import '../../../Presenter/StationPresenter.dart';
import '../../../utils/SharedPref.dart';
import '../common/audio_logger.dart';

class StationSourceResult {
  StationSourceResult({
    required this.songs,
    required this.imagePath,
    required this.audioPath,
    required this.contextId,
  });

  final List<DataMusic> songs;
  final String imagePath;
  final String audioPath;
  final String contextId;
}

/// Builds a list of songs that behave like a lightweight station (radio) queue
/// by calling the real station API and falling back safely when unavailable.
class StationSource {
  StationSource({StationPresenter? presenter, SharedPref? sharedPref})
    : _presenter = presenter ?? StationPresenter(),
      _sharedPref = sharedPref ?? SharedPref();

  final StationPresenter _presenter;
  final SharedPref _sharedPref;

  Future<StationSourceResult?> buildStationFromSeed(DataMusic seed) async {
    AudioLogger.log(
      '[DEBUG][StationSource] Building station for ${seed.audio_title}',
    );

    final token = await _sharedPref.getToken();
    if (token.isEmpty) {
      AudioLogger.log(
        '[WARN][StationSource] No auth token available for station request',
      );
      return null;
    }

    final response = await _presenter.createStation(seed.id.toString(), token);

    if (!response.status || response.data.isEmpty) {
      AudioLogger.log(
        '[WARN][StationSource] Station API returned empty response',
      );
      return null;
    }

    final orderedSongs = <DataMusic>[seed];
    for (final candidate in response.data) {
      if (candidate.id != seed.id) {
        orderedSongs.add(candidate);
      }
    }

    final imagePath = response.imagePath.isNotEmpty
        ? response.imagePath
        : 'images/audio/thumb/';
    final audioPath = response.audioPath.isNotEmpty
        ? response.audioPath
        : 'images/audio/';

    return StationSourceResult(
      songs: orderedSongs,
      imagePath: imagePath,
      audioPath: audioPath,
      contextId: 'station_${seed.id}',
    );
  }
}
