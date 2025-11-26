import 'song_model.dart';

/// Model for station creation API response
class ModelStationResponse {
  final bool status;
  final String msg;
  final List<SongModel> data;

  const ModelStationResponse(this.status, this.msg, this.data);

  factory ModelStationResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSongs = json['data'] is List
        ? json['data'] as List<dynamic>
        : const [];

    final songs = rawSongs
        .whereType<Map<String, dynamic>>()
        .map(SongModel.fromJson)
        .toList(growable: false);

    return ModelStationResponse(
      json['status'] ?? false,
      json['msg'] ?? '',
      songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'data': data.map((x) => x.toJson()).toList(),
    };
  }
}
