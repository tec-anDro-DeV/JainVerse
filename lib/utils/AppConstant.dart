class AppConstant {
  //app name
  static const String appName = 'JainVerse';

  static const String SiteUrl = "https://musicvideo.techcronus.com/";

  static const String BaseUrl = "${AppConstant.SiteUrl}api/v2/";
  static const String ImageUrl = "${AppConstant.SiteUrl}public/";
  //"/public/"; //main web url or base url here

  //api name below
  static const String API_LOGIN = "login";
  static const String API_logout = "logout";
  static const String API_delete = "deleteAccountPermanent";
  static const String API_buy_audio_to_download = "buy_audio_to_download";
  static const String API_SIGNUP = "register";
  static const String API_VERIFY_OTP = "verify_otp";
  static const String API_RESEND_OTP = "resend_otp";
  static const String API_FORGOT_PASSWORD = "forgot_password";
  static const String API_RESET_PASSWORD = "reset_password";
  static const String API_UPDATE_PROFILE = "updateProfile";
  static const String API_MUSIC_LANGUAGES = "musicLanguages";
  static const String API_SET_MUSIC_LANGUAGES = "setMusicLanguages";
  static const String API_GET_MUSIC_CATEGORIES = "musicCategories";
  static const String API_GET_MUSIC_BY_CATEGORY = "getMusicByCategory";
  static const String API_SET_MUSIC_GENRE = "setMusicGenre";
  static const String API_MUSIC_GENRE = "musicGenre";
  static const String API_GET_SEARCH_MUSIC = "searchMusic";
  static const String API_GETMUSIC = "getMusic";
  static const String API_GET_FAVOURITE_LIST = "favouriteList";
  static const String API_ADD_FAVOURITE_LIST = "addFavouriteList";
  static const String API_PLAYLIST = "playlist";
  static const String API_USER_PLAYLIST = "playlist";
  static const String API_CREATE_PLAYLIST = "create_playlist";
  static const String API_ADD_PLAYLIST_MUSIC = "add_playlist_music";
  static const String API_UPDATE_PLAYLIST_NAME = "update_playlist_name";
  static const String API_DELETE_PLAYLIST = "delete_playlist";
  static const String API_REMOVE_PLAYLIST_MUSIC = "remove_playlist_music";
  static const String API_MUSIC_HISTORY = "music_history";
  static const String API_ADD_REMOVE_MUSIC_HISTORY = "addremove_musichistory";
  static const String API_DOWNLOADED_MUSIC_LIST = "downloaded_music_list";
  static const String API_ADD_REMOVE_DOWNLOAD_MUSIC = "addremove_downloadmusic";
  static const String API_PLAN_LIST = "plan_list";
  static const String API_GET_COUPON_LIST = "get_coupon_list";
  static const String API_USER_COUPON_CODE = "user_coupon_code";
  static const String API_GET_APP_INFO = "get_app_info";
  static const String API_SAVE_PAYMENT_TRANSACTION = "save_payment_transaction";
  static const String API_GET_USER_SETTING_DETAILS = "get_user_setting_details";
  static const String API_Blog = "get_blogs";
  static const String API_YT_PLAYLISTS = "yt_pLaylists";
  static const String API_USER_PURCHASE_HISTORY = "user_purchase_history";
  // Video API endpoints
  static const String API_ALL_VIDEOS = "all_videos";
  static const String API_SEARCH_VIDEOS = "search_channel_video";
  static const String API_GET_CHANNEL_VIDEOS = "get_channel_videos";
  static const String API_LIKE_DISLIKE_VIDEO = "like_dislike_video";
  static const String API_GET_LIKED_VIDEOS = "get_liked_videos";
  static const String API_GET_SUBSCRIBED_CHANNELS = "get_subscribed_channels";
  static const String API_SUBSCRIBE_CHANNEL = "subscribe_channel";
  static const String API_UNSUBSCRIBE_CHANNEL = "unsubscribe_channel";

  static const String API_CREATE_STATION = "station";
  static const String API_GET_COUNTRY = "get_country";
  static const String API_CREATE_CHANNEL = "create_channel";
  static const String API_GET_CHANNEL = "get_channel";
  static const String API_UPDATE_CHANNEL = "update_channel";
  static const String API_DELETE_CHANNEL = "delete_channel";
  static const String API_MY_VIDEOS = "my_videos";
  static const String API_WATCH_HISTORY = "watch_history";
  //strings or paramenter name below
  static const String currency = "\$";
  static const String currencyCode = "USD";
  static const String email = "email";
  static const String name = "name";
  static const String fname = "fname";
  static const String lname = "lname";
  static const String language_id = "language_id";
  static const String genre_id = "genre_id";
  static const String image = "image";
  static const String dob = "dob";
  static const String gender = "gender";
  static const String type = "type";
  static const String plan_id = "plan_id";
  static const String payment_data = "payment_data";
  static const String order_id = "order_id";
  static const String tag = "tag";
  static const String playlist_name = "playlist_name";
  static const String playlist_id = "playlist_id";
  static const String music_id = "music_id";
  static const String coupon_code = "coupon_code";
  static const String search = "search";
  static const String id = "id";
  static const String mobile = "mobile";
  static const String country = "country_id";
  static const String OTP = "otp";
  static const String password_confirmation = "password_confirmation";
  static const String confirmationPassword = "confirm_password";
  static const String password = "password";
  static const String token = "token";
  static const String versionCode = "versionCode";

  static const double panelMinSize = 130.0;
  static const double btmNavHeight = 63.0;
  static const double appBarHeight = 35.0;
}
