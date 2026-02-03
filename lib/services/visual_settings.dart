import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual settings service for glow intensity and glitch effects
class VisualSettings extends ChangeNotifier {
  static final VisualSettings _instance = VisualSettings._internal();
  static VisualSettings get instance => _instance;

  VisualSettings._internal();

  static const String _keyGlowIntensity = 'glow_intensity';
  static const String _keyGlitchEffects = 'glitch_effects';

  double _glowIntensity = 1.0;
  double _glitchEffects = 0.5;

  double get glowIntensity => _glowIntensity;
  double get glitchEffects => _glitchEffects;

  set glowIntensity(double value) {
    if (_glowIntensity != value) {
      _glowIntensity = value;
      _savePreferences();
      notifyListeners();
    }
  }

  set glitchEffects(double value) {
    if (_glitchEffects != value) {
      _glitchEffects = value;
      _savePreferences();
      notifyListeners();
    }
  }

  /// Initialize from shared preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _glowIntensity = prefs.getDouble(_keyGlowIntensity) ?? 1.0;
    _glitchEffects = prefs.getDouble(_keyGlitchEffects) ?? 0.5;
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyGlowIntensity, _glowIntensity);
    await prefs.setDouble(_keyGlitchEffects, _glitchEffects);
  }
}
