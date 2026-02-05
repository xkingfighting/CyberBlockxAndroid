import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class HighScoreOverlay extends StatefulWidget {
  final int score;
  final int rank;
  final VoidCallback onSkip;
  final Future<void> Function(String name, bool syncToCloud) onSubmit;

  const HighScoreOverlay({
    super.key,
    required this.score,
    required this.rank,
    required this.onSkip,
    required this.onSubmit,
  });

  @override
  State<HighScoreOverlay> createState() => _HighScoreOverlayState();
}

class _HighScoreOverlayState extends State<HighScoreOverlay>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _starController;
  late Animation<double> _starAnimation;

  bool _syncToCloud = true; // Default ON when bound
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with last player name (matching iOS behavior)
    final lastName = LeaderboardService.instance.lastPlayerName;
    _nameController = TextEditingController(text: lastName.isNotEmpty ? lastName : 'PLAYER');

    // Subtle glow animation (reduced intensity)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Star wobble animation (matching iOS: ±10 degrees)
    _starController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _starAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _starController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _glowController.dispose();
    _starController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final name = _nameController.text.trim();
    final isBound = AuthService.instance.isBound;
    await widget.onSubmit(
      name.isEmpty ? 'PLAYER' : name,
      isBound && _syncToCloud,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBound = AuthService.instance.isBound;

    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.7),
          child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                final glowIntensity = _glowAnimation.value;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        CyberColors.cyan.withOpacity(0.6),
                        CyberColors.purple.withOpacity(0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CyberColors.cyan.withOpacity(0.2),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title with stars
                        _buildTitle(glowIntensity),
                        const SizedBox(height: 8),

                        // Rank
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${L.yourRank.tr} ',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'monospace',
                                color: Colors.grey[400],
                              ),
                            ),
                            Text(
                              '#${widget.rank}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: CyberColors.cyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Score with glow
                        _buildScoreDisplay(glowIntensity),
                        const SizedBox(height: 24),

                        // Enter name label
                        Text(
                          L.enterName.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: CyberColors.cyan.withOpacity(0.9),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Text input field
                        _buildNameInput(),

                        // Cloud sync toggle (only when bound)
                        if (isBound) ...[
                          const SizedBox(height: 16),
                          _buildCloudSyncToggle(),
                        ],

                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildSkipButton(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildSubmitButton(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildCloudSyncToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _syncToCloud
            ? CyberColors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _syncToCloud
              ? CyberColors.green.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _syncToCloud ? Icons.cloud_upload : Icons.cloud_off,
            color: _syncToCloud ? CyberColors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              L.uploadToGlobal.tr,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: _syncToCloud ? CyberColors.green : Colors.grey,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _syncToCloud,
              onChanged: _isSubmitting ? null : (value) {
                setState(() {
                  _syncToCloud = value;
                });
              },
              activeColor: CyberColors.green,
              activeTrackColor: CyberColors.green.withOpacity(0.3),
              inactiveThumbColor: Colors.grey[600],
              inactiveTrackColor: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(double glowIntensity) {
    return AnimatedBuilder(
      animation: _starAnimation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left star with wobble animation (opposite direction)
            Transform.rotate(
              angle: -_starAnimation.value * 3.14159 / 180, // Opposite direction
              child: Icon(
                Icons.star,
                color: CyberColors.yellow,
                size: 24,
                shadows: [
                  Shadow(
                    color: CyberColors.yellow.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [CyberColors.yellow, CyberColors.orange],
              ).createShader(bounds),
              child: Text(
                L.newHighScore.tr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.white,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: CyberColors.yellow.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right star with wobble animation
            Transform.rotate(
              angle: _starAnimation.value * 3.14159 / 180,
              child: Icon(
                Icons.star,
                color: CyberColors.yellow,
                size: 24,
                shadows: [
                  Shadow(
                    color: CyberColors.yellow.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScoreDisplay(double glowIntensity) {
    // Subtle glow effect matching iOS - reduced intensity
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, CyberColors.cyan],
      ).createShader(bounds),
      child: Text(
        '${widget.score}',
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          color: Colors.white,
          shadows: [
            // Subtle cyan glow only
            Shadow(
              color: CyberColors.cyan.withOpacity(0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFF0A0A12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CyberColors.cyan.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: TextField(
            controller: _nameController,
            textAlign: TextAlign.center,
            enabled: !_isSubmitting,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: LeaderboardService.instance.lastPlayerName.isNotEmpty
                  ? LeaderboardService.instance.lastPlayerName
                  : 'PLAYER',
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
            ),
            maxLength: 12,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : widget.onSkip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: const Color(0xFF0A0A12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isSubmitting
                    ? Colors.grey.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                L.skip.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _isSubmitting ? Colors.grey[700] : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _handleSubmit,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: _isSubmitting
                ? LinearGradient(
                    colors: [Colors.grey[700]!, Colors.grey[600]!],
                  )
                : const LinearGradient(
                    colors: [CyberColors.green, Color(0xFF00CED1)],
                  ),
            boxShadow: _isSubmitting
                ? []
                : [
                    BoxShadow(
                      color: CyberColors.green.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[400],
                  ),
                )
              else
                Icon(
                  Icons.check_circle,
                  color: Colors.black.withOpacity(0.8),
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                _isSubmitting ? L.submitting.tr : L.submit.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _isSubmitting
                      ? Colors.grey[400]
                      : Colors.black.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
