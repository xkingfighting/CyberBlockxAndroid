import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';
import '../widgets/menu_background.dart';
import '../../services/localization_service.dart';
import '../../services/auth_service.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback onStartGame;
  final VoidCallback onSettings;
  final VoidCallback onLeaderboard;
  final VoidCallback? onControls;
  final VoidCallback? onBind;

  const MenuScreen({
    super.key,
    required this.onStartGame,
    required this.onSettings,
    required this.onLeaderboard,
    this.onControls,
    this.onBind,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _showPrompt = false;

  @override
  void initState() {
    super.initState();

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
    return GestureDetector(
      onTap: widget.onStartGame,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MenuBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Main content area - takes all available space
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 40),

                            // Title
                            _buildTitle(),
                            const SizedBox(height: 20),

                            // Version text (simple, centered)
                            Text(
                              'v1.0',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                                color: Colors.grey.withOpacity(0.5),
                              ),
                            ),

                            const SizedBox(height: 200),

                            // Menu section - always rendered, opacity animated
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

                  // Footer fixed at bottom
                  _buildFooter(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
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
                      color: const Color(0xFF00FFFF).withOpacity(_glowAnimation.value * 0.8),
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
                          color: const Color(0xFFFF00FF).withOpacity(_glowAnimation.value * 0.7),
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
                        color: const Color(0xFFFF4444).withOpacity(_glowAnimation.value),
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

  Widget _buildMenuSection() {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final isBound = AuthService.instance.isBound;

        return Column(
          children: [
            // START GAME text
            Text(
              L.startGame.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),

            // Menu buttons - Row 1: LEADERBOARD, SETTINGS
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MenuButton(
                    title: L.leaderboard.tr,
                    icon: Icons.emoji_events,
                    color: CyberColors.yellow,
                    onTap: widget.onLeaderboard,
                  ),
                  const SizedBox(width: 12),
                  _MenuButton(
                    title: L.settings.tr,
                    icon: Icons.settings,
                    color: CyberColors.cyan,
                    onTap: widget.onSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Menu buttons - Row 2: CONTROLS, BIND
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MenuButton(
                    title: L.controls.tr,
                    icon: Icons.gamepad,
                    color: CyberColors.cyan,
                    onTap: widget.onControls ?? () {},
                  ),
                  const SizedBox(width: 12),
                  _MenuButton(
                    title: isBound
                        ? AuthService.instance.shortWalletAddress
                        : L.bindWallet.tr,
                    icon: isBound
                        ? Icons.check_circle
                        : Icons.account_balance_wallet,
                    color: isBound ? CyberColors.green : CyberColors.purple,
                    onTap: widget.onBind ?? () {},
                  ),
                ],
              ),
            ),
          ],
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
              CyberColors.cyan.withOpacity(0.6),
              CyberColors.purple.withOpacity(0.6),
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
            color: Colors.grey.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

/// Menu button matching iOS style - transparent background, border only
class _MenuButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isPressed ? widget.color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isPressed ? widget.color : widget.color.withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: _isPressed ? Colors.white : widget.color,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: _isPressed ? Colors.white : widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
