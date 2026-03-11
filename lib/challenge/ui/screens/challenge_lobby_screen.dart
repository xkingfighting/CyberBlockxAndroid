import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/localization_service.dart';
import '../../../ui/theme/cyber_theme.dart';
import '../../models/match_config.dart';
import '../../services/match_service.dart';

/// Challenge mode lobby - mode selection and matchmaking.
class ChallengeLobbyScreen extends StatefulWidget {
  final VoidCallback onReturnToMenu;
  final void Function(MatchConfig config) onMatchFound;
  final VoidCallback? onMatchHistory;

  const ChallengeLobbyScreen({
    super.key,
    required this.onReturnToMenu,
    required this.onMatchFound,
    this.onMatchHistory,
  });

  @override
  State<ChallengeLobbyScreen> createState() => _ChallengeLobbyScreenState();
}

class _ChallengeLobbyScreenState extends State<ChallengeLobbyScreen>
    with TickerProviderStateMixin {
  bool _isSearching = false;
  String _selectedMode = 'score_race';
  late AnimationController _pulseController;
  late AnimationController _searchController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _searchController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMatch() async {
    setState(() => _isSearching = true);

    final config = await MatchService.instance.searchMatch(
      modeType: _selectedMode,
      entryFee: 0,
    );

    if (!mounted) return;

    if (config != null) {
      widget.onMatchFound(config);
    } else {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L.matchNotFound.tr, style: CyberTextStyles.body),
            backgroundColor: CyberColors.surface,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: CyberColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: CyberColors.cyan),
                        onPressed: widget.onReturnToMenu,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        L.challenge.tr,
                        style: CyberTextStyles.subtitle.copyWith(color: CyberColors.cyan),
                      ),
                      const Spacer(),
                      if (widget.onMatchHistory != null)
                        GestureDetector(
                          onTap: widget.onMatchHistory,
                          child: Text(
                            L.history.tr,
                            style: CyberTextStyles.body.copyWith(
                              color: CyberColors.cyan,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Mode selection
                Expanded(
                  child: _isSearching ? _buildSearchingView() : _buildModeSelection(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            L.selectMode.tr,
            style: CyberTextStyles.heading.copyWith(
              color: CyberColors.textSecondary,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 32),

          _buildModeCard(
            id: 'score_race',
            title: L.scoreRace.tr,
            description: L.scoreRaceDesc.tr,
            icon: Icons.speed,
            color: CyberColors.cyan,
          ),
          const SizedBox(height: 16),
          _buildModeCard(
            id: 'survival',
            title: L.survival.tr,
            description: L.survivalDesc.tr,
            icon: Icons.shield,
            color: CyberColors.purple,
          ),
          const SizedBox(height: 40),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: CyberColors.cyan.withValues(alpha: 0.5 + _pulseController.value * 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CyberColors.cyan.withValues(alpha: 0.2 * _pulseController.value),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: CyberColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _searchMatch,
                      child: Center(
                        child: Text(
                          L.findOpponent.tr,
                          style: CyberTextStyles.button.copyWith(color: CyberColors.cyan),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String id,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMode == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : CyberColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : CyberColors.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : CyberColors.textMuted, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: CyberTextStyles.heading.copyWith(
                      color: isSelected ? color : CyberColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: CyberTextStyles.body.copyWith(
                      color: CyberColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _searchController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _searchController.value * 6.28,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: CyberColors.cyan, width: 3),
                    gradient: SweepGradient(
                      colors: [
                        CyberColors.cyan.withValues(alpha: 0),
                        CyberColors.cyan,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            L.searching.tr,
            style: CyberTextStyles.heading.copyWith(
              color: CyberColors.cyan,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L.findingOpponent.tr,
            style: CyberTextStyles.body.copyWith(
              color: CyberColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => setState(() => _isSearching = false),
            child: Text(
              L.cancel.tr,
              style: CyberTextStyles.body.copyWith(color: CyberColors.red),
            ),
          ),
        ],
      ),
    );
  }
}
