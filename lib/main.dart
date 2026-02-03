import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/theme/cyber_theme.dart';
import 'ui/screens/menu_screen.dart';
import 'ui/screens/game_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/leaderboard_screen.dart';
import 'ui/screens/controls_screen.dart';
import 'services/audio_manager.dart';
import 'services/leaderboard_service.dart';
import 'services/localization_service.dart';
import 'services/visual_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AudioManager.instance.init();
  await LeaderboardService.instance.init();
  await LocalizationService.instance.init();
  await VisualSettings.instance.init();

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
          home: const MainNavigator(),
        );
      },
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> with WidgetsBindingObserver {
  bool _isPlaying = false;
  bool _showSettings = false;
  bool _showLeaderboard = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      );
    }

    if (_showControls) {
      return ControlsScreen(
        onClose: () => setState(() => _showControls = false),
      );
    }

    return MenuScreen(
      onStartGame: () => setState(() => _isPlaying = true),
      onSettings: () => setState(() => _showSettings = true),
      onLeaderboard: () => setState(() => _showLeaderboard = true),
      onControls: () => setState(() => _showControls = true),
    );
  }
}

