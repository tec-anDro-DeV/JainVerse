import 'dart:io';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:jainverse/models/downloaded_music.dart';
import 'package:jainverse/ThemeMain/AppSettings.dart';
import 'package:jainverse/services/audio_player_service.dart';
import 'package:jainverse/managers/music_manager.dart';
import 'package:jainverse/utils/optimized_image_widget.dart';
import 'package:jainverse/controllers/download_controller.dart';
import 'package:jainverse/services/startup_controller.dart';
import 'package:jainverse/services/offline_mode_service.dart';
import 'package:jainverse/services/app_router_manager.dart';
import 'package:jainverse/providers/favorites_provider.dart';
import 'package:jainverse/controllers/user_music_controller.dart';
import 'package:session_storage/session_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'ThemeMain/appColors.dart';
import 'UI/SplashScreen.dart';
import 'UI/MainNavigation.dart';

AudioPlayerHandler? _audioHandler;
const String home = '/';
const String initProfile = 'initProfile';

// Global navigator key for router management
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Global route observer so widgets can be route-aware (didPush/didPop/etc.)
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// Helper to determine device type and provide an appropriate design size for
// ScreenUtilInit. Uses the Flutter window to calculate logical dimensions so
// we can choose a designSize before a BuildContext exists (useful at app
// startup). Detects iPad/Tablet-like sizes and returns a larger design size.
class DeviceUtils {
  static bool _isTabletFromWindow() {
    final window = WidgetsBinding.instance.window;
    final dpr = window.devicePixelRatio;
    final logicalWidth = window.physicalSize.width / dpr;
    final logicalHeight = window.physicalSize.height / dpr;
    final diagonal = sqrt(
      logicalWidth * logicalWidth + logicalHeight * logicalHeight,
    );
    // Consider devices with diagonal > 1100 logical pixels as tablets
    if (diagonal > 1100) return true;
    // Also treat wide short-side (e.g. iPad in portrait) as tablet
    if (min(logicalWidth, logicalHeight) >= 600) return true;
    return false;
  }

  static bool _isIpadFromWindow() {
    if (!Platform.isIOS) return false;
    final window = WidgetsBinding.instance.window;
    final dpr = window.devicePixelRatio;
    final shortestSide =
        min(window.physicalSize.width, window.physicalSize.height) / dpr;
    return shortestSide >= 600;
  }

  static Size getDesignSizeFromWindow() {
    // If it's an iPad or tablet, return an iPad-like design size. Otherwise use phone design.
    if (_isIpadFromWindow() || _isTabletFromWindow()) {
      return const Size(768, 1024);
    }
    return const Size(448, 998);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission at startup (Android 13+)
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final status = await Permission.notification.request();
      if (!status.isGranted) {
        debugPrint('Notification permission not granted');
      }
    }
  }

  // Request notification permission for iOS
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  if (Platform.isIOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Initialize flutter_local_notifications with Android and iOS settings
  final AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize Hive for local storage
  await Hive.initFlutter();
  Hive.registerAdapter(DownloadedMusicAdapter());

  // Initialize Image Cache Optimizer for better memory management
  ImageCacheOptimizer.initialize();

  // Initialize offline support services
  final startupController = StartupController();
  final downloadController = DownloadController();
  final offlineModeService = OfflineModeService();
  final appRouterManager = AppRouterManager();

  try {
    // Initialize core services for offline support
    debugPrint('Initializing downloadController...');
    await downloadController.initialize();

    debugPrint('Initializing startupController...');
    await startupController.initialize();

    debugPrint('Initializing offlineModeService...');
    await offlineModeService.initialize();

    debugPrint('Initializing appRouterManager...');
    await appRouterManager.initialize(navigatorKey);

    debugPrint('All offline services initialized successfully');
  } catch (e) {
    debugPrint('Error initializing offline services: $e');

    // Try to initialize critical services individually
    try {
      debugPrint('Attempting to initialize OfflineModeService separately...');
      await offlineModeService.initialize();
    } catch (offlineError) {
      debugPrint('OfflineModeService initialization failed: $offlineError');
    }

    try {
      debugPrint('Attempting to initialize AppRouterManager separately...');
      await appRouterManager.initialize(navigatorKey);
    } catch (routerError) {
      debugPrint('AppRouterManager initialization failed: $routerError');
    }
  }

  // Set system UI overlay style to ensure status bar is properly handled
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Also set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize session storage before audio
  final session = SessionStorage();
  session['page'] = "0"; // Set default page immediately

  // Enhanced AudioService initialization with comprehensive background playback support
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandlerImpl.instance,
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.jainverse.audio.channel',
      androidNotificationChannelName: 'JainVerse',
      androidNotificationChannelDescription: 'JainVerse music playback controls',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidShowNotificationBadge: true,
      // CRITICAL: Keep service alive when paused for background playback
      androidStopForegroundOnPause: false,
      androidResumeOnClick: true, // Resume playback when notification tapped
      artDownscaleWidth: 256,
      artDownscaleHeight: 256,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      preloadArtwork: true,
      // Note: androidNotificationOngoing removed to prevent conflict with androidStopForegroundOnPause: false
    ),
  );

  // Initialize MusicManager with the audio handler
  MusicManager().setAudioHandler(_audioHandler!);

  HttpOverrides.global = MyHttpOverrides();

  runApp(
    ScreenUtilInit(
      designSize: DeviceUtils.getDesignSizeFromWindow(),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return const MyApp();
      },
    ),
  );
}

class MyApp extends StatelessWidget {
  static final AudioPlayerHandler _audioHandlerr = _audioHandler!;

  const MyApp({super.key});

  AudioPlayerHandler called() {
    return _audioHandlerr;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Global Favorites Provider
        ChangeNotifierProvider<FavoritesProvider>(
          create: (context) {
            final provider = FavoritesProvider();
            // Initialize the provider asynchronously
            Future.microtask(() => provider.initialize());
            return provider;
          },
        ),
        // Global User Music Controller
        ChangeNotifierProvider<UserMusicController>(
          create: (context) => UserMusicController(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // Add global navigator key
        navigatorObservers: [routeObserver],
        color: appColors().colorBackground,
        debugShowCheckedModeBanner: false,
        theme: AppSettings.define(),
        // Add route handling for proper navigation
        onGenerateRoute: (settings) {
          // Handle navigation to specific tabs
          if (settings.name?.startsWith('/tab/') == true) {
            final tabIndex = int.tryParse(settings.name!.split('/').last) ?? 0;
            return MaterialPageRoute(
              builder:
                  (context) => MainNavigationWrapper(initialIndex: tabIndex),
            );
          }

          // Default route
          return MaterialPageRoute(builder: (context) => const SplashScreen());
        },
        home: const SplashScreen(),
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
