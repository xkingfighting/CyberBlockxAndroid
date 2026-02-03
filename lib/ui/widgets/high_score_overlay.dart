import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class HighScoreOverlay extends StatefulWidget {
  final int score;
  final int rank;
  final VoidCallback onSkip;
  final Function(String name) onSubmit;

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
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'PLAYER');

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        CyberColors.cyan.withOpacity(0.3 + glowIntensity * 0.3),
                        CyberColors.purple.withOpacity(0.3 + glowIntensity * 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CyberColors.cyan.withOpacity(glowIntensity * 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
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

  Widget _buildTitle(double glowIntensity) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.star,
          color: CyberColors.yellow,
          size: 24,
          shadows: [
            Shadow(
              color: CyberColors.yellow.withOpacity(glowIntensity),
              blurRadius: 10,
            ),
          ],
        ),
        const SizedBox(width: 12),
        Text(
          L.newHighScore.tr,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: CyberColors.yellow,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: CyberColors.yellow.withOpacity(glowIntensity),
                blurRadius: 10,
              ),
              Shadow(
                color: CyberColors.orange.withOpacity(glowIntensity * 0.5),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.star,
          color: CyberColors.yellow,
          size: 24,
          shadows: [
            Shadow(
              color: CyberColors.yellow.withOpacity(glowIntensity),
              blurRadius: 10,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreDisplay(double glowIntensity) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: CyberColors.cyan.withOpacity(glowIntensity * 0.6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Text(
        '${widget.score}',
        style: TextStyle(
          fontSize: 56,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          color: CyberColors.cyan,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(glowIntensity * 0.3),
              blurRadius: 2,
            ),
            Shadow(
              color: CyberColors.cyan.withOpacity(glowIntensity),
              blurRadius: 15,
            ),
            Shadow(
              color: CyberColors.cyan.withOpacity(glowIntensity * 0.5),
              blurRadius: 30,
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
              hintText: 'PLAYER',
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
      onTap: widget.onSkip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColoredBox(
          color: const Color(0xFF0A0A12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.grey.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                L.skip.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.white,
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
      onTap: () {
        final name = _nameController.text.trim();
        widget.onSubmit(name.isEmpty ? 'PLAYER' : name);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [CyberColors.green, Color(0xFF00CED1)],
            ),
            boxShadow: [
              BoxShadow(
                color: CyberColors.green.withOpacity(0.4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.black.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                L.submit.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.black.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
