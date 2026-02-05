import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/theme/cyber_theme.dart';
import 'ui/screens/menu_screen.dart';
import 'ui/screens/game_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/leaderboard_screen.dart';
import 'ui/screens/controls_screen.dart';
import 'ui/screens/bind_account_screen.dart';
import 'services/audio_manager.dart';
import 'services/leaderboard_service.dart';
import 'services/localization_service.dart';
import 'services/visual_settings.dart';
import 'services/auth_service.dart';
import 'solana/wallet_service.dart';

// Global app links instance
late AppLinks _appLinks;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AudioManager.instance.init();
  await LeaderboardService.instance.init();
  await LocalizationService.instance.init();
  await VisualSettings.instance.init();
  await AuthService.instance.init();
  await WalletService.instance.init();

  // Initialize deep link handling
  _appLinks = AppLinks();
  _initDeepLinks();

  // Lock orientation to portrait on phones
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: CyberColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const CyberBlockxApp());
}

// Global key for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<_MainNavigatorState> mainNavigatorKey = GlobalKey<_MainNavigatorState>();

void _initDeepLinks() {
  // Handle initial link if app was started from a deep link (cold start)
  _appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      debugPrint('Initial deep link (cold start): $uri');
      WalletService.instance.handleDeepLink(uri);

      // If this is a wallet callback, navigate to bind screen
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      final isConnectCallback = host == 'onconnect' || path == '/onconnect';
      final isSignCallback = host == 'onsignmessage' || path == '/onsignmessage';

      if (isConnectCallback || isSignCallback) {
        // Wait a bit for the widget tree to build, then navigate to bind screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (WalletService.instance.hasPendingConnectResult ||
              WalletService.instance.hasPendingSignResult ||
              WalletService.instance.isConnected) {
            mainNavigatorKey.currentState?.navigateToBind();
          }
        });
      }
    }
  });

  // Listen for incoming links while app is running
  _appLinks.uriLinkStream.listen((uri) {
    debugPrint('Incoming deep link: $uri');
    WalletService.instance.handleDeepLink(uri);
  });
}

class CyberBlockxApp extends StatelessWidget {
  const CyberBlockxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Cyber Blockx',
          theme: CyberTheme.theme,
          debugShowCheckedModeBanner: false,
          home: MainNavigator(key: mainNavigatorKey),
        );
      },
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();

  /// Get the current state instance for navigation
  static _MainNavigatorState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainNavigatorState>();
  }
}

class _MainNavigatorState extends State<MainNavigator> with WidgetsBindingObserver {
  bool _isPlaying = false;
  bool _showSettings = false;
  bool _showLeaderboard = false;
  bool _showControls = false;
  bool _showBind = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Navigate to the bind screen (used for cold start deep link handling)
  void navigateToBind() {
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _showSettings = false;
        _showLeaderboard = false;
        _showControls = false;
        _showBind = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App went to background - stop music
        AudioManager.instance.onEnterBackground();
        break;
      case AppLifecycleState.resumed:
        // App came back to foreground - resume music if playing
        AudioManager.instance.onEnterForeground();
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      return GameScreen(
        onReturnToMenu: () {
          AudioManager.instance.onReturnToMenu();
          setState(() => _isPlaying = false);
        },
        onShowLeaderboard: () {
          AudioManager.instance.onReturnToMenu();
          setState(() {
            _isPlaying = false;
            _showLeaderboard = true;
          });
        },
      );
    }

    if (_showSettings) {
      return SettingsScreen(
        onClose: () => setState(() => _showSettings = false),
      );
    }

    if (_showLeaderboard) {
      return LeaderboardScreen(
        onClose: () => setState(() => _showLeaderboard = false),
        onBind: () => setState(() {
          _showLeaderboard = false;
          _showBind = true;
        }),
      );
    }

    if (_showControls) {
      return ControlsScreen(
        onClose: () => setState(() => _showControls = false),
      );
    }

    if (_showBind) {
      return BindAccountScreen(
        onClose: () => setState(() => _showBind = false),
        onBindSuccess: () => setState(() => _showBind = false),
      );
    }

    return MenuScreen(
      onStartGame: () => setState(() => _isPlaying = true),
      onSettings: () => setState(() => _showSettings = true),
      onLeaderboard: () => setState(() => _showLeaderboard = true),
      onControls: () => setState(() => _showControls = true),
      onBind: () => setState(() => _showBind = true),
    );
  }
}

