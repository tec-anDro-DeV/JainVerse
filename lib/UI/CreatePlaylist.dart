import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jainverse/Model/ModelPlayList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/widgets/playlist/playlist_service.dart';
import 'package:jainverse/Presenter/PlaylistMusicPresenter.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/utils/performance_debouncer.dart';
import 'playList_screen.dart';

// removed unused we_slide import
import 'MainNavigation.dart';

String idMusic = '';

class CreatePlaylist extends StatefulWidget {
  CreatePlaylist(String ids, {super.key}) {
    idMusic = ids;
  }

  @override
  state createState() {
    return state();
  }
}

class state extends State {
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  SharedPref sharePrefs = SharedPref();
  String token = '';
  TextEditingController nameController = TextEditingController();
  late UserModel model;
  String checkFun = "Create";
  String updateId = '', updateName = '';
  bool showLoader = false;
  // ...existing code... (we removed unused slide panel fields)

  Future<bool> isDelete(BuildContext context, String PlayListId) async {
    return (await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  'Are you sure want to delete it?',
                  style: TextStyle(
                    fontSize: 16,
                    color: appColors().colorTextHead,
                  ),
                ),
                backgroundColor: appColors().colorBackEditText,
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.pop(context, false), // passing false
                    child: Text(
                      'No',
                      style: TextStyle(
                        fontSize: 16,
                        color: appColors().colorTextHead,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Fluttertoast.showToast(
                        msg: 'Processing please wait..',
                        toastLength: Toast.LENGTH_SHORT,
                        timeInSecForIosWeb: 1,
                        backgroundColor: appColors().black,
                        textColor: appColors().colorBackground,
                        fontSize: 14.0,
                      );
                      Navigator.pop(context, false);
                      await PlaylistMusicPresenter().removePlaylist(
                        PlayListId,
                        token,
                      );

                      setState(() {});
                    }, // passing true
                    child: Text(
                      'Yes',
                      style: TextStyle(
                        fontSize: 16,
                        color: appColors().colorTextHead,
                      ),
                    ),
                  ),
                ],
              ),
        )) ??
        false;
  }

  Future<void> createAPI(String tag) async {
    if (idMusic.isNotEmpty) {
      Fluttertoast.showToast(
        msg: 'Processing..',
        toastLength: Toast.LENGTH_SHORT,
        timeInSecForIosWeb: 1,
        backgroundColor: appColors().black,
        textColor: appColors().colorBackground,
        fontSize: 14.0,
      );
    }
    await PlaylistMusicPresenter().createPlaylist(
      "${model.data.id}",
      tag,
      token,
    );
    nameController.text = '';
    showLoader = false;
    if (idMusic.isEmpty) {
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  Future<void> updateAPI(
    String playlistname,
    String PlayListId,
    String token,
  ) async {
    await PlaylistMusicPresenter().updatePlaylist(
      playlistname,
      PlayListId,
      token,
    );
    nameController.text = '';
    checkFun = 'Create';
    showLoader = false;
    setState(() {});
  }

  Future<void> addMusicToPlayListAPI(String playListID) async {
    final service = PlaylistService();
    final success = await service.addSongToPlaylist(idMusic, playListID, '');

    nameController.text = '';

    // Navigate back to playlist screen only on success
    if (success) {
      PerformanceDebouncer.safePush(
        context,
        MaterialPageRoute(
          builder: (context) => const PlaylistScreen(),
          settings: const RouteSettings(
            arguments: 'book',
            name: '/create_playlist_to_playlist',
          ),
        ),
        navigationKey: 'create_playlist_to_playlist',
      );
    }
  }

  Future<dynamic> value() async {
    try {
      model = await sharePrefs.getUserData();
      token = await sharePrefs.getToken();
      sharedPreThemeData = await sharePrefs.getThemeData();
      setState(() {});
      return model;
    } on Exception {}
  }

  @override
  void initState() {
    super.initState();
    value();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: const BottomNavCustom().appBar("Create Playlist", context, 1),
        body: Stack(
          children: [
            // Main content
            Container(
              margin: const EdgeInsets.only(
                bottom: 70,
              ), // Space for mini player
              decoration: BoxDecoration(
                image: DecorationImage(
                  image:
                      (sharedPreThemeData.themeImageBack.isEmpty)
                          ? AssetImage(AppSettings.imageBackground)
                          : AssetImage(sharedPreThemeData.themeImageBack),
                  fit: BoxFit.fill,
                ),
              ),
              child: ListView(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 45,
                        alignment: Alignment.topCenter,
                        margin: const EdgeInsets.fromLTRB(0, 15.2, 2, 2),
                        child: Text(
                          'Playlist Update',
                          style: TextStyle(
                            fontSize: 20,
                            color:
                                (sharedPreThemeData.themeImageBack.isEmpty)
                                    ? Color(int.parse(AppSettings.colorText))
                                    : appColors().colorText,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        height: 45,
                        alignment: Alignment.topLeft,
                        margin: const EdgeInsets.fromLTRB(6, 9, 2, 2),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_outlined,
                            color:
                                (sharedPreThemeData.themeImageBack.isEmpty)
                                    ? Color(int.parse(AppSettings.colorText))
                                    : appColors().colorText,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 55,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    margin: const EdgeInsets.fromLTRB(22, 26, 22, 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColors().colorBackEditText,
                          appColors().colorBackEditText,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30.0),
                      border: Border.all(
                        width: 1,
                        color: appColors().colorHint,
                      ),
                    ),
                    child: TextField(
                      controller: nameController,
                      style: TextStyle(
                        color: appColors().colorText,
                        fontSize: 17.0,
                        fontFamily: 'Poppins',
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter Playlist name here..',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17.0,
                          color: appColors().colorHint,
                        ),
                        suffixIcon: Image.asset(
                          'assets/icons/pencil.png',
                          color: appColors().colorText,
                          height: 20,
                          width: 18,
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minHeight: 18,
                          minWidth: 8,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (showLoader)
                    Container(
                      margin: EdgeInsets.fromLTRB(0, 14, 0, 0),
                      width: 40,
                      child: SizedBox(
                        height: 35,
                        width: 30,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(
                            appColors().primaryColorApp,
                          ),
                          backgroundColor: appColors().colorHint,
                          strokeWidth: 3.5,
                        ),
                      ),
                    ),
                  if (!showLoader)
                    Container(
                      width: 200,
                      margin: const EdgeInsets.fromLTRB(80, 14, 80, 0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            appColors().PrimaryDarkColorApp,
                            appColors().primaryColorApp,
                            appColors().primaryColorApp,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      child: TextButton(
                        child: Text(
                          checkFun,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xffffffff),
                          ),
                        ),
                        onPressed:
                            () => {
                              FocusManager.instance.primaryFocus?.unfocus(),
                              if (checkFun.contains('Create'))
                                {
                                  if (nameController.text.isNotEmpty)
                                    {
                                      showLoader = true,
                                      setState(() {}),
                                      createAPI(nameController.text),
                                    }
                                  else
                                    {
                                      Fluttertoast.showToast(
                                        msg: 'Enter name to create playlist',
                                        toastLength: Toast.LENGTH_SHORT,
                                        timeInSecForIosWeb: 1,
                                        backgroundColor: appColors().black,
                                        textColor: appColors().colorBackground,
                                        fontSize: 14.0,
                                      ),
                                    },
                                }
                              else
                                {
                                  showLoader = true,
                                  setState(() {}),
                                  updateAPI(
                                    nameController.text,
                                    updateId,
                                    token,
                                  ),
                                },
                            },
                      ),
                    ),
                  if (checkFun.contains('Create'))
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 22, 12, 5),
                      child: Text(
                        'Select Playlist Below',
                        style: TextStyle(
                          fontSize: 19,
                          color:
                              (sharedPreThemeData.themeImageBack.isEmpty)
                                  ? Color(int.parse(AppSettings.colorText))
                                  : appColors().colorText,
                        ),
                      ),
                    ),
                  if (checkFun.contains('Create'))
                    if (!showLoader)
                      FutureBuilder<ModelPlayList>(
                        future: PlaylistMusicPresenter().getPlayList(token),
                        builder: (context, projectSnap) {
                          if (projectSnap.hasError) {
                            Fluttertoast.showToast(
                              msg: Resources.of(context).strings.tryAgain,
                              toastLength: Toast.LENGTH_SHORT,
                              timeInSecForIosWeb: 1,
                              backgroundColor: appColors().black,
                              textColor: appColors().colorBackground,
                              fontSize: 14.0,
                            );

                            return const Material(
                              // child: LanguageChoose(''),
                            );
                          } else {
                            if (projectSnap.hasData) {
                              ModelPlayList m = projectSnap.data!;
                              if (m.data.isEmpty) {
                                return Container(
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.fromLTRB(
                                    12,
                                    23,
                                    12,
                                    3,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 200,
                                        margin: const EdgeInsets.fromLTRB(
                                          18,
                                          60,
                                          18,
                                          23,
                                        ),
                                        child: Image.asset(
                                          'assets/images/placeholder.png',
                                        ),
                                      ),
                                      Text(
                                        'Nothing created!',
                                        style: TextStyle(
                                          color:
                                              (sharedPreThemeData
                                                      .themeImageBack
                                                      .isEmpty)
                                                  ? Color(
                                                    int.parse(
                                                      AppSettings.colorText,
                                                    ),
                                                  )
                                                  : appColors().colorText,
                                          fontFamily: 'Poppins',
                                          fontSize: 20.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return SizedBox(
                                height: MediaQuery.of(context).size.height,
                                child: ListView.builder(
                                  scrollDirection: Axis.vertical,
                                  itemCount: m.data.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.fromLTRB(
                                        12,
                                        3,
                                        12,
                                        3,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          InkResponse(
                                            child: Container(
                                              width: 200,
                                              margin: const EdgeInsets.fromLTRB(
                                                1,
                                                12,
                                                12,
                                                12,
                                              ),
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                m.data[index].playlist_name,
                                                textAlign: TextAlign.left,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  color: Color(
                                                    int.parse(
                                                      AppSettings.colorText,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            onTap: () {
                                              if (idMusic.isNotEmpty) {
                                                addMusicToPlayListAPI(
                                                  m.data[index].id.toString(),
                                                );
                                              }
                                            },
                                          ),
                                          InkResponse(
                                            onTap: () {
                                              checkFun = 'Update';
                                              updateName =
                                                  m.data[index].playlist_name
                                                      .toString();
                                              updateId =
                                                  m.data[index].id.toString();
                                              nameController.text =
                                                  m.data[index].playlist_name
                                                      .toString();
                                              setState(() {});
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.fromLTRB(
                                                12,
                                                12,
                                                1,
                                                12,
                                              ),
                                              child: Image.asset(
                                                'assets/icons/pencil.png',
                                                color: appColors().colorText,
                                                width: 17,
                                              ),
                                            ),
                                          ),
                                          InkResponse(
                                            child: Container(
                                              margin: const EdgeInsets.fromLTRB(
                                                1,
                                                12,
                                                12,
                                                12,
                                              ),
                                              height: 20,
                                              width: 20,
                                              child: Image.asset(
                                                'assets/icons/bin.png',
                                                color: appColors().colorText,
                                              ),
                                            ),
                                            onTap: () {
                                              isDelete(
                                                context,
                                                m.data[index].id.toString(),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            } else {
                              return Material(
                                type: MaterialType.transparency,
                                child: Container(
                                  height: 120,
                                  width: MediaQuery.of(context).size.width,
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.fromLTRB(
                                    10,
                                    220,
                                    10,
                                    0,
                                  ),
                                  color: appColors().colorBackEditText,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      SizedBox(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation(
                                            appColors().primaryColorApp,
                                          ),
                                          backgroundColor:
                                              appColors().colorHint,
                                          strokeWidth: 4.0,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.all(4),
                                        child: Text(
                                          Resources.of(
                                            context,
                                          ).strings.loadingPleaseWait,
                                          style: TextStyle(
                                            color: appColors().colorTextHead,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Resources {
  Resources();

  StringsLocalization get strings {
    // Keep simple language selection for now. Uses English by default.
    return EnglishStrings();
  }

  static Resources of(BuildContext context) {
    return Resources();
  }
}
