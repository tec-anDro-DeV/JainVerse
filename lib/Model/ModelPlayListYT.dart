class ModelPlayListYT {
  List<Items> items;

  ModelPlayListYT(this.items);

  factory ModelPlayListYT.fromJson(Map<dynamic, dynamic> json) {
    List<Items> itemsList = [];
    if (json["items"] != null && json["items"] is List) {
      itemsList = List<Items>.from(json["items"].map((x) => Items.fromJson(x)));
    }
    return ModelPlayListYT(itemsList);
  }
}

class Items {
  Snippet snippet;

  Items(this.snippet);

  factory Items.fromJson(Map<dynamic, dynamic> json) {
    return Items(Snippet.fromJson(json['snippet'] ?? {}));
  }
}

class Snippet {
  String title;
  String description;
  Thumbnails thumbnails;
  ResourceId resourceId;

  Snippet(this.title, this.description, this.thumbnails, this.resourceId);

  factory Snippet.fromJson(Map<dynamic, dynamic> json) {
    return Snippet(
      json['title'] ?? '',
      json['description'] ?? '',
      Thumbnails.fromJson(json['thumbnails'] ?? {}),
      ResourceId.fromJson(json['resourceId'] ?? {}),
    );
  }
}

class ResourceId {
  String videoId;

  ResourceId(this.videoId);

  factory ResourceId.fromJson(Map<dynamic, dynamic> json) {
    return ResourceId(json['videoId'] ?? '');
  }
}

class Thumbnails {
  Medium medium;

  Thumbnails(this.medium);

  factory Thumbnails.fromJson(Map<dynamic, dynamic> json) {
    return Thumbnails(Medium.fromJson(json['medium'] ?? {}));
  }
}

class Medium {
  String url;
  int width;
  int height;

  Medium(this.url, this.width, this.height);

  factory Medium.fromJson(Map<dynamic, dynamic> json) {
    return Medium(json['url'] ?? '', json['width'] ?? 0, json['height'] ?? 0);
  }
}
