import 'package:audio_session/audio_session.dart';

import '../common/audio_logger.dart';

/// Handles AudioSession configuration and interruption wiring for the stack.
class AudioPlayerInitializer {
  const AudioPlayerInitializer();

  Future<void> configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
    await session.setActive(true);

    session.becomingNoisyEventStream.listen((_) {
      AudioLogger.log('[DEBUG][AudioPlayerInitializer] Becoming noisy event');
    });

    session.interruptionEventStream.listen((event) {
      AudioLogger.log(
        '[DEBUG][AudioPlayerInitializer] Interruption: ${event.type}',
      );
    });
  }
}
