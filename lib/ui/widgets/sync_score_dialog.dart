import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/leaderboard_service.dart';
import '../../services/global_leaderboard_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class SyncScoreDialog extends StatefulWidget {
  final List<LeaderboardEntry> localScores;
  final Function(List<LeaderboardEntry>) onSync;
  final VoidCallback onSkip;

  const SyncScoreDialog({
    super.key,
    required this.localScores,
    required this.onSync,
    required this.onSkip,
  });

  @override
  State<SyncScoreDialog> createState() => _SyncScoreDialogState();
}

class _SyncScoreDialogState extends State<SyncScoreDialog> {
  final Set<int> _selectedIndices = {};
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Default select highest score
    if (widget.localScores.isNotEmpty) {
      _selectedIndices.add(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: CyberColors.cyan.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.cloud_upload, color: CyberColors.cyan, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    L.syncScores.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: CyberColors.cyan,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              L.syncScoresDescription.tr,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Scores list (max 5)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.2)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.localScores.take(5).length,
                itemBuilder: (context, index) {
                  final entry = widget.localScores[index];
                  final isSelected = _selectedIndices.contains(index);

                  return InkWell(
                    onTap: _isUploading
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedIndices.remove(index);
                              } else {
                                _selectedIndices.add(index);
                              }
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CyberColors.cyan.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: index > 0
                            ? Border(
                                top: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Checkbox
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? CyberColors.cyan
                                    : Colors.grey.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              color: isSelected
                                  ? CyberColors.cyan.withValues(alpha: 0.2)
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: CyberColors.cyan,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Rank
                          Container(
                            width: 28,
                            alignment: Alignment.center,
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: index == 0
                                    ? CyberColors.yellow
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Score
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatScore(entry.score),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? CyberColors.cyan
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Lv.${entry.level} | ${entry.lines} ${L.lines.tr}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Date
                          Text(
                            _formatDate(entry.date),
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Selected count
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${_selectedIndices.length} ${L.selected.tr}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.grey[500],
                ),
              ),
            ),

            // Buttons
            if (_isUploading)
              Column(
                children: [
                  const CircularProgressIndicator(color: CyberColors.cyan),
                  const SizedBox(height: 8),
                  Text(
                    L.uploading.tr,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSkip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        L.skip.tr,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedIndices.isEmpty ? null : _uploadScores,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: CyberColors.cyan,
                        disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        L.upload.tr,
                        style: TextStyle(
                          color: _selectedIndices.isEmpty
                              ? Colors.grey[600]
                              : Colors.black,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int score) {
    final str = score.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  Future<void> _uploadScores() async {
    setState(() => _isUploading = true);

    final selectedScores = _selectedIndices
        .map((i) => widget.localScores[i])
        .toList();

    // Upload each selected score using the new submitScore API
    for (final entry in selectedScores) {
      debugPrint('SyncScoreDialog: Uploading score=${entry.score}, level=${entry.level}, lines=${entry.lines}');
      await GlobalLeaderboardService.instance.submitScore(
        score: entry.score,
        lines: entry.lines,
        level: entry.level,
        source: 'bind_update',  // First-time binding sync
      );
    }

    await widget.onSync(selectedScores);
  }
}
