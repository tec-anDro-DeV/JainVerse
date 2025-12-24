import 'package:flutter/foundation.dart';
import 'package:jainverse/Model/song_model.dart';
import 'package:jainverse/Model/video_model.dart';
import 'package:jainverse/videoplayer/managers/subscription_state_manager.dart';
import 'package:jainverse/repositories/channel_detail_repository.dart';

class ChannelDetailState {
  final ChannelDetailInfo? channel;
  final List<VideoModel> videos;
  final List<SongModel> songs;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  const ChannelDetailState({
    this.channel,
    this.videos = const [],
    this.songs = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  bool get hasContent =>
      channel != null || videos.isNotEmpty || songs.isNotEmpty;

  ChannelDetailState copyWith({
    ChannelDetailInfo? channel,
    List<VideoModel>? videos,
    List<SongModel>? songs,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
  }) {
    return ChannelDetailState(
      channel: channel ?? this.channel,
      videos: videos ?? this.videos,
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChannelDetailPresenter extends ChangeNotifier {
  ChannelDetailPresenter({ChannelDetailRepository? repository})
    : _repository = repository ?? ChannelDetailRepository();

  final ChannelDetailRepository _repository;
  ChannelDetailState _state = const ChannelDetailState(isLoading: true);
  bool _isFetching = false;
  bool _disposed = false;

  ChannelDetailState get state => _state;

  Future<void> fetchChannelDetail(int channelId) async {
    if (_isFetching) return;
    _isFetching = true;

    final bool showInitialLoader = !_state.hasContent;
    _update(
      _state.copyWith(
        isLoading: showInitialLoader,
        isRefreshing: !showInitialLoader,
        clearError: showInitialLoader,
      ),
    );

    try {
      final payload = await _repository.fetchChannelDetail(channelId);
      _update(
        ChannelDetailState(
          channel: payload.channel,
          videos: payload.videos,
          songs: payload.songs,
          isLoading: false,
          isRefreshing: false,
          error: null,
        ),
      );
      final channelInfo = payload.channel;
      if (channelInfo != null) {
        SubscriptionStateManager().updateSubscriptionState(
          channelInfo.id,
          channelInfo.isSubscribed,
        );
      }
    } catch (error) {
      _update(
        _state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: error.toString(),
        ),
      );
    } finally {
      _isFetching = false;
    }
  }

  void updateSubscription(bool subscribed) {
    final current = _state.channel;
    if (current == null) return;
    // Update subscribersCount optimistically so UI reflects the change immediately.
    final int currentCount = current.subscribersCount;
    final int nextCount = subscribed
        ? currentCount + 1
        : (currentCount - 1).clamp(0, currentCount);

    _update(
      _state.copyWith(
        channel: current.copyWith(
          isSubscribed: subscribed,
          subscribersCount: nextCount,
        ),
      ),
    );
  }

  void _update(ChannelDetailState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
