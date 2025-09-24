class ModelAppInfo {
  bool status;
  String msg;
  List<Data> data;

  ModelAppInfo(this.status, this.msg, this.data);

  factory ModelAppInfo.fromJson(Map<dynamic, dynamic> json) {
    List<Data> dataList = [];
    if (json["data"] != null && json["data"] is List) {
      dataList = List<Data>.from(json["data"].map((x) => Data.fromJson(x)));
    }
    return ModelAppInfo(json['status'] ?? false, json['msg'] ?? '', dataList);
  }
}

class Data {
  int id;

  String title = "";
  String detail = "";

  Data(this.id, this.title, this.detail);

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(json['id'] ?? 0, json['title'] ?? '', json['detail'] ?? '');
  }
}
