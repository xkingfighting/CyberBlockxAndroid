import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';

class BadgesScreen extends StatefulWidget {
  final VoidCallback onClose;

  const BadgesScreen({
    super.key,
    required this.onClose,
  });

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  bool _isLoading = true;
  String? _error;
  List<BadgeData> _badges = [];
  int _unlockedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    if (!AuthService.instance.isBound) {
      setState(() {
        _isLoading = false;
        _error = LocalizationService.instance.tr(L.errorConnectWalletFirst);
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = LocalizationService.instance.tr(L.errorAuthFailed);
        });
        return;
      }

      // Fetch all badges and user badges in parallel
      final results = await Future.wait([
        ApiService.instance.getAllBadges(accessToken: token),
        ApiService.instance.getUserBadges(accessToken: token),
      ]);

      final allBadgesResult = results[0];
      final userBadgesResult = results[1];

      if (mounted) {
        if (allBadgesResult.isSuccess && allBadgesResult.data != null) {
          // Get user's earned badge IDs
          final earnedBadgeIds = <String>{};
          if (userBadgesResult.isSuccess && userBadgesResult.data != null) {
            for (final badge in userBadgesResult.data!.badges) {
              earnedBadgeIds.add(badge.id);
            }
          }

          // Mark badges as unlocked if user has earned them
          final badges = allBadgesResult.data!.badges.map((badge) {
            final isUnlocked = earnedBadgeIds.contains(badge.id);
            return BadgeData(
              id: badge.id,
              name: badge.name,
              description: badge.description,
              icon: badge.icon,
              imageUrl: badge.imageUrl,
              unlocked: isUnlocked,
              claimable: badge.claimable,
              unlockedAt: badge.unlockedAt,
              progress: badge.progress,
              target: badge.target,
            );
          }).toList();

          setState(() {
            _isLoading = false;
            _badges = badges;
            _unlockedCount = earnedBadgeIds.length;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = allBadgesResult.errorMessage ?? LocalizationService.instance.tr(L.errorLoadBadgesFailed);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _claimBadge(BadgeData badge) async {
    if (!badge.claimable) return;

    final token = await AuthService.instance.getValidAccessToken();
    if (token == null) return;

    final result = await ApiService.instance.claimBadge(
      accessToken: token,
      badgeId: badge.id,
    );

    if (result.isSuccess) {
      // Refresh badges list
      _loadBadges();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Badge "${badge.name}" claimed!'),
            backgroundColor: CyberColors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to claim badge'),
            backgroundColor: CyberColors.red,
          ),
        );
      }
    }
  }

  void _showBadgeDetail(BadgeData badge) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _BadgeDetailView(
            badge: badge,
            onClaim: badge.claimable ? () => _claimBadge(badge) : null,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: CyberColors.orange),
                    )
                  : _error != null
                      ? _buildError()
                      : _badges.isEmpty
                          ? _buildEmpty()
                          : _buildBadgesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            Icons.military_tech,
            color: CyberColors.orange,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            L.badges.tr,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: CyberColors.orange,
            ),
          ),
          const Spacer(),
          // Badge count
          if (!_isLoading && _error == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CyberColors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CyberColors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$_unlockedCount/${_badges.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: CyberColors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: CyberColors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadBadges,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CyberColors.orange,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: Colors.grey[600],
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No badges available yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontFamily: 'monospace',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesList() {
    return RefreshIndicator(
      onRefresh: _loadBadges,
      color: CyberColors.orange,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _badges.length,
        itemBuilder: (context, index) {
          final badge = _badges[index];
          return _BadgeCard(
            badge: badge,
            onTap: () => _showBadgeDetail(badge),
            onClaim: badge.claimable ? () => _claimBadge(badge) : null,
          );
        },
      ),
    );
  }
}

class _BadgeCard extends StatefulWidget {
  final BadgeData badge;
  final VoidCallback? onTap;
  final VoidCallback? onClaim;

