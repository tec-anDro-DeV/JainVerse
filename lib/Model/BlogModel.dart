class BlogModel {
  bool status;
  String msg;
  Data data;

  BlogModel(this.status, this.msg, this.data);

  factory BlogModel.fromJson(Map<dynamic, dynamic> json) {
    return BlogModel(
      json['status'],
      json['msg'] ?? '',
      Data.fromJson(json['data']),
    );
  }
}

class Data {
  List<BlogCategory> blogCategories;
  List<Blogs> blogs;

  Data(this.blogCategories, this.blogs);

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      List<BlogCategory>.from(
        json["blogCategories"].map((x) => BlogCategory.fromJson(x)),
      ),
      List<Blogs>.from(json["blogs"].map((x) => Blogs.fromJson(x))),
    );
  }
}

class BlogCategory {
  int id;
  String title;
  String slug;

  BlogCategory({required this.id, required this.title, required this.slug});

  factory BlogCategory.fromJson(Map<String, dynamic> json) {
    return BlogCategory(
      id: json['id'],
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class Blogs {
  int id;
  String title;
  String blog_cat_name;
  int blog_cat_id;
  String detail;
  String image;
  String created_at;

  Blogs(
    this.id,
    this.title,
    this.detail,
    this.image,
    this.created_at,
    this.blog_cat_name,
    this.blog_cat_id,
  );

  factory Blogs.fromJson(Map<dynamic, dynamic> json) {
    return Blogs(
      json['id'] ?? 0,
      json['title'] ?? '',
      json['detail'] ?? '',
      json['image'] ?? '',
      json['created_at'] ?? '',
      '', // Will be populated later from categories
      json['blog_cat_id'] is int
          ? json['blog_cat_id']
          : int.tryParse(json['blog_cat_id']?.toString() ?? '') ?? 0,
    );
  }
}
