import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/cyber_theme.dart';
import '../widgets/menu_background.dart';
import '../widgets/legal_consent_inline.dart';
import '../../services/localization_service.dart';
import '../../services/auth_service.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback onStartGame;
  final VoidCallback onSettings;
  final VoidCallback onLeaderboard;
  final VoidCallback? onControls;
  final VoidCallback? onBind;
  final VoidCallback? onBadges;
  final VoidCallback? onAccount;
  final VoidCallback? onChallenge;

  const MenuScreen({
    super.key,
    required this.onStartGame,
    required this.onSettings,
    required this.onLeaderboard,
    this.onControls,
    this.onBind,
    this.onBadges,
    this.onAccount,
    this.onChallenge,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _showPrompt = false;
  String _version = '';

  @override
  void initState() {
    super.initState();

    // Load version
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });

    // Glow animation for title
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Show prompt after delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _showPrompt = true);
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MenuBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 40),
                              _buildTitle(),
                              const SizedBox(height: 20),
                              Text(
                                _version.isNotEmpty ? 'v$_version' : '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: Colors.grey.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 120),
                              AnimatedOpacity(
                                opacity: _showPrompt ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeInOut,
                                child: _buildMenuSection(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // Avatar button - top right
              Positioned(
                top: 8,
                right: 16,
                child: _buildAvatarButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    const double fontSize = 54;
    const double letterSpacing = 5;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // CYBER - iOS: cyan → blue → purple gradient
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF00FFFF),  // Cyan
                  Color(0xFF00AAFF),  // Blue
                  Color(0xFF8844FF),  // Purple
                ],
              ).createShader(bounds),
              child: Text(
                'CYBER',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                                    color: Colors.white,
                  letterSpacing: letterSpacing,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF00FFFF).withValues(alpha: _glowAnimation.value * 0.8),
                      blurRadius: _glowAnimation.value * 25,
                    ),
                    // Extra shadow for bolder text
                    const Shadow(
                      color: Color(0xFF00FFFF),
                      blurRadius: 2,
                      offset: Offset(0.5, 0.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            // BLOCKX - iOS: purple/pink → blue → orange/red with X in bright red
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF00FF),  // Magenta/Pink
                      Color(0xFFAA44FF),  // Purple
                      Color(0xFF6666FF),  // Blue-purple
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'BLOCK',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                                            color: Colors.white,
                      letterSpacing: letterSpacing,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFF00FF).withValues(alpha: _glowAnimation.value * 0.7),
                          blurRadius: _glowAnimation.value * 25,
                        ),
                        // Extra shadow for bolder text
                        const Shadow(
                          color: Color(0xFFFF00FF),
                          blurRadius: 2,
                          offset: Offset(0.5, 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                // X - iOS: bright red/orange
                Text(
                  'X',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                                        color: const Color(0xFFFF4444),  // Bright red
                    letterSpacing: letterSpacing,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFF4444).withValues(alpha: _glowAnimation.value),
                        blurRadius: _glowAnimation.value * 30,
                      ),
                      // Extra shadow for bolder text
                      const Shadow(
                        color: Color(0xFFFF4444),
                        blurRadius: 2,
                        offset: Offset(0.5, 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvatarButton() {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final isBound = AuthService.instance.isBound;
        return GestureDetector(
          onTap: isBound
              ? (widget.onAccount ?? () {})
              : (widget.onBind ?? () {}),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isBound
                    ? CyberColors.cyan.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.4),
                width: 1.5,
              ),
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Icon(
              isBound ? Icons.person : Icons.person_outline,
              color: isBound ? CyberColors.cyan : Colors.grey,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  // ── Button size constants ──────────────────────────────────
  // Primary  : full-width CTA (START GAME)
  // Secondary: half-width pair  (CHALLENGE, BADGES)
  // Functional: compact trio    (LEADERBOARD, SETTINGS, CONTROLS)
  static const double _primaryH   = 52;
  static const double _secondaryH = 44;
  static const double _funcH      = 40;
  static const double _maxW       = 300.0; // max content width for centering
  static const double _rowGap     = 10.0;  // vertical gap between rows
  static const double _colGap     = 10.0;  // horizontal gap between buttons

  Widget _buildMenuSection() {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Column(
            children: [
              // ── Row 1: PRIMARY — START GAME (full width) ──
              _StyledButton(
                title: L.startGame.tr,
                icon: Icons.play_arrow,
                color: CyberColors.green,
                height: _primaryH,
                fontSize: 15,
                iconSize: 20,
                borderWidth: 1.5,
                expanded: true,
                onTap: widget.onStartGame,
              ),
              const SizedBox(height: _rowGap),

              // ── Row 2: SECONDARY — CHALLENGE + BADGES (equal half-width) ──
              Row(
                children: [
                  Expanded(
                    child: _StyledButton(
                      title: L.challenge.tr,
                      icon: Icons.sports_kabaddi,
                      color: CyberColors.pink,
                      height: _secondaryH,
                      fontSize: 12,
                      iconSize: 16,
                      borderWidth: 1.0,
                      expanded: true,
                      onTap: widget.onChallenge ?? () {},
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    child: _StyledButton(
                      title: L.badges.tr,
                      icon: Icons.military_tech,
                      color: CyberColors.orange,
                      height: _secondaryH,
                      fontSize: 12,
                      iconSize: 16,
                      borderWidth: 1.0,
                      expanded: true,
                      onTap: widget.onBadges ?? () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _rowGap),

              // ── Row 3: FUNCTIONAL — LEADERBOARD + SETTINGS + CONTROLS (equal thirds) ──
              Row(
                children: [
                  Expanded(
                    child: _StyledButton(
                      title: L.leaderboard.tr,
                      icon: Icons.emoji_events,
                      color: CyberColors.yellow,
                      height: _funcH,
                      fontSize: 9,
                      iconSize: 14,
                      borderWidth: 1.0,
                      expanded: true,
                      onTap: widget.onLeaderboard,
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    child: _StyledButton(
                      title: L.settings.tr,
                      icon: Icons.settings,
                      color: CyberColors.cyan,
                      height: _funcH,
                      fontSize: 9,
                      iconSize: 14,
                      borderWidth: 1.0,
                      expanded: true,
                      onTap: widget.onSettings,
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    child: _StyledButton(
                      title: L.controls.tr,
                      icon: Icons.gamepad,
                      color: CyberColors.cyan,
                      height: _funcH,
                      fontSize: 9,
                      iconSize: 14,
                      borderWidth: 1.0,
                      expanded: true,
                      onTap: widget.onControls ?? () {},
                    ),
                  ),
                ],
              ),

              // Legal consent notice
              const SizedBox(height: 20),
              const LegalConsentInline(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Website text with gradient (matching iOS)
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              CyberColors.cyan.withValues(alpha: 0.6),
              CyberColors.purple.withValues(alpha: 0.6),
            ],
          ).createShader(bounds),
          child: const Text(
            'C Y B E R  B L O C K X . C O M',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              letterSpacing: 1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A  C Y B E R P U N K  P U Z Z L E  E X P E R I E N C E',
          style: TextStyle(
            fontSize: 8,
            fontFamily: 'monospace',
            letterSpacing: 0.5,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Unified menu button with configurable size hierarchy.
///
/// Size classes driven by the caller:
///   Primary   — height 52, fontSize 15, iconSize 20, borderWidth 1.5
///   Secondary — height 44, fontSize 12, iconSize 16, borderWidth 1.0
///   Functional— height 40, fontSize  9, iconSize 14, borderWidth 1.0
class _StyledButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final double height;
  final double fontSize;
  final double iconSize;
  final double borderWidth;
  final bool expanded; // true = fill available width
  final VoidCallback onTap;

  const _StyledButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.height,
    required this.fontSize,
    required this.iconSize,
    required this.borderWidth,
    this.expanded = false,
    required this.onTap,
  });

  @override
  State<_StyledButton> createState() => _StyledButtonState();
}

class _StyledButtonState extends State<_StyledButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: widget.height,
        decoration: BoxDecoration(
          color: _isPressed ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _isPressed ? color : color.withValues(alpha: 0.5),
            width: widget.borderWidth,
          ),
          boxShadow: _isPressed
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)]
              : null,
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: _isPressed ? Colors.white : color,
              size: widget.iconSize,
            ),
            SizedBox(width: widget.iconSize > 16 ? 8 : 5),
            Flexible(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: _isPressed ? Colors.white : color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
