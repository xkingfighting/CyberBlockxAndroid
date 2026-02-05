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
import 'ui/screens/badges_screen.dart';
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
  debugPrint('=== Deep link listener initialized ===');

  // Handle initial link if app was started from a deep link (cold start)
  _appLinks.getInitialLink().then((uri) {
    debugPrint('getInitialLink result: $uri');
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
  _appLinks.uriLinkStream.listen(
    (uri) {
      debugPrint('=== Incoming deep link (warm start) ===');
      debugPrint('URI: $uri');
      debugPrint('Scheme: ${uri.scheme}');
      debugPrint('Host: ${uri.host}');
      debugPrint('Path: ${uri.path}');
      debugPrint('Query params: ${uri.queryParameters.keys.toList()}');
      WalletService.instance.handleDeepLink(uri);
    },
    onError: (error) {
      debugPrint('Deep link stream error: $error');
    },
  );
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
  bool _showBadges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Show exit confirmation dialog
  Future<bool> _showExitConfirmation() async {
    final loc = LocalizationService.instance;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _ExitConfirmDialog(
        title: loc.tr(L.exitConfirmTitle),
        message: loc.tr(L.exitConfirmMessage),
        confirmText: loc.tr(L.exitConfirmYes),
        cancelText: loc.tr(L.exitConfirmNo),
      ),
    );
    return result ?? false;
  }

  /// Handle back navigation
  Future<bool> _onPopInvoked(bool didPop) async {
    if (didPop) return true;

    // If on a sub-screen, go back to menu
    if (_showSettings || _showLeaderboard || _showControls || _showBind || _showBadges) {
      setState(() {
        _showSettings = false;
        _showLeaderboard = false;
        _showControls = false;
        _showBind = false;
        _showBadges = false;
      });
      return false;
    }

    // If playing game, let game handle it
    if (_isPlaying) {
      return false;
    }

    // On menu, show exit confirmation
    final shouldExit = await _showExitConfirmation();
    if (shouldExit && mounted) {
      SystemNavigator.pop();
    }
    return false;
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
        _showBadges = false;
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
    Widget content;

    if (_isPlaying) {
      content = GameScreen(
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
    } else if (_showSettings) {
      content = SettingsScreen(
        onClose: () => setState(() => _showSettings = false),
      );
    } else if (_showLeaderboard) {
      content = LeaderboardScreen(
        onClose: () => setState(() => _showLeaderboard = false),
        onBind: () => setState(() {
          _showLeaderboard = false;
          _showBind = true;
        }),
      );
    } else if (_showControls) {
      content = ControlsScreen(
        onClose: () => setState(() => _showControls = false),
      );
    } else if (_showBind) {
      content = BindAccountScreen(
        onClose: () => setState(() => _showBind = false),
        onBindSuccess: () => setState(() => _showBind = false),
      );
    } else if (_showBadges) {
      content = BadgesScreen(
        onClose: () => setState(() => _showBadges = false),
      );
    } else {
      content = MenuScreen(
        onStartGame: () => setState(() => _isPlaying = true),
        onSettings: () => setState(() => _showSettings = true),
        onLeaderboard: () => setState(() => _showLeaderboard = true),
        onControls: () => setState(() => _showControls = true),
        onBind: () => setState(() => _showBind = true),
        onBadges: () => setState(() => _showBadges = true),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _onPopInvoked(didPop),
      child: content,
    );
  }
}

/// Exit confirmation dialog with cyber theme styling
class _ExitConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const _ExitConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CyberColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CyberColors.cyan.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: CyberColors.cyan.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CyberColors.cyan,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: _DialogButton(
                    text: cancelText,
                    onTap: () => Navigator.of(context).pop(false),
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 16),
                // Confirm button
                Expanded(
                  child: _DialogButton(
                    text: confirmText,
                    onTap: () => Navigator.of(context).pop(true),
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Styled button for exit dialog
class _DialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isPrimary;

  const _DialogButton({
    required this.text,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? CyberColors.pink : CyberColors.cyan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.7),
              width: 2,
            ),
            gradient: isPrimary
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

