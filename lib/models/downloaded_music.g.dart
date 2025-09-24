// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_music.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadedMusicAdapter extends TypeAdapter<DownloadedMusic> {
  @override
  final int typeId = 1;

  @override
  DownloadedMusic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadedMusic(
      id: fields[0] as String,
      title: fields[1] as String,
      artist: fields[2] as String,
      albumName: fields[3] as String,
      imageUrl: fields[4] as String,
      audioUrl: fields[5] as String,
      duration: fields[6] as String,
      localAudioPath: fields[7] as String,
      localImagePath: fields[8] as String,
      downloadedAt: fields[9] as DateTime,
      fileSize: fields[10] as int,
      isDownloadComplete: fields[11] as bool,
      genre: fields[12] as String,
      language: fields[13] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadedMusic obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.albumName)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.audioUrl)
      ..writeByte(6)
      ..write(obj.duration)
      ..writeByte(7)
      ..write(obj.localAudioPath)
      ..writeByte(8)
      ..write(obj.localImagePath)
      ..writeByte(9)
      ..write(obj.downloadedAt)
      ..writeByte(10)
      ..write(obj.fileSize)
      ..writeByte(11)
      ..write(obj.isDownloadComplete)
      ..writeByte(12)
      ..write(obj.genre)
      ..writeByte(13)
      ..write(obj.language);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadedMusicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
