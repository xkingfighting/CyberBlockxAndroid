import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class ControlsScreen extends StatelessWidget {
  final VoidCallback onClose;

  const ControlsScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
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
                        L.controlsTitle.tr,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: CyberColors.green,
                        ),
                      ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
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
                      // Touch Controls Section
                      _buildSectionHeader(Icons.pan_tool, L.touchControls.tr, CyberColors.yellow),
                      const SizedBox(height: 12),
                      _buildControlsCard(),
                      const SizedBox(height: 28),

                      // Tips Section
                      _buildSectionHeader(Icons.lightbulb_outline, L.tips.tr, CyberColors.green),
                      const SizedBox(height: 12),
                      _buildTipsCard(),
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
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: color,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberColors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildControlRow(Icons.chevron_left, L.moveLeft.tr, CyberColors.cyan),
          _buildControlRow(Icons.chevron_right, L.moveRight.tr, CyberColors.cyan),
          _buildControlRow(Icons.rotate_right, L.rotateCW.tr, CyberColors.orange),
          _buildControlRow(Icons.rotate_left, L.rotateCCW.tr, CyberColors.orange),
          _buildControlRow(Icons.keyboard_arrow_down, L.softDrop.tr, CyberColors.green),
          _buildControlRow(Icons.keyboard_double_arrow_down, L.hardDrop.tr, CyberColors.green),
          _buildControlRow(Icons.copy, L.holdPiece.tr, CyberColors.purple),
          _buildControlRow(Icons.pause, L.pause.tr, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildControlRow(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CyberColors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTipRow(L.tip1.tr),
          const SizedBox(height: 12),
          _buildTipRow(L.tip2.tr),
          const SizedBox(height: 12),
          _buildTipRow(L.tip3.tr),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
