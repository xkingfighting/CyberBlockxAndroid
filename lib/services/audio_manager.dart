import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_generator.dart';
import 'background_music_generator.dart';

/// Game sound types
enum GameSound {
  move,
  rotate,
  drop,
  lock,
  lineClear,
  tetris,
  levelUp,
  gameOver,
  hold,
  combo,
  perfectClear,
}

/// Audio and haptic feedback manager
class AudioManager extends ChangeNotifier {
  static final AudioManager instance = AudioManager._();
  AudioManager._();

  // Procedural sound generators (same as iOS)
  final SoundGenerator _soundGenerator = SoundGenerator.instance;
  final BackgroundMusicGenerator _musicGenerator = BackgroundMusicGenerator.instance;

  // Sound settings
  bool _soundEnabled = true;
  double _soundVolume = 0.7;
  bool _musicEnabled = true;
  double _musicVolume = 0.5;
  bool _hapticEnabled = true;

  // Preference keys
  static const _soundEnabledKey = 'CyberBlockx_SoundEnabled';
  static const _soundVolumeKey = 'CyberBlockx_SoundVolume';
  static const _musicEnabledKey = 'CyberBlockx_MusicEnabled';
  static const _musicVolumeKey = 'CyberBlockx_MusicVolume';
  static const _hapticEnabledKey = 'CyberBlockx_HapticEnabled';

  bool get soundEnabled => _soundEnabled;
  double get soundVolume => _soundVolume;
  bool get musicEnabled => _musicEnabled;
  double get musicVolume => _musicVolume;
  bool get hapticEnabled => _hapticEnabled;

  set soundEnabled(bool value) {
    _soundEnabled = value;
    _savePreferences();
    notifyListeners();
  }

  set soundVolume(double value) {
    _soundVolume = value.clamp(0.0, 1.0);
    _savePreferences();
    notifyListeners();
  }

  set musicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      stopBackgroundMusic();
    }
    _savePreferences();
    notifyListeners();
  }

  set musicVolume(double value) {
    _musicVolume = value.clamp(0.0, 1.0);
    _musicGenerator.setVolume(_musicVolume);
    _savePreferences();
    notifyListeners();
  }

  set hapticEnabled(bool value) {
    _hapticEnabled = value;
    _savePreferences();
    notifyListeners();
  }

  /// Initialize and load preferences
  Future<void> init() async {
    await _loadPreferences();
    await _soundGenerator.init();
    await _musicGenerator.init();
    _musicGenerator.setVolume(_musicVolume);
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      _soundVolume = prefs.getDouble(_soundVolumeKey) ?? 0.7;
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
      _musicVolume = prefs.getDouble(_musicVolumeKey) ?? 0.5;
      _hapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load audio preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      await prefs.setDouble(_soundVolumeKey, _soundVolume);
      await prefs.setBool(_musicEnabledKey, _musicEnabled);
      await prefs.setDouble(_musicVolumeKey, _musicVolume);
      await prefs.setBool(_hapticEnabledKey, _hapticEnabled);
    } catch (e) {
      debugPrint('Failed to save audio preferences: $e');
    }
  }

  /// Play a game sound effect with appropriate haptic feedback
  void playSound(GameSound sound) {
    // Always play haptic feedback
    _playHapticForSound(sound);

    if (!_soundEnabled || _soundVolume <= 0) return;

    // Play procedurally generated cyberpunk sound effects (same as iOS)
    switch (sound) {
      case GameSound.move:
        _soundGenerator.playMove(_soundVolume);
        break;
      case GameSound.rotate:
        _soundGenerator.playRotate(_soundVolume);
        break;
      case GameSound.drop:
        _soundGenerator.playDrop(_soundVolume);
        break;
      case GameSound.lock:
        _soundGenerator.playLock(_soundVolume);
        break;
      case GameSound.lineClear:
        _soundGenerator.playLineClear(_soundVolume);
        break;
      case GameSound.tetris:
        _soundGenerator.playTetris(_soundVolume);
        break;
      case GameSound.levelUp:
        _soundGenerator.playLevelUp(_soundVolume);
        break;
      case GameSound.gameOver:
        _soundGenerator.playGameOver(_soundVolume);
        break;
      case GameSound.hold:
        _soundGenerator.playHold(_soundVolume);
        break;
      case GameSound.combo:
        _soundGenerator.playCombo(_soundVolume);
        break;
      case GameSound.perfectClear:
        _soundGenerator.playPerfectClear(_soundVolume);
        break;
    }
  }

  void _playHapticForSound(GameSound sound) {
    if (!_hapticEnabled) return;

    switch (sound) {
      case GameSound.move:
        HapticFeedback.selectionClick();
        break;
      case GameSound.rotate:
        HapticFeedback.lightImpact();
        break;
      case GameSound.drop:
        HapticFeedback.heavyImpact();
        break;
      case GameSound.lock:
        HapticFeedback.mediumImpact();
        break;
      case GameSound.lineClear:
        HapticFeedback.mediumImpact();
        break;
      case GameSound.tetris:
        // Double haptic for tetris
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.heavyImpact();
        });
        break;
      case GameSound.levelUp:
        HapticFeedback.heavyImpact();
        break;
      case GameSound.gameOver:
        // Triple haptic for game over
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
          HapticFeedback.heavyImpact();
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          HapticFeedback.heavyImpact();
        });
        break;
      case GameSound.hold:
        HapticFeedback.lightImpact();
        break;
      case GameSound.combo:
        HapticFeedback.mediumImpact();
        break;
      case GameSound.perfectClear:
        // Triple haptic for perfect clear
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.heavyImpact();
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
        });
        break;
    }
  }

  /// Play simple haptic feedback
  void playHaptic(HapticType type) {
    if (!_hapticEnabled) return;

    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  // Background music control
  bool _isGameActive = false;

  bool get isMusicPlaying => _musicGenerator.isPlaying;

  Future<void> startBackgroundMusic() async {
    _isGameActive = true;
    if (!_musicEnabled) return;
    _musicGenerator.setVolume(_musicVolume);
    await _musicGenerator.start();
    notifyListeners();
  }

  Future<void> stopBackgroundMusic() async {
    _isGameActive = false;
    await _musicGenerator.stop();
    notifyListeners();
  }

  Future<void> pauseBackgroundMusic() async {
    await _musicGenerator.pause();
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled || !_isGameActive) return;
    await _musicGenerator.resume();
  }

  // Game lifecycle hooks
  void onGameStart() {
    startBackgroundMusic();
  }

  void onGamePause() {
    pauseBackgroundMusic();
  }

  void onGameResume() {
    resumeBackgroundMusic();
  }

  void onGameOver() {
    playSound(GameSound.gameOver);
    stopBackgroundMusic();
  }

  void onReturnToMenu() {
    stopBackgroundMusic();
  }

  // App lifecycle
  void onEnterBackground() {
    _musicGenerator.stop();
  }

  void onEnterForeground() {
    if (_musicEnabled && _isGameActive) {
      _musicGenerator.start();
    }
  }

  @override
  void dispose() {
    _soundGenerator.dispose();
    _musicGenerator.dispose();
    super.dispose();
  }
}

enum HapticType {
  light,
  medium,
  heavy,
  selection,
}
