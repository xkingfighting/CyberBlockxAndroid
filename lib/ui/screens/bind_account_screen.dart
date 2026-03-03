import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/google_sign_in_service.dart';
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

class _BindAccountScreenState extends State<BindAccountScreen> {
  bool _isProcessing = false;
  String? _error;
  bool _showWalletPicker = false;
  SolanaWallet? _selectedWallet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingConnectResult();
    });
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

                // Logo
                _buildLogo(),
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

                // Login buttons or loading
                if (isLoading)
                  Column(
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
                else if (_showWalletPicker)
                  _buildWalletPicker()
                else
                  _buildLoginButtons(),

                const Spacer(),

                // Skip button
                GestureDetector(
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      L.skipForNow.tr,
                      style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.grey[600]),
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
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00FFFF), Color(0xFF00AAFF)],
          ).createShader(bounds),
          child: const Text(
            'CYBER',
            style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'monospace',
              color: Colors.white, letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 2),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFCC44FF), Color(0xFFFF00FF)],
          ).createShader(bounds),
          child: const Text(
            'BLOCKX',
            style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'monospace',
              color: Colors.white, letterSpacing: 3,
            ),
          ),
        ),
      ],
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
