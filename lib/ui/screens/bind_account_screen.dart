import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/google_sign_in_service.dart';
import '../../services/leaderboard_service.dart';
import '../../solana/wallet_service.dart';
import '../../services/localization_service.dart';
import '../theme/cyber_theme.dart';
import '../widgets/sync_score_dialog.dart';
import 'legal_page.dart';

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

  // Glow animation (matches menu_screen)
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Entrance animations
  late AnimationController _entranceController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _footerFade;

  // Gesture recognizers (properly managed to avoid leaks)
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();

    // Gesture recognizers
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openPrivacy;

    // Glow animation for title (same as menu_screen)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Entrance animation (800ms staggered)
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _buttonsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.3, 0.75, curve: Curves.easeOut)),
    );
    _buttonsSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.3, 0.75, curve: Curves.easeOut)),
    );
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.55, 1.0, curve: Curves.easeOut)),
    );

    // Start entrance after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entranceController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingConnectResult();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _entranceController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LegalPage(
        title: TermsContent.pageTitle,
        lastUpdated: TermsContent.lastUpdated,
        sections: TermsContent.sections,
      ),
    ));
  }

  void _openPrivacy() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LegalPage(
        title: PrivacyContent.pageTitle,
        lastUpdated: PrivacyContent.lastUpdated,
        sections: PrivacyContent.sections,
      ),
    ));
  }

  /// Check if there's a pending wallet connection from cold start
  Future<void> _checkPendingConnectResult() async {
    if (WalletService.instance.hasPendingSignResult) {
      final signature = WalletService.instance.consumePendingSignResult();
      if (signature != null && AuthService.instance.pendingWalletAddress != null) {
        await _completeBindingWithSignature(signature);
        return;
      }
    }
    if (WalletService.instance.hasPendingConnectResult) {
      final walletAddress = WalletService.instance.consumePendingConnectResult();
      if (walletAddress != null) {
        await _continueBindingWithAddress(walletAddress);
      }
    }
  }

  Future<void> _completeBindingWithSignature(String signature) async {
    setState(() { _isProcessing = true; _error = null; });
    try {
      final walletProvider = WalletService.instance.walletProviderName;
      final bindSuccess = await AuthService.instance.completeBinding(signature, walletProvider: walletProvider);
      if (bindSuccess) {
        await WalletService.instance.clearTemporaryState();
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _continueBindingWithAddress(String walletAddress) async {
    setState(() { _isProcessing = true; _error = null; });
    try {
      final nonceSuccess = await AuthService.instance.startBinding(walletAddress);
      if (!nonceSuccess) { setState(() => _isProcessing = false); return; }

      final message = AuthService.instance.messageToSign;
      if (message == null) {
        setState(() { _error = 'Failed to get sign message'; _isProcessing = false; });
        return;
      }

      final signature = await WalletService.instance.signMessage(message);
      if (signature == null) {
        AuthService.instance.cancelBinding();
        setState(() => _isProcessing = false);
        return;
      }

      final walletProvider = WalletService.instance.walletProviderName;
      final bindSuccess = await AuthService.instance.completeBinding(signature, walletProvider: walletProvider);
      if (bindSuccess) {
        await WalletService.instance.clearTemporaryState();
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([AuthService.instance, WalletService.instance]),
          builder: (context, _) {
            final auth = AuthService.instance;
            final wallet = WalletService.instance;
            final isLoading = _isProcessing || auth.isBinding || wallet.isConnecting;

            return Column(
              children: [
                // Header - close button top right
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.grey, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Logo with entrance animation
                SlideTransition(
                  position: _logoSlide,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: _buildLogo(),
                  ),
                ),
                const SizedBox(height: 40),

                // Error
                if (_error != null || auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      _error ?? auth.errorMessage ?? '',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CyberColors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Login buttons or loading with entrance animation
                SlideTransition(
                  position: _buttonsSlide,
                  child: FadeTransition(
                    opacity: _buttonsFade,
                    child: isLoading
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: CyberColors.cyan),
                              const SizedBox(height: 12),
                              Text(
                                wallet.isConnecting ? L.connectingWallet.tr
                                    : auth.isBinding ? L.binding.tr
                                    : L.processing.tr,
                                style: TextStyle(color: Colors.grey[500], fontFamily: 'monospace', fontSize: 12),
                              ),
                            ],
                          )
                        : _showWalletPicker
                            ? _buildWalletPicker()
                            : _buildLoginButtons(),
                  ),
                ),

                const Spacer(),

                // Legal consent + wallet hint with entrance animation
                FadeTransition(
                  opacity: _footerFade,
                  child: _buildConsentFooter(),
                ),
                const SizedBox(height: 16),

                // Skip button with entrance animation
                FadeTransition(
                  opacity: _footerFade,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        L.skipForNow.tr,
                        style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    const double fontSize = 42;
    const double letterSpacing = 4;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // CYBER - cyan → blue → purple gradient (matches menu_screen)
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF00FFFF), // Cyan
                  Color(0xFF00AAFF), // Blue
                  Color(0xFF8844FF), // Purple
                ],
              ).createShader(bounds),
              child: Text(
                'CYBER',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: Colors.white,
                  letterSpacing: letterSpacing,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF00FFFF).withValues(alpha: _glowAnimation.value * 0.8),
                      blurRadius: _glowAnimation.value * 25,
                    ),
                    const Shadow(
                      color: Color(0xFF00FFFF),
                      blurRadius: 2,
                      offset: Offset(0.5, 0.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            // BLOCK + X - separated with distinct glow (matches menu_screen)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF00FF), // Magenta/Pink
                      Color(0xFFAA44FF), // Purple
                      Color(0xFF6666FF), // Blue-purple
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'BLOCK',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: Colors.white,
                      letterSpacing: letterSpacing,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFF00FF).withValues(alpha: _glowAnimation.value * 0.7),
                          blurRadius: _glowAnimation.value * 25,
                        ),
                        const Shadow(
                          color: Color(0xFFFF00FF),
                          blurRadius: 2,
                          offset: Offset(0.5, 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                // X - bright red with its own glow
                Text(
                  'X',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: const Color(0xFFFF4444),
                    letterSpacing: letterSpacing,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFFF4444).withValues(alpha: _glowAnimation.value),
                        blurRadius: _glowAnimation.value * 30,
                      ),
                      const Shadow(
                        color: Color(0xFFFF4444),
                        blurRadius: 2,
                        offset: Offset(0.5, 0.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoginButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          // Google Sign-In
          _buildLoginOption(
            onTap: _signInWithGoogle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[400])),
                const SizedBox(width: 10),
                Text(L.signInWithGoogle.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Colors.white)),
              ],
            ),
            bgColor: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 14),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(L.orConnectWallet.tr, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey[600])),
              ),
              Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 14),

          // Seed Vault (Saga phone)
          if (WalletService.instance.isSeedVaultAvailable) ...[
            _buildLoginOption(
              onTap: () => _connectWithWallet(SolanaWallet.seedVault, useDeepLink: false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, color: Color(0xFF14F195), size: 16),
                  const SizedBox(width: 8),
                  const Text('Seed Vault', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFF14F195))),
                ],
              ),
              borderColor: const Color(0xFF14F195).withValues(alpha: 0.4),
              bgColor: Colors.white.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 12),
          ],

          // Wallet buttons
          Row(
            children: [
              Expanded(
                child: _buildLoginOption(
                  onTap: () => _connectWithWallet(SolanaWallet.phantom, useDeepLink: true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet, color: const Color(0xFFAB9FF2), size: 16),
                      const SizedBox(width: 6),
                      const Text('Phantom', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFFAB9FF2))),
                    ],
                  ),
                  borderColor: const Color(0xFFAB9FF2).withValues(alpha: 0.4),
                  bgColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLoginOption(
                  onTap: () => _connectWithWallet(SolanaWallet.solflare, useDeepLink: true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.whatshot, color: const Color(0xFFFC822B), size: 16),
                      const SizedBox(width: 6),
                      const Text('Solflare', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFFFC822B))),
                    ],
                  ),
                  borderColor: const Color(0xFFFC822B).withValues(alpha: 0.4),
                  bgColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginOption({
    required VoidCallback onTap,
    required Widget child,
    Color? bgColor,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.3)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildWalletPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(L.selectWallet.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _showWalletPicker = false),
                child: Icon(Icons.close, color: Colors.grey[500], size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (WalletService.instance.isSeedVaultAvailable)
            _buildWalletOption(wallet: SolanaWallet.seedVault, icon: Icons.security, iconColor: const Color(0xFF14F195), useDeepLink: false),
          _buildWalletOption(wallet: SolanaWallet.phantom, icon: Icons.account_balance_wallet, iconColor: const Color(0xFFAB9FF2), useDeepLink: true),
          const SizedBox(height: 12),
          _buildWalletOption(wallet: SolanaWallet.solflare, icon: Icons.whatshot, iconColor: const Color(0xFFFC822B), useDeepLink: true),
        ],
      ),
    );
  }

  Widget _buildWalletOption({
    required SolanaWallet wallet,
    required IconData icon,
    required Color iconColor,
    bool useDeepLink = false,
  }) {
    return GestureDetector(
      onTap: () => _connectWithWallet(wallet, useDeepLink: useDeepLink),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: iconColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Text(wallet.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.white)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          // Wallet identity hint
          Text(
            L.walletIdentityHint.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.white.withValues(alpha: 0.3),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          // Legal consent with clickable links
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.35),
                height: 1.6,
                letterSpacing: 0.2,
              ),
              children: [
                TextSpan(text: L.legalConsentPart1.tr),
                TextSpan(
                  text: L.legalConsentTermsLabel.tr,
                  recognizer: _termsRecognizer,
                  style: TextStyle(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.75),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    decorationThickness: 0.8,
                  ),
                ),
                TextSpan(text: L.legalConsentPart2.tr),
                TextSpan(
                  text: L.legalConsentPrivacyLabel.tr,
                  recognizer: _privacyRecognizer,
                  style: TextStyle(
                    color: const Color(0xFFCC44FF).withValues(alpha: 0.75),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFFCC44FF).withValues(alpha: 0.5),
                    decorationThickness: 0.8,
                  ),
                ),
                TextSpan(text: L.legalConsentPart3.tr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Actions

  Future<void> _signInWithGoogle() async {
    setState(() { _isProcessing = true; _error = null; });
    try {
      final idToken = await GoogleSignInService.instance.signIn();
      if (idToken == null) { setState(() => _isProcessing = false); return; }
      final success = await AuthService.instance.signInWithGoogle(idToken);
      if (success) {
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      } else {
        setState(() => _error = AuthService.instance.errorMessage);
      }
    } catch (e) {
      if (!e.toString().contains('cancelled')) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _connectWithWallet(SolanaWallet wallet, {bool useDeepLink = false}) async {
    setState(() { _selectedWallet = wallet; _error = null; });
    WalletService.instance.clearError();

    final isInstalled = await WalletService.instance.isWalletInstalled(wallet);
    if (!isInstalled) {
      setState(() => _error = L.walletNotInstalled.tr.replaceAll('{wallet}', wallet.name));
      return;
    }
    _startBinding(useDeepLink: useDeepLink && wallet.supportsDeepLink);
  }

  Future<void> _startBinding({bool useDeepLink = false}) async {
    setState(() { _isProcessing = true; _error = null; });
    try {
      String? walletAddress;
      if (useDeepLink && _selectedWallet != null) {
        walletAddress = await WalletService.instance.connectWithDeepLink(_selectedWallet!);
      } else {
        walletAddress = await WalletService.instance.connect(wallet: _selectedWallet);
      }
      if (walletAddress == null) { setState(() => _isProcessing = false); return; }

      final nonceSuccess = await AuthService.instance.startBinding(walletAddress);
      if (!nonceSuccess) { setState(() => _isProcessing = false); return; }

      final message = AuthService.instance.messageToSign;
      if (message == null) {
        setState(() { _error = 'Failed to get sign message'; _isProcessing = false; });
        return;
      }

      final signature = await WalletService.instance.signMessage(message);
      if (signature == null) {
        AuthService.instance.cancelBinding();
        setState(() => _isProcessing = false);
        return;
      }

      final walletProvider = WalletService.instance.walletProviderName;
      final bindSuccess = await AuthService.instance.completeBinding(signature, walletProvider: walletProvider);
      if (bindSuccess) {
        await WalletService.instance.clearTemporaryState();
        final localScores = LeaderboardService.instance.entries;
        if (localScores.isNotEmpty && mounted) {
          _showSyncScoreDialog(localScores);
        } else {
          widget.onBindSuccess?.call();
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
}
