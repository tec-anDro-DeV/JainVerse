class CountryModel {
  bool status;
  String msg;
  List<Country> data;

  CountryModel({required this.status, required this.msg, required this.data});

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(
      status: json['status'] ?? false,
      msg: json['msg'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => Country.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class Country {
  int id;
  String iso;
  String name;
  String nicename;
  String iso3;
  int numcode;
  int phonecode;

  Country({
    required this.id,
    required this.iso,
    required this.name,
    required this.nicename,
    required this.iso3,
    required this.numcode,
    required this.phonecode,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] ?? 0,
      iso: json['iso'] ?? '',
      name: json['name'] ?? '',
      nicename: json['nicename'] ?? '',
      iso3: json['iso3'] ?? '',
      numcode: json['numcode'] ?? 0,
      phonecode: json['phonecode'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'iso': iso,
      'name': name,
      'nicename': nicename,
      'iso3': iso3,
      'numcode': numcode,
      'phonecode': phonecode,
    };
  }

  @override
  String toString() {
    return nicename; // Display the nice name in dropdowns
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Country && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
