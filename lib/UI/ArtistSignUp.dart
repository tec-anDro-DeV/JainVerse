import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/main.dart';
import 'package:jainverse/UI/PrivacyPolicy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:jainverse/Model/ModelSettings.dart';
import 'package:jainverse/Model/ModelTheme.dart';
import 'package:jainverse/Model/UserModel.dart';
import 'package:jainverse/Presenter/ProfilePresenter.dart';
import 'package:jainverse/utils/AppConstant.dart';
import 'package:jainverse/utils/SharedPref.dart';
import 'package:jainverse/Resources/Strings/StringsLocalization.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/ThemeMain/appColors.dart';
import 'package:jainverse/ThemeMain/sizes.dart';

class ArtistSignUp extends StatefulWidget {
  const ArtistSignUp({super.key});

  @override
  myState createState() {
    return myState();
  }
}

class myState extends State {
  final bool _passwordVisible = false;
  TextEditingController passwordController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController dobController = TextEditingController();
  final picker = ImagePicker();
  bool has = false, presentImage = true;
  late File _image;
  SharedPref sharePrefs = SharedPref();
  late ModelTheme sharedPreThemeData = ModelTheme('', '', '', '', '', '');
  late UserModel model;
  String gender = " Select  ", dateOfBirth = '';
  String imagePresent = '';
  String token = '';
  bool isOpen = false;
  bool _checkbox = true;

  // Audio handler for mini player detection
  AudioPlayerHandler? _audioHandler;

  Future<dynamic> value() async {
    model = await sharePrefs.getUserData();
    token = await sharePrefs.getToken();
    getSettings();

    if (model.data.gender.toString().contains('0')) {
      gender = "Male";
    } else {
      gender = 'Female';
      //0 = male , 1= female
    }
    setState(() {});

    return model;
  }

  @override
  void initState() {
    // Initialize audio handler
    _audioHandler = const MyApp().called();

    value();
    final DateTime dob = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String formatted = formatter.format(dob);
    dateOfBirth = formatted;
    super.initState();
  }

