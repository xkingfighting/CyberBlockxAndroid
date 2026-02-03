import 'package:flutter/material.dart';
import '../../services/audio_manager.dart';
import '../../services/localization_service.dart';
import '../../services/visual_settings.dart';
import '../theme/cyber_theme.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsScreen({super.key, required this.onClose});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    // Wrap entire screen with ListenableBuilder to update when language changes
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        L.settingsTitle.tr,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: CyberColors.cyan,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LANGUAGE Section
                          _buildSectionHeader(Icons.language, L.language.tr, CyberColors.cyan),
                          const SizedBox(height: 8),
                          _buildSettingsCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  L.languageSettings.tr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'monospace',
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildLanguageDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // VISUAL Section
                          _buildSectionHeader(Icons.auto_awesome, L.visual.tr, CyberColors.cyan),
                          const SizedBox(height: 8),
                          ListenableBuilder(
                            listenable: VisualSettings.instance,
                            builder: (context, _) {
                              final visual = VisualSettings.instance;
                              return _buildSettingsCard(
                                child: Column(
                                  children: [
                                    _buildSliderRow(
                                      L.glowIntensity.tr,
                                      visual.glowIntensity,
                                      CyberColors.cyan,
                                      (value) => visual.glowIntensity = value,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildSliderRow(
                                      L.glitchEffects.tr,
                                      visual.glitchEffects,
                                      CyberColors.pink,
                                      (value) => visual.glitchEffects = value,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          // AUDIO Section
                          _buildSectionHeader(Icons.volume_up, L.audio.tr, CyberColors.purple),
                          const SizedBox(height: 8),
                          ListenableBuilder(
                            listenable: AudioManager.instance,
                            builder: (context, _) {
                              final audio = AudioManager.instance;
                              return _buildSettingsCard(
                                child: Column(
                                  children: [
                                    _buildToggleRow(
                                      L.soundEffects.tr,
                                      audio.soundEnabled,
                                      CyberColors.purple,
                                      (value) => audio.soundEnabled = value,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSliderRow(
                                      L.volume.tr,
                                      audio.soundVolume,
                                      CyberColors.orange,
                                      (value) => audio.soundVolume = value,
                                      enabled: audio.soundEnabled,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildToggleRow(
                                      L.music.tr,
                                      audio.musicEnabled,
                                      CyberColors.purple,
                                      (value) => audio.musicEnabled = value,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSliderRow(
                                      L.musicVolume.tr,
                                      audio.musicVolume,
                                      CyberColors.purple,
                                      (value) => audio.musicVolume = value,
                                      enabled: audio.musicEnabled,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildToggleRow(
                                      L.hapticFeedback.tr,
                                      audio.hapticEnabled,
                                      CyberColors.cyan,
                                      (value) => audio.hapticEnabled = value,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberColors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildLanguageDropdown() {
    final localization = LocalizationService.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CyberColors.cyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: localization.currentLanguage,
          isExpanded: true,
          dropdownColor: CyberColors.surface,
          icon: Icon(
            Icons.unfold_more,
            color: CyberColors.cyan.withOpacity(0.7),
            size: 20,
          ),
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: Colors.white,
          ),
          items: AppLanguage.values.map((lang) {
            return DropdownMenuItem<AppLanguage>(
              value: lang,
              child: Text(lang.displayName),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              localization.setLanguage(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String label,
    bool value,
    Color color,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: Colors.white,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          activeTrackColor: color.withOpacity(0.3),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.withOpacity(0.3),
        ),
      ],
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged, {
    bool enabled = true,
  }) {
    final percentage = (value * 100).round();
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: Colors.white,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: Colors.white,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
