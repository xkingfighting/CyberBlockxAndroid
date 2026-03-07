import 'package:flutter/material.dart';
import '../../models/api_response.dart';
import '../../models/auth_state.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/google_sign_in_service.dart';
import '../../services/localization_service.dart';
import '../../solana/wallet_service.dart';
import '../../utils/country_flags.dart';
import '../theme/cyber_theme.dart';

class AccountScreen extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onLogout;

  const AccountScreen({
    super.key,
    required this.onClose,
    this.onLogout,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _isLoading = true);
    await AuthService.instance.fetchLinkedProviders();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AuthService.instance,
          builder: (context, _) {
            final auth = AuthService.instance;
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildUserInfoSection(auth),
                        const SizedBox(height: 24),
                        _buildLinkedAccountsSection(auth),
                        const SizedBox(height: 32),
                        _buildLogoutButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            L.account.tr,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: CyberColors.cyan,
            ),
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
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection(AuthService auth) {
    return _SectionCard(
      title: 'USER',
      icon: Icons.person,
      children: [
        if (auth.displayName != null && auth.displayName!.isNotEmpty)
          _infoRow('Name', auth.countryCode != null
              ? '${auth.displayName!} ${countryCodeToEmoji(auth.countryCode!)}'
              : auth.displayName!),
        if (auth.userId != null)
          _infoRow('User ID', () {
            final id = auth.displayUserId ?? 'CBX-${auth.userId.toString().padLeft(6, '0')}';
            // If no Name row, append flag to User ID instead
            if ((auth.displayName == null || auth.displayName!.isEmpty) && auth.countryCode != null) {
              return '$id ${countryCodeToEmoji(auth.countryCode!)}';
            }
            return id;
          }()),
        if (auth.authProvider != null)
          _infoRow('Login', _providerDisplayName(auth.authProvider!.rawValue)),
        if (auth.walletAddress != null && auth.walletAddress!.isNotEmpty)
          _infoRow('Wallet', auth.shortWalletAddress),
      ],
    );
  }

  Widget _buildLinkedAccountsSection(AuthService auth) {
    return _SectionCard(
      title: L.linkedAccounts.tr.toUpperCase(),
      icon: Icons.link,
      children: [
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              L.loading.tr,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
          )
        else if (auth.linkedProviders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              L.loading.tr,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
          )
        else
          ...auth.linkedProviders.map((provider) => _providerRow(provider, auth)),

        // Link buttons for unlinked providers
        ..._buildLinkButtons(auth),
      ],
    );
  }

  List<Widget> _buildLinkButtons(AuthService auth) {
    final linked = auth.linkedProviders.map((p) => p.provider).toSet();
    final buttons = <Widget>[];

    if (!linked.contains('google')) {
      buttons.add(const SizedBox(height: 8));
      buttons.add(_linkButton(
        provider: 'google',
        label: L.signInWithGoogle.tr,
        icon: 'G',
        color: Colors.red,
      ));
    }

    return buttons;
  }

  Widget _providerRow(AuthProviderInfo provider, AuthService auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _providerIcon(provider.provider),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.provider == 'wallet' && provider.name != null && provider.name!.isNotEmpty
                      ? '${_providerDisplayName(provider.provider)} · ${provider.name}'
                      : _providerDisplayName(provider.provider),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    color: Colors.white,
                  ),
                ),
                if (provider.email != null && provider.email!.isNotEmpty)
                  Text(
                    provider.email!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
                  )
                else if (provider.provider == 'wallet')
                  Text(
                    _shortAddress(provider.providerId),
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          if (auth.linkedProviders.length > 1)
            GestureDetector(
              onTap: () => _unlinkProvider(provider.provider),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: CyberColors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  L.unlinkAccount.tr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                    color: CyberColors.red.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _linkButton({
    required String provider,
    required String label,
    required String icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _linkProvider(provider),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${L.linkAccount.tr} ${_providerDisplayName(provider)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: CyberColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _showLogoutConfirmation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: CyberColors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CyberColors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: CyberColors.red, size: 14),
            const SizedBox(width: 8),
            Text(
              L.logout.tr,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: CyberColors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers

  Widget _providerIcon(String provider) {
    Widget icon;
    switch (provider) {
      case 'wallet':
        icon = const Icon(Icons.link, color: CyberColors.purple, size: 20);
      case 'google':
        icon = Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red[400],
          ),
        );
      case 'apple':
        icon = const Icon(Icons.apple, color: Colors.white, size: 20);
      default:
        icon = const Icon(Icons.person, color: Colors.grey, size: 20);
    }
    return SizedBox(width: 24, height: 24, child: Center(child: icon));
  }

  String _providerDisplayName(String provider) {
    switch (provider) {
      case 'wallet': return 'Wallet';
      case 'google': return 'Google';
      case 'apple': return 'Apple';
      default: return provider;
    }
  }

  String _shortAddress(String address) {
    if (address.length < 8) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Actions

  Future<void> _linkProvider(String provider, {bool force = false, String? cachedIdToken}) async {
    try {
      String? idToken = cachedIdToken;

      switch (provider) {
        case 'google':
          idToken ??= await GoogleSignInService.instance.signIn();
          if (idToken == null) return;
          final token = await AuthService.instance.getValidAccessToken();
          if (token == null) return;
          final result = await ApiService.instance.linkGoogle(
            accessToken: token,
            idToken: idToken,
            force: force,
          );
          if (result.isConflict && mounted) {
            _showConflictDialog(provider, idToken, result);
            return;
          }
        default:
          return;
      }
      await AuthService.instance.fetchLinkedProviders();
    } catch (e) {
      debugPrint('[AccountScreen] Link error: $e');
    }
  }

  void _showConflictDialog(String provider, String idToken, ApiResponse result) {
    final conflictEmail = result.conflictData?['conflict_email'] as String? ?? '';
    final conflictName = result.conflictData?['conflict_name'] as String? ?? '';
    final displayInfo = conflictEmail.isNotEmpty ? conflictEmail : conflictName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: CyberColors.orange.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: CyberColors.orange, size: 24),
            const SizedBox(width: 10),
            Text(
              L.linkConflictTitle.tr,
              style: const TextStyle(
                color: CyberColors.orange,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          L.linkConflictMessage.tr.replaceAll('{account}', displayInfo),
          style: TextStyle(
            color: Colors.grey[400],
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
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
            onPressed: () {
              Navigator.of(context).pop();
              _linkProvider(provider, force: true, cachedIdToken: idToken);
            },
            child: Text(
              L.linkConflictConfirm.tr,
              style: const TextStyle(color: CyberColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlinkProvider(String provider) async {
    try {
      final token = await AuthService.instance.getValidAccessToken();
      if (token == null) return;
      await ApiService.instance.unlinkProvider(accessToken: token, provider: provider);
      await AuthService.instance.fetchLinkedProviders();
    } catch (e) {
      debugPrint('[AccountScreen] Unlink error: $e');
    }
  }

  void _showLogoutConfirmation() {
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
              L.logout.tr,
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
              widget.onLogout?.call();
            },
            child: Text(
              L.logout.tr,
              style: const TextStyle(color: CyberColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section card with title and icon
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: CyberColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: CyberColors.cyan,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
