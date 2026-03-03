import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pinenacl/x25519.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'crypto_helper.dart';
import 'wallet_service.dart' show SolanaWallet;

/// Restored deep link connect state from SharedPreferences.
class DeepLinkConnectState {
  final PrivateKey dappKeyPair;
  final SolanaWallet wallet;
  DeepLinkConnectState({required this.dappKeyPair, required this.wallet});
}

/// Restored deep link sign state from SharedPreferences.
class DeepLinkSignState {
  final PrivateKey dappKeyPair;
  final String walletSession;
  final Uint8List walletEncryptionPublicKey;
  final SolanaWallet wallet;
  final String? publicKey;
  DeepLinkSignState({
    required this.dappKeyPair,
    required this.walletSession,
    required this.walletEncryptionPublicKey,
    required this.wallet,
    this.publicKey,
  });
}

/// Manages deep link state persistence for cold start recovery
/// and builds deep link URLs for wallet communication.
class DeepLinkHandler {
  DeepLinkHandler._();

  // SharedPreferences keys
  static const _keyDappPrivateKey = 'wallet_dapp_private_key';
  static const _keyDeepLinkWallet = 'wallet_deep_link_wallet';
  static const _keyPendingConnect = 'wallet_pending_connect';
  static const _keyWalletSession = 'wallet_session';
  static const _keyWalletEncryptionKey = 'wallet_encryption_key';
  static const _keyPendingSign = 'wallet_pending_sign';
  static const _keyPublicKey = 'wallet_public_key';

  // App scheme
  static const appScheme = 'cyberblockx';
  static const _appUri = 'https://cyberblockx.com';

  // Wallet deep link URLs
  static const _phantomConnectUrl = 'phantom://v1/connect';
  static const _phantomSignMessageUrl = 'phantom://v1/signMessage';
  static const _solflareConnectUrl = 'https://solflare.com/ul/v1/connect';
  static const _solflareSignMessageUrl = 'https://solflare.com/ul/v1/signMessage';

  // ──────────────────────────────────────────────
  // Connect State Persistence
  // ──────────────────────────────────────────────