  Future<void> getSettings() async {
    String? sett = await sharePrefs.getSettings();

    final Map<String, dynamic> parsed = json.decode(sett!);
    ModelSettings modelSettings = ModelSettings.fromJson(parsed);
    if (modelSettings.data.image.isNotEmpty) {
      imagePresent = AppConstant.ImageUrl + modelSettings.data.image;
      presentImage = false;
    } else {
      // Clear the image when the new user doesn't have a profile image
      imagePresent = '';
      presentImage = true;
    }

    nameController.text = modelSettings.data.name;
    mobileController.text = modelSettings.data.mobile;

    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        2000,
        1,
      ), // Set the initial date to the currently selected date
      firstDate: DateTime(1900, 1), // Set the minimum selectable date
      lastDate: DateTime(2006, 1), // Set the maximum selectable date
    );
    if (picked != null) {
      setState(() {
        dateOfBirth = picked as String;
      });
    }
  }

  void showPickDialog(BuildContext context) {
    imgFromCamera() async {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      final File file = File(pickedFile!.path);

      has = true;
      _image = file;
      ProfilePresenter().getProfileUpdate(
        context,
        _image,
        '',
        '',
        '',
        '',
        '',
        '', // country_id parameter
        token,
        true,
      );
      Navigator.of(context).pop();
      setState(() {});
    }

    openGallery() async {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      final File file = File(pickedFile!.path);

      has = true;
      _image = file;
      ProfilePresenter().getProfileUpdate(
        context,
        _image,
        '',
        '',
        '',
        '',
        '',
        '', // country_id parameter
        token,
        true,
      );
      Navigator.of(context).pop();
      setState(() {});
    }

    Future<void> future = showModalBottomSheet(
      barrierColor: const Color(0x00eae5e5),
      context: context,
      backgroundColor: appColors().colorBackEditText,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(6),
          height: MediaQuery.of(context).size.height * 0.29,
          alignment: Alignment.center,
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.all(7),
                  child: Text(
                    'From where would you like to \ntake the image ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (Platform.isAndroid) ? 18 : 20,
                      color: appColors().colorTextSideDrawer,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            imgFromCamera();
                          },
                          child: CircleAvatar(
                            backgroundColor: const Color(0xff161826),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset('assets/images/Camera.png'),
                            ),
                          ),
                        ),
                        Text(
                          'Camera',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (Platform.isAndroid) ? 13 : 18,
                            color: appColors().colorText,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            openGallery();
                          },
                          child: CircleAvatar(
                            backgroundColor: const Color(0xff161826),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              child: Image.asset('assets/images/Gallery.png'),
                            ),
                          ),
                        ),
                        Text(
                          'Gallery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (Platform.isAndroid) ? 13 : 18,
                            color: appColors().colorText,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: CircleAvatar(
                            backgroundColor: const Color(0xff161826),
                            child: Container(
                              padding: const EdgeInsets.all(13),
                              child: Image.asset('assets/images/Cancel.png'),
                            ),
                          ),
                        ),
                        Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (Platform.isAndroid) ? 13 : 18,
                            color: appColors().colorText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    void closeModal(void value) {
      if (isOpen) {
        isOpen = false;
        setState(() {});
      } else {
        isOpen = true;
        setState(() {});
      }
    }

    future.then((value) => closeModal(value));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          padding: const EdgeInsets.fromLTRB(6, 9, 9, 6),
          decoration: BoxDecoration(
            image: DecorationImage(
              image:
                  (sharedPreThemeData.themeImageBack.isEmpty)
                      ? AssetImage(AppSettings.imageBackground)
                      : AssetImage(sharedPreThemeData.themeImageBack),
              fit: BoxFit.fill,
            ),
          ),
          child: StreamBuilder<MediaItem?>(
            stream: _audioHandler?.mediaItem,
            builder: (context, snapshot) {
              // Calculate proper bottom padding accounting for mini player and navigation
              final hasMiniPlayer = snapshot.hasData;
              final bottomPadding =
                  hasMiniPlayer
                      ? AppSizes.basePadding + AppSizes.miniPlayerPadding
                      : AppSizes.basePadding;

              return ListView(
                padding: EdgeInsets.only(bottom: bottomPadding),
                children: [
                  Stack(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                          child: Text(
                            Resources.of(context).strings.requestArtist,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color:
                                  (sharedPreThemeData.themeImageBack.isEmpty)
                                      ? Color(int.parse(AppSettings.colorText))
                                      : appColors().colorText,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: InkResponse(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Image.asset(
                              'assets/icons/backarrow.png',
                              width: 20,
                              height: 20,
                              color:
                                  (sharedPreThemeData.themeImageBack.isEmpty)
                                      ? Color(int.parse(AppSettings.colorText))
                                      : appColors().colorText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      alignment: Alignment.center,
                      height: 200,
                      width: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 180,
                              margin: const EdgeInsets.fromLTRB(15, 25, 15, 0),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: appColors().colorBackEditText,
                                border: Border.all(
                                  color: const Color(0xa64f5055),
                                ),
                              ),
                              child: Container(
                                width: 200,
                                alignment: Alignment.center,
                                child: InkResponse(
                                  onTap: () {},
                                  child: CircleAvatar(
                                    radius: 72.0,
                                    backgroundColor: const Color(0xfffcf7f8),
                                    backgroundImage:
                                        has
                                            ? Image.file(
                                              _image,
                                              fit: BoxFit.cover,
                                            ).image
                                            : (presentImage)
                                            ? const AssetImage(
                                              'assets/icons/user2.png',
                                            )
                                            : NetworkImage(imagePresent)
                                                as ImageProvider,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(0, 0, 40, 14),
                              child: GestureDetector(
                                onTap: () {
                                  showPickDialog(context);
                                },
                                child: CircleAvatar(
                                  backgroundColor: appColors().red,
                                  radius: 15.0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Image.asset(
                                      'assets/icons/edit.png',
                                      color: appColors().white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Container(
                  //   height: 55,
                  //   padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  //   margin: const EdgeInsets.fromLTRB(22, 26, 22, 6),
                  //   alignment: Alignment.center,
                  //   decoration: BoxDecoration(
                  //       gradient: LinearGradient(
                  //         colors: [
                  //           appColors().colorBackEditText,
                  //           appColors().colorBackEditText
                  //         ],
                  //         begin: Alignment.centerLeft,
                  //         end: Alignment.centerRight,
                  //       ),
                  //       borderRadius: BorderRadius.circular(30.0),
                  //       border: Border.all(
                  //           width: 0.5, color: appColors().colorBorder)),
                  //   child: TextField(
                  //     style: TextStyle(
                  //         color: appColors().colorText,
                  //         fontSize: 17.0,
                  //         fontFamily: 'Poppins'),
                  //     controller: nameController,
                  //     decoration: InputDecoration(
                  //       suffixIcon: Image.asset(
                  //         'assets/icons/person.png',
                  //         height: 10.0,
                  //         width: 10.0,
                  //       ),
                  //       suffixIconConstraints:
                  //           const BoxConstraints(minHeight: 18, minWidth: 18),
                  //       hintText: Resources.of(context).strings.enterNameHere,
                  //       hintStyle: TextStyle(
                  //           fontFamily: 'Poppins',
                  //           fontSize: 17.0,
                  //           color: appColors().colorHint),
                  //       border: InputBorder.none,
                  //     ),
                  //   ),
                  // ),
                  // Container(
                  //   height: 57,
                  //   padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  //   margin: const EdgeInsets.fromLTRB(22, 10, 22, 6),
                  //   alignment: Alignment.center,
                  //   decoration: BoxDecoration(
                  //       gradient: LinearGradient(
                  //         colors: [
                  //           appColors().colorBackEditText,
                  //           appColors().colorBackEditText
                  //         ],
                  //         begin: Alignment.centerLeft,
                  //         end: Alignment.centerRight,
                  //       ),
                  //       borderRadius: BorderRadius.circular(30.0),
                  //       border: Border.all(
                  //           width: 0.5, color: appColors().colorBorder)),
                  //   child: TextField(
                  //     maxLength: 20,
                  //     keyboardType: const TextInputType.numberWithOptions(),
                  //     style: TextStyle(
                  //         color: appColors().colorText,
                  //         fontSize: 17.0,
                  //         fontFamily: 'Poppins'),
                  //     controller: mobileController,
                  //     decoration: InputDecoration(
                  //       counterText: "",
                  //       suffixIcon: Image.asset(
                  //         'assets/icons/mobile.png',
                  //         height: 10.0,
                  //         width: 10.0,
                  //       ),
                  //       suffixIconConstraints:
                  //           const BoxConstraints(minHeight: 18, minWidth: 18),
                  //       hintText:
                  //           Resources.of(context).strings.enterMobileHere,
                  //       hintStyle: TextStyle(
                  //           fontFamily: 'Poppins',
                  //           fontSize: 17.0,
                  //           color: appColors().colorHint),
                  //       border: InputBorder.none,
                  //     ),
                  //   ),
                  // ),
                  Container(
                    height: 55,
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                    margin: const EdgeInsets.fromLTRB(22, 10, 22, 6),
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
                        width: 0.5,
                        color: appColors().colorBorder,
                      ),
                    ),
                    child: TextField(
                      //controller: dobController,
                      style: TextStyle(
                        color: appColors().colorText,
                        fontSize: 17.0,
                        fontFamily: 'Poppins',
                      ),
                      decoration: InputDecoration(
                        hintText:
                            dateOfBirth.isNotEmpty
                                ? dateOfBirth
                                : 'Enter Date of Birth Here',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17.0,
                          color: appColors().colorHint,
                        ),
                        suffixIcon: IconButton(
                          padding: const EdgeInsets.all(13),
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () {
                            _selectDate(context);
                          },
                        ),
                        suffixIconConstraints: const BoxConstraints(
                          minHeight: 18,
                          minWidth: 8,
                        ),
                        border: InputBorder.none,
                      ),
                      onTap: () {
                        _selectDate(context); //Your code here
                      },
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.fromLTRB(0, 12, 0, 2),
                    alignment: Alignment.center,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          height: 39,
                          width: MediaQuery.of(context).size.width - 25,
                          alignment: Alignment.center,
                          child: CheckboxListTile(
                            tileColor: appColors().colorText,
                            selectedTileColor: appColors().colorText,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              'I\'ve read and accept the',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16.6,
                                color: appColors().colorText,
                              ),
                            ),
                            value: _checkbox,
                            onChanged: (value) {
                              setState(() {
                                _checkbox = value!;
                              });
                            },
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkResponse(
                              child: Text(
                                "Terms of use ",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16.5,
                                  color: appColors().primaryColorApp,
                                ),
                              ),
                              onTap: () async {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PrivacyPolicy('', ''),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.fromLTRB(19, 14, 19, 0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appColors().PrimaryDarkColorApp,
                          appColors().primaryColorApp,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    child: TextButton(
                      child: const Text(
                        //Resources.of(context).strings.update,
                        'Submit',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffffffff),
                        ),
                      ),
                      onPressed:
                          () => {
                            ProfilePresenter().getProfileUpdate(
                              context,
                              File(''),
                              nameController.text,
                              passwordController.text,
                              mobileController.text,
                              dateOfBirth,
                              gender,
                              '', // country_id parameter
                              token,
                              true,
                            ),
                          },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class Resources {
  final BuildContext _context;

  Resources(this._context);

  StringsLocalization get strings {
    switch ('en') {
      case 'ar':
        return ArabicStrings();
      case 'fn':
        return FranchStrings();
      default:
        return EnglishStrings();
    }
  }

  static Resources of(BuildContext context) {
    return Resources(context);
  }
}
