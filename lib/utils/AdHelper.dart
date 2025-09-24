import 'dart:io';

class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // return 'ca-app-pub-3940256099942544/6300978111';
        return 'ca-app-pub-3940256099942545/6300978110';

    } else if (Platform.isIOS) {
      return 'ca-app-pub-1420722541056351/3917985475';
    } else {
      //throw UnsupportedError('Unsupported platform');
      return '';
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return "ca-app-pub-3940256099942544/1033173712";
    } else if (Platform.isIOS) {
      return "ca-app-pub-1420722541056351/8978740467";
    } else {
      //throw UnsupportedError('Unsupported platform');
      return '';
    }
  }
}
