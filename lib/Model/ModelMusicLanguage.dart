class ModelMusicLanguage {
  bool status;
  String msg;
  String imagePath;
  List selectedLanguage;
  List<Data> data;

  ModelMusicLanguage(
    this.status,
    this.msg,
    this.imagePath,
    this.selectedLanguage,
    this.data,
  );

  factory ModelMusicLanguage.fromJson(Map<dynamic, dynamic> json) {
    List l = List.from(json['selectedLanguage']);

    return ModelMusicLanguage(
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

  String language_name = "";
  String language_code = "";
  String image = "";

  int status;

  String created_at = "";
  String updated_at = "";

  Data(
    this.id,
    this.language_name,
    this.language_code,
    this.image,
    this.status,
    this.created_at,
    this.updated_at,
  );

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      json['id'],
      json['language_name'],
      json['language_code'],
      json['image'],
      json['status'],
      json['created_at'],
      json['updated_at'],
    );
  }
}
