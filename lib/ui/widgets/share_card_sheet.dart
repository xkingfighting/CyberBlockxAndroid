import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/share_card_data.dart';
import '../../services/localization_service.dart';
import '../../services/share_card_service.dart';
import '../../ui/widgets/share_card_painter.dart';
import '../theme/cyber_theme.dart';

/// Bottom sheet for previewing and sharing the achievement card.
class ShareCardSheet extends StatefulWidget {
  final ShareCardData data;
  final Uint8List? gameScreenshot;

  const ShareCardSheet({super.key, required this.data, this.gameScreenshot});

  /// Show the share card sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, ShareCardData data, {Uint8List? gameScreenshot}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardSheet(data: data, gameScreenshot: gameScreenshot),
    );
  }

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet> {
  Uint8List? _previewBytes;
  bool _isGenerating = false;
  bool _isSharing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  Future<void> _generatePreview() async {
    setState(() => _isGenerating = true);

    final bytes = await ShareCardPainter.generateImage(widget.data, gameScreenshot: widget.gameScreenshot);

    if (mounted) {
      setState(() {
        _previewBytes = bytes;
        _isGenerating = false;
      });
    }
  }

  Future<void> _shareCard() async {
    if (_isSharing) return; // Debounce rapid taps
    setState(() {
      _isSharing = true;
      _statusMessage = null;
    });

    try {
      // Reuse preview bytes if available to avoid re-rendering
      final file = await ShareCardService.instance.generateCardFromBytes(
        widget.data,
        pngBytes: _previewBytes,
        gameScreenshot: widget.gameScreenshot,
      );

      if (file != null && mounted) {
        await ShareCardService.instance.shareGeneral(file, widget.data);
        if (mounted) {
          // Auto-close after successful share
          Navigator.of(context).pop();
          return;
        }
      } else {
        if (mounted) {
          setState(() => _statusMessage = 'Failed to generate');
        }
      }
    } catch (e) {
      debugPrint('ShareCard: Share failed: $e');
      if (mounted) {
        setState(() => _statusMessage = 'Share failed: $e');
      }
    }

    if (mounted) {
      setState(() => _isSharing = false);
    }
  }

  Future<void> _saveCard() async {
    if (_isSharing) return; // Debounce rapid taps
    setState(() {
      _isSharing = true;
      _statusMessage = null;
    });

    try {
      // Reuse preview bytes if available to avoid re-rendering
      final file = await ShareCardService.instance.generateCardFromBytes(
        widget.data,
        pngBytes: _previewBytes,
        gameScreenshot: widget.gameScreenshot,
      );

      if (file != null && mounted) {
        setState(() => _statusMessage = 'Saved to ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Save failed');
      }
    }

    if (mounted) {
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Container(
          height: screenH * 0.85,
          decoration: const BoxDecoration(
            color: CyberColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: CyberColors.cyan, width: 2),
              left: BorderSide(color: CyberColors.cyan, width: 1),
              right: BorderSide(color: CyberColors.cyan, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: CyberColors.cyan.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  L.shareTitle.tr,
                  style: CyberTextStyles.heading.copyWith(
                    color: CyberColors.cyan,
                    letterSpacing: 3,
                  ),
                ),
              ),

              // Preview
              Expanded(child: _buildPreview()),

              // Status message
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    _statusMessage!,
                    style: CyberTextStyles.body.copyWith(
                      color: CyberColors.green,
                      fontSize: 12,
                    ),
                  ),
                ),

              // Share buttons
              _buildShareButtons(),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    if (_isGenerating || _previewBytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: CyberColors.cyan),
            const SizedBox(height: 12),
            Text(
              L.generatingCard.tr,
              style: const TextStyle(
                color: CyberColors.cyan,
                fontSize: 12,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _previewBytes!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildShareButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Share button (primary)
          Expanded(
            child: _ShareActionButton(
              icon: Icons.share,
              label: L.shareAchievement.tr,
              color: CyberColors.cyan,
              isLoading: _isSharing,
              onTap: _shareCard,
            ),
          ),
          const SizedBox(width: 8),
          // Save button
          Expanded(
            child: _ShareActionButton(
              icon: Icons.save_alt,
              label: L.saveImage.tr,
              color: CyberColors.pink,
              isLoading: _isSharing,
              onTap: _saveCard,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: CyberColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: CyberTextStyles.body.copyWith(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
