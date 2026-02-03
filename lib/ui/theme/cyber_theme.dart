import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cyberpunk color palette
class CyberColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceLight = Color(0xFF16213E);

  static const cyan = Color(0xFF00FFFF);
  static const pink = Color(0xFFFF00FF);
  static const purple = Color(0xFFAA00FF);
  static const orange = Color(0xFFFF8800);
  static const green = Color(0xFF00FF00);
  static const red = Color(0xFFFF0044);
  static const yellow = Color(0xFFFFFF00);
  static const blue = Color(0xFF0088FF);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB0B0B0);
  static const textMuted = Color(0xFF666666);
}

/// Cyberpunk text styles
class CyberTextStyles {
  static TextStyle get title => GoogleFonts.orbitron(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      );

  static TextStyle get subtitle => GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      );

  static TextStyle get heading => GoogleFonts.orbitron(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      );

  static TextStyle get body => GoogleFonts.shareTechMono(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get button => GoogleFonts.orbitron(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      );

  static TextStyle get score => GoogleFonts.orbitron(
        fontSize: 32,
        fontWeight: FontWeight.w900,
      );

  static TextStyle get label => GoogleFonts.shareTechMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      );
}

/// Cyberpunk theme data
class CyberTheme {
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CyberColors.background,
        colorScheme: const ColorScheme.dark(
          primary: CyberColors.cyan,
          secondary: CyberColors.pink,
          surface: CyberColors.surface,
          error: CyberColors.red,
        ),
        textTheme: TextTheme(
          displayLarge: CyberTextStyles.title,
          displayMedium: CyberTextStyles.subtitle,
          headlineMedium: CyberTextStyles.heading,
          bodyLarge: CyberTextStyles.body,
          labelLarge: CyberTextStyles.button,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: CyberColors.surface,
            foregroundColor: CyberColors.cyan,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: CyberColors.cyan, width: 2),
            ),
          ),
        ),
      );
}

/// Gradient text widget
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;

  const GradientText({
    super.key,
    required this.text,
    this.style,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// Glowing container
class GlowingContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  const GlowingContainer({
    super.key,
    required this.child,
    this.glowColor = CyberColors.cyan,
    this.glowRadius = 10,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CyberColors.surface.withOpacity(0.8),
        borderRadius: radius,
        border: Border.all(color: glowColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.2),
            blurRadius: glowRadius,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Cyber button
class CyberButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final IconData? icon;
  final bool expanded;

  const CyberButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = CyberColors.cyan,
    this.icon,
    this.expanded = false,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: _isPressed ? widget.color : CyberColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_isPressed ? 0.5 : 0.2),
              blurRadius: _isPressed ? 15 : 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                color: _isPressed ? Colors.black : widget.color,
                size: 20,
              ),
              const SizedBox(width: 10),
            ],
            Text(
              widget.text,
              style: CyberTextStyles.button.copyWith(
                color: _isPressed ? Colors.black : widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
