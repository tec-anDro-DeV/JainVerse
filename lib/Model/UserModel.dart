class UserModel {
  bool status;
  String msg;
  String login_token;
  int appVersion;

  UserData data;
  int selectedLanguage; // Changed from List to int
  List favGenre;

  UserModel(
    this.status,
    this.msg,
    this.login_token,
    this.appVersion,
    this.data,
    this.selectedLanguage,
    this.favGenre,
  );

  factory UserModel.fromJson(Map<dynamic, dynamic> json) {
    // Parse selectedLanguage as int with proper error handling
    int languageId = 0;
    if (json['selectedLanguage'] != null) {
      if (json['selectedLanguage'] is int) {
        languageId = json['selectedLanguage'];
      } else if (json['selectedLanguage'] is String) {
        try {
          languageId = int.parse(json['selectedLanguage']);
        } catch (e) {
          languageId = 0;
        }
      } else if (json['selectedLanguage'] is List) {
        var list = json['selectedLanguage'] as List;
        if (list.isNotEmpty) {
          try {
            languageId = int.parse(list[0].toString());
          } catch (e) {
            languageId = 0;
          }
        }
      }
    }

    List g = json['favGenre'] != null ? List.from(json['favGenre']) : [];

    // Handle empty or null data object (e.g., during signup)
    UserData userData;
    if (json['data'] != null &&
        json['data'] is Map &&
        (json['data'] as Map).isNotEmpty) {
      userData = UserData.fromJson(Map<String, dynamic>.from(json['data']));
    } else {
      // Create empty UserData if data is null or empty
      userData = UserData(0, '', '', '', '', '', '', '', '', '');
    }

    return UserModel(
      json['status'] ?? false,
      json['msg'] ?? '',
      json['login_token'] ?? '',
      json['appVersion'] ?? 0,
      userData,
      languageId,
      g,
    );
  }
}

class UserData {
  int id;

  String name = "";
  String fname = "";
  String lname = "";
  String email = "";
  String mobile = "";
  String image = "";
  String dob = "";
  String gender = "";
  String artist_verify_status = "";

  UserData(
    this.id,
    this.name,
    this.fname,
    this.lname,
    this.email,
    this.mobile,
    this.image,
    this.dob,
    this.gender,
    this.artist_verify_status,
  );

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      json['id'] ?? 0,
      json['name'] ?? '',
      json['fname'] ?? '',
      json['lname'] ?? '',
      json['email'] ?? '',
      json['mobile'] ?? '',
      json['image'] ?? '',
      json['dob'] ?? '',
      json['gender'] ?? '',
      json['artist_verify_status'] ?? '',
    );
  }
}
