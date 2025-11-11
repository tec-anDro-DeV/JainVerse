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
      // gender is nullable so pass null here
      userData = UserData(0, '', '', '', '', '', '', '', null, '');
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
  int? gender; // 0 = Male, 1 = Female; may be null if not set
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
    // Parse gender safely: API may return int or string
    int? parsedGender;
    try {
      if (json.containsKey('gender') && json['gender'] != null) {
        final g = json['gender'];
        if (g is int) {
          parsedGender = g;
        } else if (g is String) {
          parsedGender = int.tryParse(g);
        }
      }
    } catch (e) {
      parsedGender = null;
    }

    return UserData(
      json['id'] ?? 0,
      json['name'] ?? '',
      json['fname'] ?? '',
      json['lname'] ?? '',
      json['email'] ?? '',
      json['mobile'] ?? '',
      json['image'] ?? '',
      json['dob'] ?? '',
      parsedGender,
      json['artist_verify_status'] ?? '',
    );
  }
}

// Helper extension/utility on UserData
extension UserDataExtensions on UserData {
  /// Returns a readable display name: `name` if set, otherwise `fname + lname`.
  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    final full = '${fname.trim()} ${lname.trim()}'.trim();
    if (full.isNotEmpty) return full;
    return '';
  }

  /// Returns gender as int (0/1) or null if not available.
  int? get genderInt => gender;

  /// Returns gender as lowercase string for backward compatibility ('male','female')
  String get genderString {
    if (gender == null) return '';
    if (gender == 0) return 'male';
    if (gender == 1) return 'female';
    return '';
  }
}