  /// Save deep link connect state for cold start recovery.
  static Future<void> saveConnectState(PrivateKey dappKeyPair, SolanaWallet wallet) async {
    try {
      final keyBytes = CryptoHelper.privateKeyBytes(dappKeyPair);
      final keyBase58 = CryptoHelper.toBase58(keyBytes);
      debugPrint('Saving deep link state: key length=${keyBytes.length}, wallet=${wallet.name}');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDappPrivateKey, keyBase58);
      await prefs.setString(_keyDeepLinkWallet, wallet.name);
      await prefs.setBool(_keyPendingConnect, true);

      final verifyPending = prefs.getBool(_keyPendingConnect);
      final verifyKey = prefs.getString(_keyDappPrivateKey);
      debugPrint('Deep link state saved and verified: pending=$verifyPending, keySaved=${verifyKey != null}');
    } catch (e, stackTrace) {
      debugPrint('Failed to save deep link state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Restore deep link connect state from SharedPreferences.
  static Future<DeepLinkConnectState?> restoreConnectState() async {
    try {
      debugPrint('Attempting to restore deep link state...');
      final prefs = await SharedPreferences.getInstance();

      final isPending = prefs.getBool(_keyPendingConnect);
      debugPrint('isPending from storage: $isPending');

      if (isPending != true) {
        debugPrint('No pending deep link state to restore');
        return null;
      }

      final keyBase58 = prefs.getString(_keyDappPrivateKey);
      final walletName = prefs.getString(_keyDeepLinkWallet);

      debugPrint('keyBase58: ${keyBase58 != null ? "${keyBase58.substring(0, 10)}..." : "null"}');
      debugPrint('walletName: $walletName');

      if (keyBase58 != null && walletName != null) {
        final keyBytes = CryptoHelper.fromBase58(keyBase58);
        debugPrint('Key bytes length: ${keyBytes.length}');

        final dappKeyPair = CryptoHelper.privateKeyFromBytes(Uint8List.fromList(keyBytes));
        final wallet = SolanaWallet.values.firstWhere(
          (w) => w.name == walletName,
          orElse: () => SolanaWallet.phantom,
        );

        final restoredPublicKey = CryptoHelper.publicKeyBase58(dappKeyPair);
        debugPrint('Deep link state restored successfully: wallet=$walletName, publicKey=$restoredPublicKey');

        return DeepLinkConnectState(dappKeyPair: dappKeyPair, wallet: wallet);
      } else {
        debugPrint('Missing data for restore: key=${keyBase58 != null}, wallet=${walletName != null}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to restore deep link state: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Clear saved deep link connect state.
  static Future<void> clearConnectState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDappPrivateKey);
      await prefs.remove(_keyDeepLinkWallet);
      await prefs.remove(_keyPendingConnect);
      debugPrint('Deep link state cleared');
    } catch (e) {
      debugPrint('Failed to clear deep link state: $e');
    }
  }

  // ──────────────────────────────────────────────
  // Sign State Persistence
  // ──────────────────────────────────────────────

  /// Save sign state for cold start recovery.
  static Future<void> saveSignState({
    required PrivateKey dappKeyPair,
    required String walletSession,
    required Uint8List walletEncryptionPublicKey,
    required SolanaWallet wallet,
    String? publicKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyBase58 = CryptoHelper.toBase58(CryptoHelper.privateKeyBytes(dappKeyPair));
      final encKeyBase58 = CryptoHelper.toBase58(walletEncryptionPublicKey);

      await prefs.setString(_keyDappPrivateKey, keyBase58);
      await prefs.setString(_keyWalletSession, walletSession);
      await prefs.setString(_keyWalletEncryptionKey, encKeyBase58);
      await prefs.setString(_keyDeepLinkWallet, wallet.name);
      await prefs.setBool(_keyPendingSign, true);
      if (publicKey != null) {
        await prefs.setString(_keyPublicKey, publicKey);
      }

      debugPrint('Sign state saved for cold start recovery');
    } catch (e, stackTrace) {
      debugPrint('Failed to save sign state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Restore sign state from SharedPreferences.
  static Future<DeepLinkSignState?> restoreSignState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isPending = prefs.getBool(_keyPendingSign);
      debugPrint('isPending sign from storage: $isPending');

      if (isPending != true) return null;

      final keyBase58 = prefs.getString(_keyDappPrivateKey);
      final sessionStr = prefs.getString(_keyWalletSession);
      final encKeyBase58 = prefs.getString(_keyWalletEncryptionKey);
      final walletName = prefs.getString(_keyDeepLinkWallet);
      final publicKeyStr = prefs.getString(_keyPublicKey);

      if (keyBase58 != null && sessionStr != null && encKeyBase58 != null && walletName != null) {
        final keyBytes = CryptoHelper.fromBase58(keyBase58);
        final encKeyBytes = CryptoHelper.fromBase58(encKeyBase58);

        final dappKeyPair = CryptoHelper.privateKeyFromBytes(Uint8List.fromList(keyBytes));
        final wallet = SolanaWallet.values.firstWhere(
          (w) => w.name == walletName,
          orElse: () => SolanaWallet.phantom,
        );

        debugPrint('Sign state restored successfully: wallet=$walletName, publicKey=$publicKeyStr');

        return DeepLinkSignState(
          dappKeyPair: dappKeyPair,
          walletSession: sessionStr,
          walletEncryptionPublicKey: Uint8List.fromList(encKeyBytes),
          wallet: wallet,
          publicKey: publicKeyStr,
        );
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('Failed to restore sign state: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Clear saved sign state.
  static Future<void> clearSignState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyWalletSession);
      await prefs.remove(_keyWalletEncryptionKey);
      await prefs.remove(_keyPendingSign);
      await prefs.remove(_keyPublicKey);
      await prefs.remove(_keyDeepLinkWallet);
      debugPrint('Sign state cleared');
    } catch (e) {
      debugPrint('Failed to clear sign state: $e');
    }
  }

  // ──────────────────────────────────────────────
  // URL Building
  // ──────────────────────────────────────────────

  /// Build the connect URL for a wallet deep link.
  static Uri buildConnectUrl(SolanaWallet wallet, String dappPublicKeyBase58) {
    final connectBaseUrl = wallet == SolanaWallet.phantom
        ? _phantomConnectUrl
        : _solflareConnectUrl;

    final redirectUri = '$appScheme://onConnect';
    final params = {
      'app_url': _appUri,
      'dapp_encryption_public_key': dappPublicKeyBase58,
      'cluster': 'mainnet-beta',
      'redirect_link': redirectUri,
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return Uri.parse('$connectBaseUrl?$queryString');
  }

  /// Build the sign message URL for a wallet deep link.
  static Uri buildSignUrl(
    SolanaWallet wallet, {
    required String dappPublicKeyBase58,
    required String payloadBase58,
    required String nonceBase58,
  }) {
    final signBaseUrl = wallet == SolanaWallet.phantom
        ? _phantomSignMessageUrl
        : _solflareSignMessageUrl;

    final redirectUri = '$appScheme://onSignMessage';
    final params = {
      'dapp_encryption_public_key': dappPublicKeyBase58,
      'nonce': nonceBase58,
      'redirect_link': redirectUri,
      'payload': payloadBase58,
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return Uri.parse('$signBaseUrl?$queryString');
  }
}
