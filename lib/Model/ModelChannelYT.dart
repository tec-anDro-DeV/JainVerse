class ModelChannelYT {
  bool status;
  String msg;
  Data data;

  ModelChannelYT(this.status, this.msg, this.data);

  factory ModelChannelYT.fromJson(Map<dynamic, dynamic> json) {
    return ModelChannelYT(
      json['status'],
      json['msg'],
      Data.fromJson(json['data']),
    );
  }
}

class Data {
  List<Results> results;

  Data(this.results);

  factory Data.fromJson(Map<dynamic, dynamic> json) {
    return Data(
      List<Results>.from(json["results"].map((x) => Results.fromJson(x))),
    );
  }
}

class Results {
  String id;
  Snippet snippet;

  Results(this.id, this.snippet);

  factory Results.fromJson(Map<dynamic, dynamic> json) {
    return Results(json['id'], Snippet.fromJson(json['snippet']));
  }
}

class Snippet {
  String title;

  Snippet(this.title);

  factory Snippet.fromJson(Map<dynamic, dynamic> json) {
    return Snippet(json['title']);
  }
}
