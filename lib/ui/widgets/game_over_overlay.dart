import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/global_leaderboard_service.dart';
import '../../services/leaderboard_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class GameOverOverlay extends StatefulWidget {
  final int score;
  final int level;
  final int lines;
  final int? maxCombo;
  final Duration? playTime;
  final VoidCallback onRestart;
  final VoidCallback onMenu;
  final VoidCallback? onLeaderboard;
  final VoidCallback? onUploadSuccess;
  final bool alreadySynced; // Whether the score was already synced from HighScoreOverlay

  const GameOverOverlay({
    super.key,
    required this.score,
    required this.level,
    required this.lines,
    this.maxCombo,
    this.playTime,
    required this.onRestart,
    required this.onMenu,
    this.onLeaderboard,
    this.onUploadSuccess,
    this.alreadySynced = false,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Upload state
  bool _uploadToCloud = true;  // Default ON when bound
  bool _isUploading = false;
  bool _uploaded = false;
  String? _uploadError;
  bool _isNewRecord = false;
  int _rank = 0;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // If already synced from HighScoreOverlay, mark as uploaded
    if (widget.alreadySynced) {
      _uploaded = true;
      _uploadToCloud = true;
    } else if (AuthService.instance.isBound && _uploadToCloud) {
      // Auto upload if bound and toggle is on (and not already synced)
      _autoUploadScore();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _formatTime(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _autoUploadScore() async {
    // Small delay to let the UI render first
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && !_uploaded && !_isUploading) {
      await _uploadScore();
    }
  }

  Future<void> _uploadScore() async {
    if (_isUploading || _uploaded) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    debugPrint('GameOverOverlay: Uploading score=${widget.score}, level=${widget.level}, lines=${widget.lines}');

    final result = await GlobalLeaderboardService.instance.submitScore(
      score: widget.score,
      lines: widget.lines,
      level: widget.level,
      source: 'game_daily',
    );

    if (mounted) {
      setState(() {
        _isUploading = false;
        if (result != null) {
          _uploaded = true;
          _isNewRecord = result.isNewRecord;
          _rank = result.rank;
          debugPrint('GameOverOverlay: Upload success, isNewRecord=${result.isNewRecord}, rank=${result.rank}');
          // Mark local leaderboard entry as synced
          LeaderboardService.instance.markAsSynced(widget.score);
          widget.onUploadSuccess?.call();
        } else {
          _uploadError = 'Upload failed';
        }
      });
    }
  }

  void _onToggleChanged(bool value) {
    setState(() {
      _uploadToCloud = value;
    });

    // If turned on and not yet uploaded, upload now
    if (value && !_uploaded && !_isUploading && AuthService.instance.isBound) {
      _uploadScore();
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
          color: Colors.black.withValues(alpha: 0.85),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // GAME OVER title
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        final glowIntensity = _glowAnimation.value;
                        final scale = 1.0 + (glowIntensity - 0.5) * 0.03;
                        return Transform.scale(
                          scale: scale,
                          child: _buildGameOverTitle(glowIntensity),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Score card with gradient border
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [CyberColors.cyan, CyberColors.purple],
                        ),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0A12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Text(
                              L.finalScore.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'monospace',
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.score}',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: Color(0xFFFFB800),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem(L.level.tr, '${widget.level}', CyberColors.green),
                                _buildStatItem(L.lines.tr, '${widget.lines}', CyberColors.cyan),
                                _buildStatItem(L.maxCombo.tr, 'x${widget.maxCombo ?? 0}', CyberColors.orange),
                                _buildStatItem(L.time.tr, _formatTime(widget.playTime), CyberColors.pink),
                              ],
                            ),

                            // Cloud upload section - only show when bound
                            if (isBound) ...[
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 12),
                              _buildCloudUploadSection(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _OutlineButton(
                            text: L.playAgain.tr,
                            icon: Icons.refresh,
                            color: CyberColors.green,
                            onTap: widget.onRestart,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _OutlineButton(
                            text: L.mainMenu.tr,
                            icon: Icons.home,
                            color: CyberColors.cyan,
                            onTap: widget.onMenu,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _OutlineButton(
                      text: L.leaderboard.tr,
                      icon: Icons.emoji_events,
                      color: CyberColors.yellow,
                      onTap: widget.onLeaderboard ?? () {},
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCloudUploadSection() {
    return Row(
      children: [
        // Cloud icon and label
        Icon(
          _uploaded ? Icons.cloud_done : Icons.cloud_upload_outlined,
          color: _uploaded ? CyberColors.green : CyberColors.purple,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L.uploadToGlobal.tr,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: _uploaded ? CyberColors.green : Colors.white,
                ),
              ),
              // Status text
              if (_isUploading)
                Text(
                  L.uploading.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.grey[500],
                  ),
                )
              else if (_uploaded)
                Text(
                  _isNewRecord ? 'New Record! Rank #$_rank' : 'Rank #$_rank',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: _isNewRecord ? CyberColors.yellow : CyberColors.green,
                  ),
                )
              else if (_uploadError != null)
                GestureDetector(
                  onTap: _uploadScore,
                  child: Text(
                    '$_uploadError - Tap to retry',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: CyberColors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Toggle or loading indicator
        if (_isUploading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: CyberColors.purple,
              strokeWidth: 2,
            ),
          )
        else if (_uploaded)
          const Icon(
            Icons.check_circle,
            color: CyberColors.green,
            size: 24,
          )
        else
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: _uploadToCloud,
              onChanged: _onToggleChanged,
              activeColor: CyberColors.purple,
              activeTrackColor: CyberColors.purple.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.grey[600],
              inactiveTrackColor: Colors.grey[800],
            ),
          ),
      ],
    );
  }

  Widget _buildGameOverTitle(double glowIntensity) {
    final gameOverText = L.gameOver.tr;
    final colors = [
      const Color(0xFFFF00FF),
      const Color(0xFFFF1493),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFD700),
      const Color(0xFFFF8C00),
      const Color(0xFFFF6B6B),
      const Color(0xFFFF1493),
      const Color(0xFFFF00FF),
    ];

    final widgets = <Widget>[];
    int colorIndex = 0;

    for (int i = 0; i < gameOverText.length; i++) {
      final char = gameOverText[i];
      if (char == ' ') {
        widgets.add(const SizedBox(width: 16));
      } else {
        widgets.add(_buildGlowText(
          char,
          colors[colorIndex % colors.length],
          glowIntensity,
        ));
        colorIndex++;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widgets,
    );
  }

  Widget _buildGlowText(String char, Color color, double intensity) {
    return Text(
      char,
      style: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
        color: color,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: intensity * 0.3),
            blurRadius: 2,
          ),
          Shadow(
            color: color.withValues(alpha: intensity),
            blurRadius: 8 + (intensity * 12),
          ),
          Shadow(
            color: color.withValues(alpha: intensity * 0.7),
            blurRadius: 20 + (intensity * 25),
          ),
          Shadow(
            color: color.withValues(alpha: intensity * 0.4),
            blurRadius: 35 + (intensity * 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            color: Colors.grey[600],
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: color,
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: color,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
