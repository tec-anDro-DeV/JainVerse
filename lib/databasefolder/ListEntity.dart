import 'package:floor/floor.dart';

@entity
class ListEntity {
  @primaryKey
  final String AudioId;

  final String userId;
  final String id;
  final String name;
  final String url;

  final String image;
  final String duration;
  final String artistname;

  ListEntity(this.AudioId, this.userId, this.duration, this.id, this.name,
      this.url, this.image, this.artistname);
}
