import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/leaderboard_service.dart';
import '../../solana/wallet_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';
import '../widgets/sync_score_dialog.dart';

class BindAccountScreen extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onBindSuccess;

  const BindAccountScreen({
    super.key,
    required this.onClose,
    this.onBindSuccess,
  });

  @override
  State<BindAccountScreen> createState() => _BindAccountScreenState();
}

class _BindAccountScreenState extends State<BindAccountScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = false;
  String? _error;
  bool _showWalletPicker = false;
  SolanaWallet? _selectedWallet;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _scanLineController;
  late AnimationController _particleController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();

    // Check for pending connect result from cold start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingConnectResult();
    });
  }

  /// Check if there's a pending wallet connection from cold start
  Future<void> _checkPendingConnectResult() async {
    // First check for pending signature (from sign message cold start)
    if (WalletService.instance.hasPendingSignResult) {
      final signature = WalletService.instance.consumePendingSignResult();
      if (signature != null && AuthService.instance.pendingWalletAddress != null) {
        debugPrint('BindScreen: Found pending sign result from cold start');
        await _completeBindingWithSignature(signature);
        return;
      }
    }

    // Then check for pending connect result
    if (WalletService.instance.hasPendingConnectResult) {
      final walletAddress = WalletService.instance.consumePendingConnectResult();
      if (walletAddress != null) {
        debugPrint('BindScreen: Found pending connect result from cold start: $walletAddress');
        // Continue with the binding process
        await _continueBindingWithAddress(walletAddress);
      }
    }
  }

  /// Complete binding with a signature (used for cold start recovery)
  Future<void> _completeBindingWithSignature(String signature) async {
    debugPrint('BindScreen: Completing binding with signature from cold start');
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final walletProvider = WalletService.instance.walletProviderName;
      final bindSuccess = await AuthService.instance.completeBinding(
        signature,
        walletProvider: walletProvider,
      );
      debugPrint('BindScreen: Bind result: $bindSuccess');
      if (bindSuccess) {
        debugPrint('BindScreen: Binding successful!');
        // Clear temporary wallet state to avoid interference with future bindings
        await WalletService.instance.clearTemporaryState();
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      } else {
        debugPrint('BindScreen: Binding failed');
      }
    } catch (e) {
      debugPrint('BindScreen: Exception: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Continue binding process with a wallet address (used for cold start recovery)
  Future<void> _continueBindingWithAddress(String walletAddress) async {
    debugPrint('BindScreen: Continuing binding with address: $walletAddress');
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      debugPrint('BindScreen: Getting nonce from server...');
      final nonceSuccess = await AuthService.instance.startBinding(walletAddress);
      debugPrint('BindScreen: Nonce result: $nonceSuccess');
      if (!nonceSuccess) {
        debugPrint('BindScreen: Failed to get nonce');
        setState(() => _isProcessing = false);
        return;
      }

      final message = AuthService.instance.messageToSign;
      debugPrint('BindScreen: Message to sign: $message');
      if (message == null) {
        debugPrint('BindScreen: No message to sign');
        setState(() {
          _error = 'Failed to get sign message';
          _isProcessing = false;
        });
        return;
      }

      debugPrint('BindScreen: Requesting signature from wallet...');
      final signature = await WalletService.instance.signMessage(message);
      debugPrint('BindScreen: Signature result: ${signature != null ? "received" : "null"}');
      if (signature == null) {
        debugPrint('BindScreen: Signature failed, canceling binding');
        AuthService.instance.cancelBinding();
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('BindScreen: Completing binding with signature...');
      final walletProvider = WalletService.instance.walletProviderName;
      final bindSuccess = await AuthService.instance.completeBinding(
        signature,
        walletProvider: walletProvider,
      );
      debugPrint('BindScreen: Bind result: $bindSuccess');
      if (bindSuccess) {
        debugPrint('BindScreen: Binding successful!');
        // Clear temporary wallet state to avoid interference with future bindings
        await WalletService.instance.clearTemporaryState();
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      } else {
        debugPrint('BindScreen: Binding failed');
      }
    } catch (e) {
      debugPrint('BindScreen: Exception: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _initAnimations() {
    // Pulse animation for glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate animation for ring
    _rotateController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Scan line animation
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    _scanLineAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _scanLineController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background cyber effects
            _buildCyberBackground(),
            // Main content
            ListenableBuilder(
              listenable: Listenable.merge([
                AuthService.instance,
                WalletService.instance,
              ]),
              builder: (context, _) {
                final auth = AuthService.instance;
                final wallet = WalletService.instance;

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: Center(
                          child: auth.isBound
                              ? _buildBoundState(auth)
                              : _buildUnboundState(auth, wallet),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Subtle cyber background with scan lines and particles
  Widget _buildCyberBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_scanLineAnimation, _particleController]),
      builder: (context, child) {
        return CustomPaint(
          painter: _CyberBackgroundPainter(
            scanLineProgress: _scanLineAnimation.value,
            particleProgress: _particleController.value,
          ),
          size: Size.infinite,
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
              Icons.account_balance_wallet,
              color: CyberColors.purple,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              L.bindWallet.tr,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: CyberColors.purple,
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
    );
  }

  Widget _buildUnboundState(AuthService auth, WalletService wallet) {
    final isLoading = _isProcessing || auth.isBinding || wallet.isConnecting;
    final errorMsg = _error ?? auth.errorMessage ?? wallet.errorMessage;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated wallet icon with rotating ring and pulsing glow
          _buildAnimatedWalletIcon(),
          const SizedBox(height: 32),

          // Title
          Text(
            L.connectWallet.tr,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: CyberColors.purple,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              L.bindDescription.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Benefits list
          _buildBenefitsList(),
          const SizedBox(height: 32),

          // Connect button, loading state, or wallet picker
          if (isLoading)
            Column(
              children: [
                const CircularProgressIndicator(color: CyberColors.purple),
                const SizedBox(height: 12),
                Text(
                  wallet.isConnecting
                      ? L.connectingWallet.tr
                      : auth.isBinding
                          ? L.binding.tr
                          : L.processing.tr,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else if (_showWalletPicker)
            _buildWalletPicker()
          else
            Column(
              children: [
                CyberButton(
                  text: L.connectWallet.tr,
                  icon: Icons.link,
                  color: CyberColors.purple,
                  expanded: true,
                  onPressed: () => setState(() => _showWalletPicker = true),
                ),
                const SizedBox(height: 8),
                Text(
                  L.unlockGlobalRank.tr,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),

          // Error message
          if (errorMsg != null && !isLoading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CyberColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CyberColors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: CyberColors.red, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      errorMsg,
                      style: const TextStyle(
                        color: CyberColors.red,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Animated wallet icon with rotating ring and pulsing glow
  Widget _buildAnimatedWalletIcon() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotateAnimation]),
      builder: (context, child) {
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating ring
              Transform.rotate(
                angle: _rotateAnimation.value,
                child: CustomPaint(
                  size: const Size(140, 140),
                  painter: _RotatingRingPainter(
                    color: CyberColors.purple,
                    opacity: 0.3,
                  ),
                ),
              ),
              // Inner rotating ring (opposite direction)
              Transform.rotate(
                angle: -_rotateAnimation.value * 0.7,
                child: CustomPaint(
                  size: const Size(120, 120),
                  painter: _RotatingRingPainter(
                    color: CyberColors.cyan,
                    opacity: 0.2,
                    dashed: true,
                  ),
                ),
              ),
              // Pulsing glow
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CyberColors.purple.withValues(alpha: _pulseAnimation.value),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              // Main icon container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CyberColors.purple.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      CyberColors.purple.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: CyberColors.purple.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      (Icons.leaderboard, L.benefitGlobalRanking.tr),
      (Icons.cloud_sync, L.benefitCloudSync.tr),
      (Icons.emoji_events, L.benefitAchievements.tr),
    ];

    return Column(
      children: benefits.asMap().entries.map((entry) {
        final index = entry.key;
        final benefit = entry.value;
        // Staggered fade-in effect
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 500 + index * 200),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(20 * (1 - value), 0),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(benefit.$1, color: CyberColors.cyan, size: 18),
                const SizedBox(width: 10),
                Text(
                  benefit.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Wallet picker UI
  Widget _buildWalletPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              L.selectWallet.tr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showWalletPicker = false),
              child: Icon(
                Icons.close,
                color: Colors.grey[500],
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Wallet options - both use deep link protocol
        _buildWalletOption(
          wallet: SolanaWallet.phantom,
          icon: Icons.account_balance_wallet,
          iconColor: const Color(0xFFAB9FF2),
          recommended: true,
          useDeepLink: true,  // Use Phantom deep link
        ),
        const SizedBox(height: 12),
        _buildWalletOption(
          wallet: SolanaWallet.solflare,
          icon: Icons.whatshot,
          iconColor: const Color(0xFFFC822B),
          recommended: false,
          useDeepLink: true,  // Use Solflare deep link (same protocol as Phantom)
        ),

      ],
    );
  }

  Widget _buildWalletOption({
    required SolanaWallet wallet,
    required IconData icon,
    required Color iconColor,
    required bool recommended,
    bool useDeepLink = false,
  }) {
    return GestureDetector(
      onTap: () => _connectWithWallet(wallet, useDeepLink: useDeepLink),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: recommended
                ? CyberColors.purple.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: recommended ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Wallet icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Wallet name and badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        wallet.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CyberColors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            L.recommended.tr,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: CyberColors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recommended ? L.bestMwaSupport.tr : L.deepLinkSupported.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectWithWallet(SolanaWallet wallet, {bool useDeepLink = false}) async {
    setState(() {
      _showWalletPicker = false;
      _selectedWallet = wallet;
      _error = null;
    });

    // Clear any previous errors
    WalletService.instance.clearError();

    // Start the binding process with selected wallet
    // Use deep link if the wallet supports it and useDeepLink is true
    _startBinding(useDeepLink: useDeepLink && wallet.supportsDeepLink);
  }

  Widget _buildBoundState(AuthService auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated success icon
        _buildAnimatedSuccessIcon(),
        const SizedBox(height: 32),

        Text(
          L.walletConnected.tr,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: CyberColors.green,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CyberColors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet, color: CyberColors.green, size: 22),
              const SizedBox(width: 12),
              Text(
                auth.shortWalletAddress,
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: CyberColors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        CyberButton(
          text: L.unbind.tr,
          icon: Icons.link_off,
          color: CyberColors.red,
          onPressed: _showUnbindConfirmation,
        ),
      ],
    );
  }

  Widget _buildAnimatedSuccessIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CyberColors.green.withValues(alpha: _pulseAnimation.value * 0.5),
                      blurRadius: 40,
                      spreadRadius: 15,
                    ),
                  ],
                ),
              ),
              // Main icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CyberColors.green.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      CyberColors.green.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 48,
                  color: CyberColors.green.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startBinding({bool useDeepLink = false}) async {
    debugPrint('BindScreen: Starting binding flow (useDeepLink=$useDeepLink, wallet=${_selectedWallet?.name})');
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      String? walletAddress;

      if (useDeepLink && _selectedWallet != null) {
        // Use wallet's deep link protocol (Phantom or Solflare)
        debugPrint('BindScreen: Connecting via ${_selectedWallet!.name} deep link...');
        walletAddress = await WalletService.instance.connectWithDeepLink(_selectedWallet!);
      } else {
        // Use MWA protocol
        debugPrint('BindScreen: Connecting via MWA...');
        walletAddress = await WalletService.instance.connect(wallet: _selectedWallet);
      }

      debugPrint('BindScreen: Wallet address received: $walletAddress');
      if (walletAddress == null) {
        debugPrint('BindScreen: Wallet connection failed, aborting');
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('BindScreen: Getting nonce from server...');
      final nonceSuccess = await AuthService.instance.startBinding(walletAddress);
      debugPrint('BindScreen: Nonce result: $nonceSuccess');
      if (!nonceSuccess) {
        debugPrint('BindScreen: Failed to get nonce');
        setState(() => _isProcessing = false);
        return;
      }

      final message = AuthService.instance.messageToSign;
      debugPrint('BindScreen: Message to sign: $message');
      if (message == null) {
        debugPrint('BindScreen: No message to sign');
        setState(() {
          _error = 'Failed to get sign message';
          _isProcessing = false;
        });
        return;
      }

      debugPrint('BindScreen: Requesting signature from wallet...');
      final signature = await WalletService.instance.signMessage(message);
      debugPrint('BindScreen: Signature result: ${signature != null ? "received" : "null"}');
      if (signature == null) {
        debugPrint('BindScreen: Signature failed, canceling binding');
        AuthService.instance.cancelBinding();
        setState(() => _isProcessing = false);
        return;
      }

      debugPrint('BindScreen: Completing binding with signature...');
      // Determine wallet provider name from connected wallet
      final walletProvider = WalletService.instance.walletProviderName;
      final bindSuccess = await AuthService.instance.completeBinding(
        signature,
        walletProvider: walletProvider,
      );
      debugPrint('BindScreen: Bind result: $bindSuccess');
      if (bindSuccess) {
        debugPrint('BindScreen: Binding successful!');
        // Clear temporary wallet state to avoid interference with future bindings
        await WalletService.instance.clearTemporaryState();
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      } else {
        debugPrint('BindScreen: Binding failed');
      }
    } catch (e) {
      debugPrint('BindScreen: Exception: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSyncScoreDialog(List<LeaderboardEntry> localScores) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SyncScoreDialog(
        localScores: localScores,
        onSync: (selectedScores) async {
          Navigator.of(context).pop();
          widget.onBindSuccess?.call();
        },
        onSkip: () {
          Navigator.of(context).pop();
          widget.onBindSuccess?.call();
        },
      ),
    );
  }

  void _showUnbindConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CyberColors.red.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: CyberColors.orange, size: 24),
            const SizedBox(width: 10),
            Text(
              L.unbind.tr,
              style: const TextStyle(
                color: CyberColors.orange,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          L.unbindConfirm.tr,
          style: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'monospace',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              L.cancel.tr,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await WalletService.instance.disconnect();
              await AuthService.instance.unbind();
            },
            child: Text(
              L.unbind.tr,
              style: const TextStyle(color: CyberColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cyber background painter with scan lines and floating particles
class _CyberBackgroundPainter extends CustomPainter {
  final double scanLineProgress;
  final double particleProgress;

  _CyberBackgroundPainter({
    required this.scanLineProgress,
    required this.particleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle grid lines
    final gridPaint = Paint()
      ..color = CyberColors.purple.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Scan line effect
    final scanY = size.height * scanLineProgress;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          CyberColors.cyan.withValues(alpha: 0.08),
          CyberColors.cyan.withValues(alpha: 0.15),
          CyberColors.cyan.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0, 0.3, 0.5, 0.7, 1],
      ).createShader(Rect.fromLTWH(0, scanY - 60, size.width, 120));

    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 60, size.width, 120),
      scanPaint,
    );

    // Floating particles
    final random = math.Random(42);
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final particleSize = 1.0 + random.nextDouble() * 2;

      final y = (baseY - particleProgress * size.height * speed) % size.height;
      final opacity = 0.1 + random.nextDouble() * 0.2;

      particlePaint.color = (i % 2 == 0 ? CyberColors.purple : CyberColors.cyan)
          .withValues(alpha: opacity);

      canvas.drawCircle(Offset(baseX, y), particleSize, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberBackgroundPainter oldDelegate) {
    return oldDelegate.scanLineProgress != scanLineProgress ||
        oldDelegate.particleProgress != particleProgress;
  }
}

/// Rotating ring painter
class _RotatingRingPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final bool dashed;

  _RotatingRingPainter({
    required this.color,
    required this.opacity,
    this.dashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (dashed) {
      // Draw dashed circle
      const dashLength = 8.0;
      const gapLength = 6.0;
      final circumference = 2 * math.pi * radius;
      final dashCount = (circumference / (dashLength + gapLength)).floor();

      for (int i = 0; i < dashCount; i++) {
        final startAngle = (i * (dashLength + gapLength)) / radius;
        final sweepAngle = dashLength / radius;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
      }
    } else {
      // Draw partial arc for visual interest
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        0,
        math.pi * 1.5,
        false,
        paint,
      );
      // Small accent
      paint.color = color.withValues(alpha: opacity * 2);
      paint.strokeWidth = 2.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 1.6,
        math.pi * 0.3,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RotatingRingPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.color != color;
  }
}

