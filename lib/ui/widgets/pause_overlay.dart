import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  final VoidCallback? onSettings;

  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onMenu,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap with ListenableBuilder to update when language changes
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title - PAUSED in orange/yellow gradient
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFD700), // Gold yellow
                      Color(0xFFFF8C00), // Dark orange
                    ],
                  ).createShader(bounds),
                  child: Text(
                    L.paused.tr,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Colors.orange.withValues(alpha: 0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Divider line
                Container(
                  width: 160,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        CyberColors.cyan.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                _PauseButton(
                  text: L.resume.tr,
                  icon: Icons.play_arrow,
                  color: CyberColors.green,
                  onTap: onResume,
                ),
                const SizedBox(height: 10),
                _PauseButton(
                  text: L.restart.tr,
                  icon: Icons.refresh,
                  color: CyberColors.orange,
                  onTap: onRestart,
                ),
                const SizedBox(height: 10),
                if (onSettings != null) ...[
                  _PauseButton(
                    text: L.settings.tr,
                    icon: Icons.settings,
                    color: CyberColors.cyan,
                    onTap: onSettings!,
                  ),
                  const SizedBox(height: 10),
                ],
                _PauseButton(
                  text: L.mainMenu.tr,
                  icon: Icons.home,
                  color: CyberColors.purple,
                  onTap: onMenu,
                ),
                const SizedBox(height: 20),

                // Hint text
                Text(
                  L.tapToResume.tr,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.grey.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PauseButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PauseButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: _isPressed
              ? widget.color.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isPressed ? widget.color : widget.color.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(
              widget.icon,
              color: widget.color,
              size: 18,
            ),
            const SizedBox(width: 14),
            Text(
              widget.text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: widget.color,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
