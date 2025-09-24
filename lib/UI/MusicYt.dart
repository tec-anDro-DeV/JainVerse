import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jainverse/Model/ModelMusicList.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:jainverse/utils/SharedPref.dart';

List<DataMusic> list = [];

class Music2 extends StatefulWidget {
  Music2(List<DataMusic> listMusic, {super.key}) {
    list = listMusic;
    debugPrint('[Music2] Constructor called with listMusic: $listMusic');
  }

  @override
  State<StatefulWidget> createState() {
    debugPrint('[Music2] createState called');
    return MusicState();
  }
}

class MusicState extends State {
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  SharedPref sharePrefs = SharedPref();
  late YoutubePlayerController _controller;
  bool _isControllerInitialized = false;

  Future<dynamic> value() async {
    debugPrint('[MusicState] value() called');
    sharedPreThemeData = await sharePrefs.getThemeData();
    debugPrint('[MusicState] Theme data loaded: $sharedPreThemeData');
  }

  void _initializeController() {
    if (!_isControllerInitialized) {
      String videoId = YoutubePlayer.convertUrlToId(list[0].audio)!;
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          hideControls: false,
          mute: false,
        ),
      );
      _isControllerInitialized = true;
      debugPrint('[MusicState] Controller initialized with videoId: $videoId');
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[MusicState] initState called');
    debugPrint('[MusicState] list[0].audio: ${list[0].audio}');
    _initializeController();
    value();
  }

  @override
  void dispose() {
    debugPrint('[MusicState] dispose called');
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[MusicState] build called');

    // Use LayoutBuilder instead of OrientationBuilder to avoid unnecessary rebuilds
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isLandscape = constraints.maxWidth > constraints.maxHeight;
        debugPrint(
          '[MusicState] LayoutBuilder: ${isLandscape ? 'landscape' : 'portrait'}',
        );

        // Only initialize controller if not already done
        if (!_isControllerInitialized) {
          _initializeController();
        }

        if (isLandscape) {
          debugPrint('[MusicState] Building landscape UI');
          return Scaffold(
            body: SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image:
                        (sharedPreThemeData.themeImageBack.isEmpty)
                            ? AssetImage(AppSettings.imageBackground)
                            : AssetImage(sharedPreThemeData.themeImageBack),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    ListView(
                      children: [
                        Container(
                          alignment: Alignment.topCenter,
                          child: Stack(
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height - 24,
                                child: YoutubePlayer(
                                  controller: _controller,
                                  showVideoProgressIndicator: true,
                                  onReady: () {
                                    debugPrint(
                                      '[MusicState] YoutubePlayer ready (landscape)',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          debugPrint('[MusicState] Building portrait UI');
          return Scaffold(
            appBar: AppBar(
              title: const Text("Playing Now"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_outlined),
                onPressed: () {
                  debugPrint('[MusicState] Back button pressed');
                  Navigator.of(context).pop();
                },
              ),
            ),
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
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: SafeArea(
                    child: ListView(
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.fromLTRB(0, 8, 0, 10),
                          child: YoutubePlayer(
                            controller: _controller,
                            showVideoProgressIndicator: true,
                            onReady: () {
                              debugPrint(
                                '[MusicState] YoutubePlayer ready (portrait)',
                              );
                            },
                          ),
                        ),
                        Text(
                          list[0].audio_title.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: appColors().colorTextHead,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          list[0].audio_slug.toString(),
                          textAlign: TextAlign.center,
                          maxLines: 10,
                          style: TextStyle(
                            fontSize: 14,
                            color: appColors().colorTextHead,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