  const _BadgeCard({
    required this.badge,
    this.onTap,
    this.onClaim,
  });

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.02), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.02, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onTap() {
    _shakeController.forward(from: 0.0);
    widget.onTap?.call();
  }

  IconData _getIconForBadge() {
    switch (widget.badge.icon?.toLowerCase()) {
      case 'star':
        return Icons.star;
      case 'trophy':
      case 'emoji_events':
        return Icons.emoji_events;
      case 'flash':
      case 'bolt':
        return Icons.flash_on;
      case 'speed':
        return Icons.speed;
      case 'layers':
        return Icons.layers;
      case 'workspace_premium':
      case 'premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.military_tech;
    }
  }

  Widget _buildBadgeIcon(BadgeData badge, Color color) {
    Widget iconWidget;

    if (badge.imageUrl != null) {
      iconWidget = Image.network(
        badge.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          badge.unlocked ? _getIconForBadge() : Icons.lock,
          color: color,
          size: 56,
        ),
      );
    } else {
      iconWidget = Icon(
        badge.unlocked ? _getIconForBadge() : Icons.lock,
        color: color,
        size: 56,
      );
    }

    // Apply grayscale filter for unearned badges
    if (!badge.unlocked) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Opacity(
          opacity: 0.6,
          child: iconWidget,
        ),
      );
    }

    return iconWidget;
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final color = badge.unlocked ? CyberColors.orange : Colors.grey[700]!;

    return GestureDetector(
      onTap: _onTap,
      child: Container(
        decoration: BoxDecoration(
          color: badge.unlocked
              ? CyberColors.orange.withValues(alpha: 0.08)
              : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.unlocked
                ? CyberColors.orange.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Badge content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge icon - Apple Watch style
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _shakeAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: badge.unlocked
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: CyberColors.orange.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            )
                          : null,
                      child: _buildBadgeIcon(badge, color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Badge name
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: badge.unlocked ? Colors.white : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Badge description
                  Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: badge.unlocked ? Colors.grey[400] : Colors.grey[600],
                      height: 1.2,
                    ),
                  ),
                  // Progress bar if available
                  if (badge.progress != null && badge.target != null && !badge.unlocked) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: badge.target! > 0 ? badge.progress! / badge.target! : 0,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(CyberColors.orange.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${badge.progress}/${badge.target}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Unlocked indicator
            if (badge.unlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: CyberColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            // Claimable indicator
            if (badge.claimable && !badge.unlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CyberColors.yellow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'CLAIM',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen badge detail view with 3D rotation
class _BadgeDetailView extends StatefulWidget {
  final BadgeData badge;
  final VoidCallback? onClaim;

  const _BadgeDetailView({
    required this.badge,
    this.onClaim,
  });

  @override
  State<_BadgeDetailView> createState() => _BadgeDetailViewState();
}

class _BadgeDetailViewState extends State<_BadgeDetailView> with SingleTickerProviderStateMixin {
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  late AnimationController _resetController;
  late Animation<double> _resetAnimationX;
  late Animation<double> _resetAnimationY;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resetController.addListener(() {
      if (_isResetting) {
        setState(() {
          _rotationX = _resetAnimationX.value;
          _rotationY = _resetAnimationY.value;
        });
      }
    });
    _resetController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isResetting = false;
      }
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotationY += details.delta.dx * 0.01;
      _rotationX -= details.delta.dy * 0.01;
      // Clamp rotation to prevent over-rotation
      _rotationX = _rotationX.clamp(-0.5, 0.5);
      _rotationY = _rotationY.clamp(-0.5, 0.5);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Animate back to center with spring effect
    _isResetting = true;
    _resetAnimationX = Tween<double>(begin: _rotationX, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.elasticOut),
    );
    _resetAnimationY = Tween<double>(begin: _rotationY, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.elasticOut),
    );
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final isUnlocked = badge.unlocked;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {}, // Prevent closing when tapping badge
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 3D rotating badge
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
                    ..rotateX(_rotationX)
                    ..rotateY(_rotationY),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: isUnlocked
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: CyberColors.orange.withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          )
                        : null,
                    child: _buildBadgeImage(badge, isUnlocked),
                  ),
                ),
                const SizedBox(height: 32),
                // Badge name
                Text(
                  badge.name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isUnlocked ? CyberColors.orange : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 12),
                // Badge description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    badge.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                      color: isUnlocked ? Colors.grey[300] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Status indicator
                if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: CyberColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CyberColors.green.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: CyberColors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          L.badgeUnlocked.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: CyberColors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, color: Colors.grey[500], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          L.badgeLocked.tr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 40),
                // Close hint
                Text(
                  L.tapToClose.tr,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeImage(BadgeData badge, bool isUnlocked) {
    Widget imageWidget;

    if (badge.imageUrl != null) {
      imageWidget = Image.network(
        badge.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.military_tech,
          color: isUnlocked ? CyberColors.orange : Colors.grey[600],
          size: 120,
        ),
      );
    } else {
      imageWidget = Icon(
        Icons.military_tech,
        color: isUnlocked ? CyberColors.orange : Colors.grey[600],
        size: 120,
      );
    }

    // Apply grayscale for locked badges
    if (!isUnlocked) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: Opacity(
          opacity: 0.5,
          child: imageWidget,
        ),
      );
    }

    return imageWidget;
  }
}
