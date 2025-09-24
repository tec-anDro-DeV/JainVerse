class ModelHomePage {
  late final String cat;
  late List<Data> data;

  ModelHomePage(this.cat, this.data);
}

class Data {
  String SubCatName = "";
  String SubCatImage = "";

  Data(this.SubCatName, this.SubCatImage);
}
