import 'package:flutter/material.dart';
import '../../services/leaderboard_service.dart';
import '../../services/global_leaderboard_service.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../models/global_leaderboard_entry.dart';
import '../theme/cyber_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onBind;

  const LeaderboardScreen({
    super.key,
    required this.onClose,
    this.onBind,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _animateRows = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Trigger row animations after a short delay (like iOS)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _animateRows = true;
        });
      }
    });

    // Fetch global leaderboard if bound
    if (AuthService.instance.isBound) {
      GlobalLeaderboardService.instance.fetchLeaderboard();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocalizationService.instance,
        AuthService.instance,
      ]),
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
                  _buildHeader(),
                  const SizedBox(height: 16),

                  // Tab bar
                  _buildTabBar(),
                  const SizedBox(height: 16),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLocalTab(),
                        _buildGlobalTab(),
                      ],
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_events,
              color: CyberColors.yellow,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              L.leaderboard.tr,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.yellow,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
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
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CyberColors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: CyberColors.cyan.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: CyberColors.cyan,
            width: 1,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: CyberColors.cyan,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          fontFamily: 'monospace',
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_android, size: 16),
                const SizedBox(width: 6),
                Text(L.localTab.tr),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AuthService.instance.isBound ? Icons.public : Icons.lock,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(L.globalTab.tr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalTab() {
    return Column(
      children: [
        // Table header
        _buildTableHeader(isGlobal: false),
        const SizedBox(height: 8),

        // Local leaderboard entries
        Expanded(
          child: ListenableBuilder(
            listenable: LeaderboardService.instance,
            builder: (context, _) {
              final entries = LeaderboardService.instance.entries;

              if (entries.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  return _AnimatedLocalRow(
                    index: index,
                    entry: entries[index],
                    animate: _animateRows,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalTab() {
    final isBound = AuthService.instance.isBound;

    if (!isBound) {
      return _buildLockedState();
    }

    return Column(
      children: [
        // Table header
        _buildTableHeader(isGlobal: true),
        const SizedBox(height: 8),

        // Global leaderboard entries
        Expanded(
          child: ListenableBuilder(
            listenable: GlobalLeaderboardService.instance,
            builder: (context, _) {
              final service = GlobalLeaderboardService.instance;

              if (service.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: CyberColors.cyan),
                );
              }

              if (service.hasError) {
                return _buildErrorState(service.errorMessage ?? 'Unknown error');
              }

              if (!service.hasData) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                color: CyberColors.cyan,
                backgroundColor: Colors.black,
                onRefresh: () => service.fetchLeaderboard(forceRefresh: true),
                child: ListView.builder(
                  itemCount: service.entries.length,
                  itemBuilder: (context, index) {
                    return _AnimatedGlobalRow(
                      index: index,
                      entry: service.entries[index],
                      animate: _animateRows,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader({required bool isGlobal}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CyberColors.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CyberColors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isGlobal ? 'WALLET' : L.playerName.tr.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              L.score.tr.toUpperCase(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              L.level.tr.toUpperCase(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              L.lines.tr.toUpperCase(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.cyan.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: CyberColors.yellow.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            L.noRecords.tr,
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'monospace',
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            L.playToRecord.tr,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: CyberColors.purple.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              L.globalLocked.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'monospace',
                color: Colors.grey[400],
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onBind,
            icon: const Icon(Icons.account_balance_wallet, size: 18),
            label: Text(
              L.bindNow.tr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CyberColors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: CyberColors.red.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'monospace',
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                GlobalLeaderboardService.instance.fetchLeaderboard(forceRefresh: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Retry',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CyberColors.cyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated local leaderboard row
class _AnimatedLocalRow extends StatefulWidget {
  final int index;
  final LeaderboardEntry entry;
  final bool animate;

  const _AnimatedLocalRow({
    required this.index,
    required this.entry,
    required this.animate,
  });

  @override
  State<_AnimatedLocalRow> createState() => _AnimatedLocalRowState();
}

class _AnimatedLocalRowState extends State<_AnimatedLocalRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    final delay = Duration(milliseconds: widget.index * 50);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.animate) {
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedLocalRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      final delay = Duration(milliseconds: widget.index * 50);
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.index + 1;
    final (rankColor, rankIcon) = _getRankStyle(rank);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: _buildRow(rank, rankColor, rankIcon, widget.entry.name),
          ),
        );
      },
    );
  }

  Widget _buildRow(int rank, Color rankColor, IconData? rankIcon, String name) {
    final isSynced = widget.entry.isSynced;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.1) : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.4) : CyberColors.cyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 20)
                : Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: rankColor,
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'monospace',
                      color: rank <= 3 ? rankColor : Colors.white.withOpacity(0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Cloud sync indicator
                if (isSynced) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: L.syncedToCloud.tr,
                    child: Icon(
                      Icons.cloud_done,
                      color: CyberColors.green.withOpacity(0.8),
                      size: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Text(
              _formatScore(widget.entry.score),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: rank == 1 ? CyberColors.yellow : CyberColors.cyan,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${widget.entry.level}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: CyberColors.green,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${widget.entry.lines}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: CyberColors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData?) _getRankStyle(int rank) {
    switch (rank) {
      case 1:
        return (CyberColors.yellow, Icons.emoji_events);
      case 2:
        return (Colors.grey.shade300, Icons.emoji_events);
      case 3:
        return (CyberColors.orange, Icons.emoji_events);
      default:
        return (Colors.white.withOpacity(0.7), null);
    }
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
}

/// Animated global leaderboard row
class _AnimatedGlobalRow extends StatefulWidget {
  final int index;
  final GlobalLeaderboardEntry entry;
  final bool animate;

  const _AnimatedGlobalRow({
    required this.index,
    required this.entry,
    required this.animate,
  });

  @override
  State<_AnimatedGlobalRow> createState() => _AnimatedGlobalRowState();
}

class _AnimatedGlobalRowState extends State<_AnimatedGlobalRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    final delay = Duration(milliseconds: widget.index * 50);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.animate) {
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AnimatedGlobalRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      final delay = Duration(milliseconds: widget.index * 50);
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rank = widget.entry.rank;
    final (rankColor, rankIcon) = _getRankStyle(rank);
    final isCurrentUser =
        widget.entry.walletAddress == AuthService.instance.walletAddress;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: _buildRow(rank, rankColor, rankIcon, isCurrentUser),
          ),
        );
      },
    );
  }

  Widget _buildRow(int rank, Color rankColor, IconData? rankIcon, bool isCurrentUser) {
    final shortAddress = _shortAddress(widget.entry.walletAddress);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? CyberColors.green.withOpacity(0.15)
            : rank <= 3
                ? rankColor.withOpacity(0.1)
                : Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentUser
              ? CyberColors.green.withOpacity(0.6)
              : rank <= 3
                  ? rankColor.withOpacity(0.4)
                  : CyberColors.cyan.withOpacity(0.2),
          width: isCurrentUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 20)
                : Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: rankColor,
                    ),
                  ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (isCurrentUser) ...[
                  const Icon(Icons.person, color: CyberColors.green, size: 14),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    shortAddress,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: rank <= 3 || isCurrentUser ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'monospace',
                      color: isCurrentUser
                          ? CyberColors.green
                          : rank <= 3
                              ? rankColor
                              : Colors.white.withOpacity(0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              _formatScore(widget.entry.bestScore),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: rank == 1 ? CyberColors.yellow : CyberColors.cyan,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${widget.entry.level}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: CyberColors.green,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${widget.entry.bestLines}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: CyberColors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData?) _getRankStyle(int rank) {
    switch (rank) {
      case 1:
        return (CyberColors.yellow, Icons.emoji_events);
      case 2:
        return (Colors.grey.shade300, Icons.emoji_events);
      case 3:
        return (CyberColors.orange, Icons.emoji_events);
      default:
        return (Colors.white.withOpacity(0.7), null);
    }
  }

  String _shortAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
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
}
