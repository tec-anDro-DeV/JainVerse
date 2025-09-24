class ModelPlanList {
  bool status;
  String msg;

  List<DataPlan> data;

  ModelPlanList(this.status, this.msg, this.data);

  factory ModelPlanList.fromJson(Map<String, dynamic> json) {
    List<DataPlan> d = [];
    if (json["data"] != null && json["data"] is List) {
      d = List<DataPlan>.from(json["data"].map((x) => DataPlan.fromJson(x)));
    }
    return ModelPlanList(json['status'] ?? false, json['msg'] ?? '', d);
  }
}

class DataPlan {
  CurrentPlanData current_plan;
  List<SubData> all_plans;

  DataPlan(this.current_plan, this.all_plans);

  factory DataPlan.fromJson(Map<String, dynamic> json) {
    List<SubData> d = [];
    if (json["all_plans"] != null && json["all_plans"] is List) {
      d = List<SubData>.from(json["all_plans"].map((x) => SubData.fromJson(x)));
    }

    return DataPlan(CurrentPlanData.fromJson(json['current_plan'] ?? {}), d);
  }
}

class CurrentPlanData {
  int id = 0;
  String image = '';
  String plan_name = '';
  String plan_amount = '';
  int is_month_days = 0;
  int validity = 0;
  int is_download = 0;
  int show_advertisement = 0;
  int status = 0;
  String description = "";
  String created_at = '';
  String updated_at = '';

  CurrentPlanData(
    this.id,
    this.image,
    this.plan_name,
    this.plan_amount,
    this.is_month_days,
    this.validity,
    this.is_download,

    this.show_advertisement,
    this.status,
    this.description,
    this.created_at,
    this.updated_at,
  );

  factory CurrentPlanData.fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      return CurrentPlanData(
        0,
        '',
        'No Plan Available',
        '',
        0,
        0,
        0,
        1,
        0,
        '',
        '',
        '',
      );
    } else {
      return CurrentPlanData(
        json['id'] ?? 0,
        json['image'] ?? '',
        json['plan_name'] ?? '',
        json['plan_amount'] ?? '',
        json['is_month_days'] ?? 0,
        json['validity'] ?? 0,
        json['is_download'] ?? 0,
        json['show_advertisement'] ?? 0,
        json['status'] ?? 0,
        json['description'] ?? '',
        json['created_at'] ?? '',
        json['updated_at'] ?? '',
      );
    }
  }
}

class SubData {
  int id;
  String image = "";
  String plan_name = "";
  String plan_amount;

  int is_month_days;

  int validity;

  int is_download;

  int show_advertisement;

  int status;

  String description = "";

  String created_at = "";
  String updated_at = "";
  String product_id = "";
  String in_app_purchase = "";

  SubData(
    this.id,
    this.image,
    this.plan_name,
    this.plan_amount,
    this.is_month_days,
    this.validity,
    this.is_download,
    this.show_advertisement,
    this.status,
    this.description,
    this.created_at,
    this.updated_at,
    this.product_id,
    this.in_app_purchase,
  );

  factory SubData.fromJson(Map<String, dynamic> json) {
    return SubData(
      json['id'] ?? 0,
      json['image'] ?? '',
      json['plan_name'] ?? '',
      json['plan_amount'] ?? '',
      json['is_month_days'] ?? 0,
      json['validity'] ?? 0,
      json['is_download'] ?? 0,
      json['show_advertisement'] ?? 0,
      json['status'] ?? 0,
      json['description'] ?? '',
      json['created_at'] ?? '',
      json['updated_at'] ?? '',
      json['product_id'] ?? '',
      json['in_app_purchase'] ?? '',
    );
  }
}
