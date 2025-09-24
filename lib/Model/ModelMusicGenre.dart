class ModelMusicGenre {
  bool status;
  String msg;
  String imagePath;
  List selectedGenre;
  List<Data> data;

  ModelMusicGenre(
    this.status,
    this.msg,
    this.imagePath,
    this.selectedGenre,
    this.data,
  );

  factory ModelMusicGenre.fromJson(Map<dynamic, dynamic> json) {
    List l = List.from(json['selectedGenre']);

    return ModelMusicGenre(
      json['status'],
      json['msg'],
      json['imagePath'],
      l,
      List<Data>.from(json["data"].map((x) => Data.fromJson(x))),
    );
  }
}

class Data {
  int id;

  String genre_name = "";
  String genre_slug = "";
  String image = "";

  int status;

  String created_at = "";
  String updated_at = "";

  Data(
    this.id,
    this.genre_name,
    this.genre_slug,
    this.image,
    this.status,
    this.created_at,
    this.updated_at,
  );

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      json['id'],
      json['genre_name'],
      json['genre_slug'],
      json['image'],
      json['status'],
      json['created_at'],
      json['updated_at'],
    );
  }
}
