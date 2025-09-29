class ModelPurchaseInfo {
  bool status;
  String msg;
  Data data;

  ModelPurchaseInfo(this.status, this.msg, this.data);

  factory ModelPurchaseInfo.fromJson(Map<dynamic, dynamic> json) {
    return ModelPurchaseInfo(
      json['status'],
      json['msg'],
      Data.fromJson(json['data']),
    );
  }
}

class Data {
  List<AudioPurchaseHistory> audioPurchaseHistory;
  List<PlanPurchaseHistory> planPurchaseHistory;

  Data(this.audioPurchaseHistory, this.planPurchaseHistory);

  factory Data.fromJson(Map<dynamic, dynamic> json) {
    return Data(
      List<AudioPurchaseHistory>.from(
        json["audioPurchaseHistory"].map(
          (x) => AudioPurchaseHistory.fromJson(x),
        ),
      ),
      List<PlanPurchaseHistory>.from(
        json["planPurchaseHistory"].map((x) => PlanPurchaseHistory.fromJson(x)),
      ),
    );
  }
}

class AudioPurchaseHistory {
  String created_at;
  String order_id;
  String audio_data;
  String payment_data;

  AudioPurchaseHistory(
    this.created_at,
    this.order_id,
    this.audio_data,
    this.payment_data,
  );

  factory AudioPurchaseHistory.fromJson(Map<dynamic, dynamic> json) {
    return AudioPurchaseHistory(
      json['created_at'],
      json['order_id'],
      json['audio_data'],
      json['payment_data'],
    );
  }
}

class PlanPurchaseHistory {
  String created_at;
  String order_id;
  String plan_data;
  String payment_data;
  String expiry_date;

  PlanPurchaseHistory(
    this.created_at,
    this.order_id,
    this.plan_data,
    this.payment_data,
    this.expiry_date,
  );

  factory PlanPurchaseHistory.fromJson(Map<dynamic, dynamic> json) {
    return PlanPurchaseHistory(
      json['created_at'],
      json['order_id'],
      json['plan_data'],
      json['payment_data'],
      json['expiry_date'],
    );
  }
}
