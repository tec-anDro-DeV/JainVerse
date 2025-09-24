import 'ModelMusicList.dart';

/// Model for station creation API response
class ModelStationResponse {
  bool status;
  String msg;
  String imagePath;
  String audioPath;
  List<DataMusic> data;

  ModelStationResponse(
    this.status,
    this.msg,
    this.data,
    this.imagePath,
    this.audioPath,
  );

  factory ModelStationResponse.fromJson(Map<String, dynamic> json) {
    List<DataMusic> songs = [];
    if (json["data"] != null && json["data"] is List) {
      songs = List<DataMusic>.from(
        json["data"].map((x) => DataMusic.fromJson(x)),
      );
    }

    return ModelStationResponse(
      json['status'] ?? false,
      json['msg'] ?? '',
      songs,
      json['imagePath'] ?? '',
      json['audioPath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'msg': msg,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'data': data.map((x) => x.toJson()).toList(),
    };
  }
}
