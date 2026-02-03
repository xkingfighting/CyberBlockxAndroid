import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/game_state.dart';
import '../../core/tetromino.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

/// Left HUD - Score, Level, Lines (matching iOS iPhoneLeftHUD)
class LeftHUD extends StatelessWidget {
  final GameState gameState;

  const LeftHUD({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58, // Match iOS width
      child: Padding(
        padding: const EdgeInsets.only(left: 2, top: 20), // Add 20px top padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Score (cyan, star icon)
            SideStatCard(
              label: L.score.tr,
              value: _formatNumber(gameState.scoring.score),
              icon: Icons.star,
              color: CyberColors.cyan,
              isLarge: true,
            ),
            const SizedBox(height: 8),

            // Level (green, bolt icon)
            SideStatCard(
              label: L.level.tr,
              value: '${gameState.scoring.level}',
              icon: Icons.bolt,
              color: CyberColors.green,
            ),
            const SizedBox(height: 8),

            // Lines (yellow, horizontal lines icon)
            SideStatCard(
              label: L.lines.tr,
              value: '${gameState.scoring.totalLines}',
              icon: Icons.menu,
              color: CyberColors.yellow,
            ),

            // Combo (only when active, orange, fire icon)
            if (gameState.scoring.combo > 1) ...[
              const SizedBox(height: 8),
              SideStatCard(
                label: L.combo.tr,
                value: '×${gameState.scoring.combo}',
                icon: Icons.local_fire_department,
                color: CyberColors.orange,
                isPulsing: true,
              ),
            ],

            const Spacer(),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Right HUD - Hold + Next pieces (matching iOS iPhoneRightHUD)
class RightHUD extends StatelessWidget {
  final GameState gameState;

  const RightHUD({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58, // Match iOS width
      child: Padding(
        padding: const EdgeInsets.only(right: 2, top: 15), // Move down 15px
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Hold piece (purple border)
            SidePieceCard(
              label: L.hold.tr,
              piece: gameState.holdPiece,
              accentColor: CyberColors.purple,
            ),

            // Divider line (vertical gradient)
            const SizedBox(height: 6),
            Container(
              width: 1,
              height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    CyberColors.cyan.withOpacity(0.5),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Next pieces queue (cyan)
            SideNextQueue(
              label: L.next.tr,
              pieces: gameState.previewQueue,
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Side Stat Card (matching iOS SideStatCard)
class SideStatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLarge;
  final bool isPulsing;

  const SideStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLarge = false,
    this.isPulsing = false,
  });

  @override
  State<SideStatCard> createState() => _SideStatCardState();
}

class _SideStatCardState extends State<SideStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with glow
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isPulsing ? _scaleAnimation.value : 1.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow
                    Icon(
                      widget.icon,
                      size: 14,
                      color: widget.color.withOpacity(0.5),
                    ),
                    // Icon
                    Icon(
                      widget.icon,
                      size: 12,
                      color: widget.color,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 3),

          // Value
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                widget.value,
                style: TextStyle(
                  fontSize: widget.isLarge ? 16 : 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: widget.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),

          // Label
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: widget.color.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Side Piece Card for Hold (matching iOS SidePieceCard)
class SidePieceCard extends StatelessWidget {
  final String label;
  final TetrominoType? piece;
  final Color accentColor;

  const SidePieceCard({
    super.key,
    required this.label,
    required this.piece,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: accentColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),

        // Piece box
        Container(
          width: 52,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentColor.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Corner accents
              CustomPaint(
                size: const Size(52, 46),
                painter: _MiniCornerPainter(color: accentColor, cornerSize: 6),
              ),
              // Piece or placeholder
              Center(
                child: piece != null
                    ? _CyberPiecePreview(
                        type: piece!,
                        blockSize: 11,
                        glowColor: accentColor,
                      )
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: accentColor.withOpacity(0.3),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Side Next Queue (matching iOS SideNextQueue)
class SideNextQueue extends StatelessWidget {
  final String label;
  final List<TetrominoType> pieces;

  const SideNextQueue({
    super.key,
    required this.label,
    required this.pieces,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Label
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
            color: CyberColors.cyan,
          ),
        ),
        const SizedBox(height: 4),

        // Next pieces vertically
        ...List.generate(
          min(3, pieces.length),
          (index) {
            final type = pieces[index];
            final isFirst = index == 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                width: 52,
                height: isFirst ? 46 : 38,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(isFirst ? 0.5 : 0.3),
                  borderRadius: BorderRadius.circular(isFirst ? 8 : 6),
                  border: Border.all(
                    color: isFirst
                        ? CyberColors.cyan.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    if (isFirst)
                      CustomPaint(
                        size: const Size(52, 46),
                        painter: _MiniCornerPainter(
                          color: CyberColors.cyan,
                          cornerSize: 6,
                        ),
                      ),
                    Center(
                      child: Opacity(
                        opacity: isFirst ? 1.0 : 0.6,
                        child: _CyberPiecePreview(
                          type: type,
                          blockSize: isFirst ? 11 : 9,
                          glowColor: isFirst ? CyberColors.cyan : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Mini Corner Painter
class _MiniCornerPainter extends CustomPainter {
  final Color color;
  final double cornerSize;

  _MiniCornerPainter({required this.color, required this.cornerSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Top Left
    final topLeftPath = Path()
      ..moveTo(0, cornerSize)
      ..lineTo(0, 0)
      ..lineTo(cornerSize, 0);
    canvas.drawPath(topLeftPath, paint);

    // Top Right
    final topRightPath = Path()
      ..moveTo(size.width - cornerSize, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, cornerSize);
    canvas.drawPath(topRightPath, paint);

    // Bottom Left
    final bottomLeftPath = Path()
      ..moveTo(0, size.height - cornerSize)
      ..lineTo(0, size.height)
      ..lineTo(cornerSize, size.height);
    canvas.drawPath(bottomLeftPath, paint);

    // Bottom Right
    final bottomRightPath = Path()
      ..moveTo(size.width - cornerSize, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - cornerSize);
    canvas.drawPath(bottomRightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cyber Piece Preview
class _CyberPiecePreview extends StatelessWidget {
  final TetrominoType type;
  final double blockSize;
  final Color glowColor;

  const _CyberPiecePreview({
    required this.type,
    required this.blockSize,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final shape = type.shapes[0];
    final color = type.color;

    // Calculate bounds
    int minX = 10, maxX = -10, minY = 10, maxY = -10;
    for (final p in shape) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final width = maxX - minX + 1;
    final height = maxY - minY + 1;
    final contentWidth = width * blockSize;
    final contentHeight = height * blockSize;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 5,
          ),
        ],
      ),
      child: SizedBox(
        width: contentWidth,
        height: contentHeight,
        child: CustomPaint(
          painter: _PiecePreviewPainter(
            shape: shape,
            color: color,
            minX: minX,
            minY: minY,
            maxY: maxY,
            blockSize: blockSize,
          ),
        ),
      ),
    );
  }
}

class _PiecePreviewPainter extends CustomPainter {
  final List<Point<int>> shape;
  final Color color;
  final int minX, minY, maxY;
  final double blockSize;

  _PiecePreviewPainter({
    required this.shape,
    required this.color,
    required this.minX,
    required this.minY,
    required this.maxY,
    required this.blockSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pieceColor = color;
    final darkerColor = Color.fromRGBO(
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
      1,
    );

    for (final p in shape) {
      final x = (p.x - minX) * blockSize;
      final y = (maxY - p.y) * blockSize;

      final rect = Rect.fromLTWH(x + 1, y + 1, blockSize - 2, blockSize - 2);

      // Outer glow
      final glowPaint = Paint()
        ..color = pieceColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        glowPaint,
      );

      // Main block with gradient
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          colors: [pieceColor, darkerColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        gradientPaint,
      );

      // Border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        borderPaint,
      );

      // Highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(rect.left + 3, rect.top + 2),
        Offset(rect.right - 3, rect.top + 2),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Legacy GameHUD for backwards compatibility
class GameHUD extends StatelessWidget {
  final GameState gameState;

  const GameHUD({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return RightHUD(gameState: gameState);
  }
}
