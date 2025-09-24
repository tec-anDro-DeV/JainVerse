class ModelTheme {
  String status;
  String msg;
  String themeName;
  final String themeColorFont;
  final String themeImageBack;
  final String proOrFree;

  ModelTheme(this.status, this.msg, this.themeName, this.themeColorFont,
      this.themeImageBack, this.proOrFree);

  Map toJson() => {
        'status': status,
        'msg': msg,
        'themeName': themeName,
        'themeColorFont': themeColorFont,
        'themeImageBack': themeImageBack,
        'proOrFree': proOrFree,
      };

  factory ModelTheme.fromJson(Map<dynamic, dynamic> json) {
    return ModelTheme(
      json['status'],
      json['msg'],
      json['themeName'],
      json['themeColorFont'],
      json['themeImageBack'],
      json['proOrFree'],
    );
  }
}
