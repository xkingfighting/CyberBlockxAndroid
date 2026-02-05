import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pinenacl/api.dart';
import 'package:pinenacl/x25519.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported wallet types
enum SolanaWallet {
  phantom('Phantom', 'phantom', 'com.phantom', true),
  solflare('Solflare', 'solflare', 'com.solflare.mobile', true);

  final String name;
  final String scheme;
  final String packageName;
  final bool supportsDeepLink; // Both Phantom and Solflare support deep link auth
  const SolanaWallet(this.name, this.scheme, this.packageName, this.supportsDeepLink);
}

/// Solana wallet connection service using Mobile Wallet Adapter
class WalletService extends ChangeNotifier {
  static final WalletService instance = WalletService._();
  WalletService._();

  // SharedPreferences keys for persisting deep link state (cold start recovery)
  static const _keyDappPrivateKey = 'wallet_dapp_private_key';
  static const _keyDeepLinkWallet = 'wallet_deep_link_wallet';
  static const _keyPendingConnect = 'wallet_pending_connect';
  // Keys for sign message cold start recovery
  static const _keyWalletSession = 'wallet_session';
  static const _keyWalletEncryptionKey = 'wallet_encryption_key';
  static const _keyPendingSign = 'wallet_pending_sign';
  static const _keyPublicKey = 'wallet_public_key';

  // App identity for MWA
  static const String _appName = 'CyberBlockx';
  static const String _appUri = 'https://cyberblockx.com';
  static const String _appIcon = 'favicon.ico';

  // Connection timeout
  static const Duration _connectionTimeout = Duration(seconds: 60);

  // Selected wallet
  SolanaWallet? _selectedWallet;

  // Deep link connection state
  String? _walletSession;  // Session from wallet connect (Phantom/Solflare)
  Completer<String?>? _deepLinkCompleter;
  PrivateKey? _dappKeyPair;
  Uint8List? _walletEncryptionPublicKey;  // Wallet's X25519 public key for encryption
  bool _useDeepLink = false;  // Whether connected via deep link
  SolanaWallet? _deepLinkWallet;  // Which wallet is connected via deep link
  static const _appScheme = 'cyberblockx';

  // Pending connection result (for cold start recovery)
  String? _pendingConnectResult;

  // Pending sign result (for cold start recovery)
  String? _pendingSignResult;

  // Phantom deep link URLs - use phantom:// scheme for Android, https:// for iOS
  // Android prefers the custom scheme for direct app-to-app communication
  static const _phantomConnectUrl = 'phantom://v1/connect';
  static const _phantomSignMessageUrl = 'phantom://v1/signMessage';

  // Solflare deep link URLs - use https:// universal links
  static const _solflareConnectUrl = 'https://solflare.com/ul/v1/connect';
  static const _solflareSignMessageUrl = 'https://solflare.com/ul/v1/signMessage';

  String? _publicKey;
  Uint8List? _publicKeyBytes;
  String? _authToken;
  bool _isConnecting = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool? _isMwaAvailable;

  // Getters
  bool get isConnected => _publicKey != null && (_authToken != null || _useDeepLink);
  bool get isConnecting => _isConnecting;
  String? get publicKey => _publicKey;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool? get isMwaAvailable => _isMwaAvailable;
  SolanaWallet? get connectedWallet => _useDeepLink ? _deepLinkWallet : _selectedWallet;
  String get walletProviderName => connectedWallet?.name ?? 'Unknown';

  // For compatibility with existing code
  String? get connectUri => null;

  String get shortAddress {
    if (_publicKey == null) return '';
    if (_publicKey!.length < 10) return _publicKey!;
    return '${_publicKey!.substring(0, 4)}...${_publicKey!.substring(_publicKey!.length - 4)}';
  }

  /// Initialize the wallet service
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check if MWA is available
    try {
      _isMwaAvailable = await LocalAssociationScenario.isAvailable();
      debugPrint('MWA available: $_isMwaAvailable');
    } catch (e) {
      debugPrint('Failed to check MWA availability: $e');
      _isMwaAvailable = false;
    }

    // Restore deep link state if pending (cold start recovery)
    await _restoreDeepLinkState();
    // Also try to restore sign state
    await _restoreSignState();

    debugPrint('WalletService initialized (MWA)');
    notifyListeners();
  }

  /// Check if there's a pending connection result (from cold start)
  bool get hasPendingConnectResult => _pendingConnectResult != null;

  /// Get and clear the pending connection result
  String? consumePendingConnectResult() {
    final result = _pendingConnectResult;
    _pendingConnectResult = null;
    return result;
  }

  /// Check if there's a pending sign result (from cold start)
  bool get hasPendingSignResult => _pendingSignResult != null;

  /// Get and clear the pending sign result
  String? consumePendingSignResult() {
    final result = _pendingSignResult;
    _pendingSignResult = null;
    return result;
  }

  /// Save deep link state to SharedPreferences (for cold start recovery)
  Future<void> _saveDeepLinkState(SolanaWallet wallet) async {
    try {
      if (_dappKeyPair != null) {
        final prefs = await SharedPreferences.getInstance();

        // PrivateKey extends ByteList, so toList() returns the raw key bytes (32 bytes)
        final keyBytes = Uint8List.fromList(_dappKeyPair!.toList());
        final keyBase58 = _toBase58(keyBytes);
        debugPrint('Saving deep link state: key length=${keyBytes.length}, wallet=${wallet.name}');

        // Save synchronously-ish by committing immediately
        await prefs.setString(_keyDappPrivateKey, keyBase58);
        await prefs.setString(_keyDeepLinkWallet, wallet.name);
        await prefs.setBool(_keyPendingConnect, true);

        // Verify the save
        final verifyPending = prefs.getBool(_keyPendingConnect);
        final verifyKey = prefs.getString(_keyDappPrivateKey);
        debugPrint('Deep link state saved and verified: pending=$verifyPending, keySaved=${verifyKey != null}');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to save deep link state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Restore deep link state from SharedPreferences
  Future<void> _restoreDeepLinkState() async {
    try {
      debugPrint('Attempting to restore deep link state...');
      final prefs = await SharedPreferences.getInstance();

      final isPending = prefs.getBool(_keyPendingConnect);
      debugPrint('isPending from storage: $isPending');

      if (isPending != true) {
        debugPrint('No pending deep link state to restore');
        return;
      }

      final keyBase58 = prefs.getString(_keyDappPrivateKey);
      final walletName = prefs.getString(_keyDeepLinkWallet);

      debugPrint('keyBase58: ${keyBase58 != null ? "${keyBase58.substring(0, 10)}..." : "null"}');
      debugPrint('walletName: $walletName');

      if (keyBase58 != null && walletName != null) {
        final keyBytes = _fromBase58(keyBase58);
        debugPrint('Key bytes length: ${keyBytes.length}');

        // Reconstruct PrivateKey from bytes (PrivateKey constructor accepts Uint8List)
        _dappKeyPair = PrivateKey(Uint8List.fromList(keyBytes));
        _deepLinkWallet = SolanaWallet.values.firstWhere(
          (w) => w.name == walletName,
          orElse: () => SolanaWallet.phantom,
        );

        // Verify the restored public key
        final restoredPublicKey = _toBase58(Uint8List.fromList(_dappKeyPair!.publicKey.toList()));
        debugPrint('Deep link state restored successfully: wallet=$walletName, publicKey=$restoredPublicKey');
      } else {
        debugPrint('Missing data for restore: key=${keyBase58 != null}, wallet=${walletName != null}');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to restore deep link state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Clear saved deep link state
  Future<void> _clearDeepLinkState() async {
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

  /// Save sign state to SharedPreferences (for cold start recovery)
  Future<void> _saveSignState() async {
    try {
      if (_dappKeyPair != null && _walletSession != null && _walletEncryptionPublicKey != null) {
        final prefs = await SharedPreferences.getInstance();

        final keyBytes = Uint8List.fromList(_dappKeyPair!.toList());
        final keyBase58 = _toBase58(keyBytes);
        final encKeyBase58 = _toBase58(_walletEncryptionPublicKey!);

        await prefs.setString(_keyDappPrivateKey, keyBase58);
        await prefs.setString(_keyWalletSession, _walletSession!);
        await prefs.setString(_keyWalletEncryptionKey, encKeyBase58);
        await prefs.setString(_keyDeepLinkWallet, _deepLinkWallet?.name ?? 'Unknown');
        await prefs.setBool(_keyPendingSign, true);
        // Also save the public key for proper state restoration
        if (_publicKey != null) {
          await prefs.setString(_keyPublicKey, _publicKey!);
        }

        debugPrint('Sign state saved for cold start recovery');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to save sign state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Restore sign state from SharedPreferences
  Future<void> _restoreSignState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isPending = prefs.getBool(_keyPendingSign);
      debugPrint('isPending sign from storage: $isPending');

      if (isPending != true) {
        return;
      }

      final keyBase58 = prefs.getString(_keyDappPrivateKey);
      final sessionStr = prefs.getString(_keyWalletSession);
      final encKeyBase58 = prefs.getString(_keyWalletEncryptionKey);
      final walletName = prefs.getString(_keyDeepLinkWallet);
      final publicKeyStr = prefs.getString(_keyPublicKey);

      if (keyBase58 != null && sessionStr != null && encKeyBase58 != null && walletName != null) {
        final keyBytes = _fromBase58(keyBase58);
        final encKeyBytes = _fromBase58(encKeyBase58);

        _dappKeyPair = PrivateKey(Uint8List.fromList(keyBytes));
        _walletSession = sessionStr;
        _walletEncryptionPublicKey = Uint8List.fromList(encKeyBytes);
        _deepLinkWallet = SolanaWallet.values.firstWhere(
          (w) => w.name == walletName,
          orElse: () => SolanaWallet.phantom,
        );
        _useDeepLink = true;
        // Also restore the public key
        if (publicKeyStr != null) {
          _publicKey = publicKeyStr;
        }

        debugPrint('Sign state restored successfully: wallet=$walletName, publicKey=$publicKeyStr');
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to restore sign state: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Clear saved sign state
  Future<void> _clearSignState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyWalletSession);
      await prefs.remove(_keyWalletEncryptionKey);
      await prefs.remove(_keyPendingSign);
      await prefs.remove(_keyPublicKey);
      // Also clear the deep link wallet to avoid state confusion
      await prefs.remove(_keyDeepLinkWallet);
      debugPrint('Sign state cleared');
    } catch (e) {
      debugPrint('Failed to clear sign state: $e');
    }
  }

  /// Connect to a Solana wallet using Mobile Wallet Adapter
  /// [wallet] - Optional specific wallet to use. If null, system will choose.
  /// Returns the wallet address if successful, null otherwise
  Future<String?> connect({SolanaWallet? wallet}) async {
    if (_isConnecting || isConnected) return _publicKey;

    _isConnecting = true;
    _errorMessage = null;
    _selectedWallet = wallet;
    notifyListeners();

    // Check MWA availability
    if (_isMwaAvailable == false) {
      _errorMessage = 'No MWA-compatible wallet found. Please install Phantom or Solflare.';
      _isConnecting = false;
      notifyListeners();
      return null;
    }

    LocalAssociationScenario? session;

    try {
      // If a specific wallet is selected, try to launch it first
      if (wallet != null) {
        debugPrint('Attempting to launch ${wallet.name}...');
        final launched = await _launchWalletApp(wallet);
        if (!launched) {
          debugPrint('Could not launch ${wallet.name}, falling back to system picker');
        } else {
          // Give the wallet app time to open (Solflare needs more time)
          final delay = wallet == SolanaWallet.solflare
              ? const Duration(milliseconds: 1500)
              : const Duration(milliseconds: 500);
          debugPrint('Waiting ${delay.inMilliseconds}ms for ${wallet.name} to initialize...');
          await Future.delayed(delay);
        }
      }

      // Create session
      debugPrint('Creating MWA session for ${wallet?.name ?? "system"}...');
      session = await LocalAssociationScenario.create();

      // Start the wallet activity (don't ignore, but don't await)
      debugPrint('Starting wallet activity...');
      session.startActivityForResult(null).then((_) {
        debugPrint('Wallet activity result received');
      }).catchError((e) {
        debugPrint('Wallet activity error: $e');
      });

      // Get MWA client with timeout
      debugPrint('Waiting for wallet connection...');
      final client = await session.start().timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Wallet connection timed out. Please make sure your wallet app is responding.');
        },
      );

      debugPrint('MWA client connected, authorizing...');

      // Authorize with the wallet
      final result = await client.authorize(
        identityUri: Uri.parse(_appUri),
        iconUri: Uri.parse('$_appUri/$_appIcon'),
        identityName: _appName,
        cluster: 'mainnet-beta',
      ).timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Authorization timed out. Please approve the request in your wallet.');
        },
      );

      if (result != null) {
        // Store authorization info
        _authToken = result.authToken;
        _publicKeyBytes = result.publicKey;

        // Convert to base58 for display
        _publicKey = _toBase58(result.publicKey);
        debugPrint('Wallet connected: $_publicKey');
      } else {
        debugPrint('Authorization returned null - wallet may have disconnected');
        _errorMessage = 'Authorization failed. The wallet may have closed before approving. Please stay in the wallet and approve the connection request.';
      }

      return _publicKey;
    } on TimeoutException catch (e) {
      debugPrint('Wallet connect timeout: $e');
      _errorMessage = e.message ?? 'Connection timed out';
      return null;
    } catch (e) {
      debugPrint('Wallet connect error: $e');
      final errorStr = e.toString().toLowerCase();
      final isSolflare = wallet == SolanaWallet.solflare;

      if (errorStr.contains('user rejected') ||
          errorStr.contains('declined') ||
          errorStr.contains('cancelled') ||
          errorStr.contains('canceled')) {
        _errorMessage = 'Connection rejected by user';
      } else if (errorStr.contains('no wallet') || errorStr.contains('not found')) {
        _errorMessage = 'No MWA wallet found. Please install Phantom or Solflare.';
      } else if (errorStr.contains('session') ||
                 errorStr.contains('websocket') ||
                 errorStr.contains('disconnected') ||
                 errorStr.contains('closed')) {
        if (isSolflare) {
          _errorMessage = 'Solflare MWA connection failed. Please try Phantom wallet instead.';
        } else {
          _errorMessage = 'Wallet disconnected. Please stay in the wallet and approve the request.';
        }
      } else if (errorStr.contains('platform')) {
        _errorMessage = 'Wallet connection failed. Please try Phantom wallet for better MWA support.';
      } else {
        if (isSolflare) {
          _errorMessage = 'Solflare connection failed. Solflare may have MWA issues - please try Phantom instead.';
        } else {
          _errorMessage = 'Connection failed: ${e.toString()}';
        }
      }
      return null;
    } finally {
      // Always close the session
      try {
        await session?.close();
      } catch (e) {
        debugPrint('Error closing session: $e');
      }
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Sign a message with the connected wallet
  /// Returns base58 encoded signature
  Future<String?> signMessage(String message) async {
    // If connected via deep link, use deep link signing
    if (_useDeepLink && _deepLinkWallet != null) {
      return _signMessageWithDeepLink(message, _deepLinkWallet!);
    }

    // Otherwise use MWA
    if (!isConnected || _authToken == null || _publicKeyBytes == null) {
      _errorMessage = 'Wallet not connected';
      notifyListeners();
      return null;
    }

    LocalAssociationScenario? session;

    try {
      // Create session
      debugPrint('Creating MWA session for signing...');
      session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).then((_) {
        debugPrint('Sign activity result received');
      }).catchError((e) {
        debugPrint('Sign activity error: $e');
      });

      final client = await session.start().timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Wallet connection timed out');
        },
      );

      // Reauthorize with existing token
      debugPrint('Reauthorizing...');
      final reauth = await client.reauthorize(
        identityUri: Uri.parse(_appUri),
        iconUri: Uri.parse('$_appUri/$_appIcon'),
        identityName: _appName,
        authToken: _authToken!,
      ).timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Reauthorization timed out');
        },
      );

      if (reauth == null) {
        _errorMessage = 'Reauthorization failed';
        return null;
      }

      // Update auth token if changed
      _authToken = reauth.authToken;

      // Convert message to bytes
      final messageBytes = Uint8List.fromList(utf8.encode(message));

      // Sign the message
      debugPrint('Signing message...');
      final signResult = await client.signMessages(
        messages: [messageBytes],
        addresses: [_publicKeyBytes!],
      ).timeout(
        _connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Signing timed out');
        },
      );

      // Get signature from result
      if (signResult.signedMessages.isNotEmpty) {
        final signedMessage = signResult.signedMessages.first;
        if (signedMessage.signatures.isNotEmpty) {
          final signature = signedMessage.signatures.first;
          debugPrint('Message signed successfully');
          return _toBase58(signature);
        }
      }

      _errorMessage = 'No signature returned';
      return null;
    } on TimeoutException catch (e) {
      debugPrint('Sign message timeout: $e');
      _errorMessage = e.message ?? 'Signing timed out';
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Sign message error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('user rejected') ||
          errorStr.contains('declined') ||
          errorStr.contains('canceled')) {
        _errorMessage = 'Signature rejected by user';
      } else {
        _errorMessage = 'Failed to sign message';
      }
      notifyListeners();
      return null;
    } finally {
      try {
        await session?.close();
      } catch (e) {
        debugPrint('Error closing session: $e');
      }
    }
  }

  /// Disconnect the wallet
  Future<void> disconnect() async {
    if (_authToken != null) {
      LocalAssociationScenario? session;
      try {
        session = await LocalAssociationScenario.create();
        session.startActivityForResult(null).ignore();
        final client = await session.start();
        await client.deauthorize(authToken: _authToken!);
      } catch (e) {
        debugPrint('Disconnect error: $e');
      } finally {
        await session?.close();
      }
    }

    _publicKey = null;
    _publicKeyBytes = null;
    _authToken = null;
    _errorMessage = null;
    // Clear deep link state
    _useDeepLink = false;
    _deepLinkWallet = null;
    _walletSession = null;
    _walletEncryptionPublicKey = null;
    _dappKeyPair = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear temporary deep link state after binding completes
  /// This ensures clean state for future binding attempts
  Future<void> clearTemporaryState() async {
    await _clearDeepLinkState();
    await _clearSignState();
    // Clear in-memory state that might interfere with future bindings
    // but keep _publicKey, _useDeepLink, _deepLinkWallet for isConnected check
    _deepLinkCompleter = null;
    _pendingConnectResult = null;
    _pendingSignResult = null;
    debugPrint('WalletService: Temporary state cleared');
  }

  /// Launch a specific wallet app
  Future<bool> _launchWalletApp(SolanaWallet wallet) async {
    try {
      // Try to launch using Android package name (most reliable)
      final androidIntent = Uri.parse(
        'intent://#Intent;package=${wallet.packageName};end',
      );

      if (await canLaunchUrl(androidIntent)) {
        return await launchUrl(
          androidIntent,
          mode: LaunchMode.externalApplication,
        );
      }

      // Fallback: try using the wallet's scheme
      final schemeUri = Uri.parse('${wallet.scheme}://');
      if (await canLaunchUrl(schemeUri)) {
        return await launchUrl(
          schemeUri,
          mode: LaunchMode.externalApplication,
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error launching wallet app: $e');
      return false;
    }
  }

  /// Connect using Phantom's deep link protocol (convenience method)
  Future<String?> connectWithPhantomDeepLink() async {
    return connectWithDeepLink(SolanaWallet.phantom);
  }

  /// Connect using Solflare's deep link protocol (convenience method)
  Future<String?> connectWithSolflareDeepLink() async {
    return connectWithDeepLink(SolanaWallet.solflare);
  }

  /// Connect using deep link protocol (works with Phantom and Solflare)
  Future<String?> connectWithDeepLink(SolanaWallet wallet) async {
    if (_isConnecting || isConnected) return _publicKey;

    if (!wallet.supportsDeepLink) {
      _errorMessage = '${wallet.name} does not support deep link connection';
      notifyListeners();
      return null;
    }

    _isConnecting = true;
    _errorMessage = null;
    _deepLinkWallet = wallet;
    notifyListeners();

    try {
      // Generate X25519 keypair for encryption
      _dappKeyPair = PrivateKey.generate();
      final dappPublicKey = _dappKeyPair!.publicKey;
      final dappPublicKeyBase58 = _toBase58(Uint8List.fromList(dappPublicKey.toList()));

      debugPrint('Generated dApp public key: $dappPublicKeyBase58');

      // Save state for cold start recovery BEFORE launching wallet
      await _saveDeepLinkState(wallet);

      // Get the connect URL based on wallet
      final connectBaseUrl = wallet == SolanaWallet.phantom
          ? _phantomConnectUrl
          : _solflareConnectUrl;

      // Build the connect URL
      final redirectUri = '$_appScheme://onConnect';
      final params = {
        'app_url': _appUri,
        'dapp_encryption_public_key': dappPublicKeyBase58,
        'cluster': 'mainnet-beta',
        'redirect_link': redirectUri,
      };

      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final connectUri = Uri.parse('$connectBaseUrl?$queryString');
      debugPrint('Opening ${wallet.name} with deep link: $connectUri');

      // Create a completer to wait for the callback BEFORE launching
      // This prevents race condition where callback arrives before completer exists
      _deepLinkCompleter = Completer<String?>();

      // Launch wallet
      final launched = await launchUrl(
        connectUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _errorMessage = 'Could not open ${wallet.name}. Please make sure it is installed.';
        _isConnecting = false;
        _deepLinkWallet = null;
        _deepLinkCompleter = null;
        await _clearDeepLinkState();
        notifyListeners();
        return null;
      }

      // Wait for the callback (with timeout)
      final result = await _deepLinkCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('Deep link timeout');
          return null;
        },
      );

      if (result != null) {
        _publicKey = result;
        debugPrint('Connected via ${wallet.name} deep link: $_publicKey');
      } else if (_errorMessage == null) {
        _errorMessage = 'Connection cancelled or timed out';
        _deepLinkWallet = null;
      }

      // Clear saved state after successful handling
      await _clearDeepLinkState();

      return _publicKey;
    } catch (e) {
      debugPrint('${wallet.name} deep link error: $e');
      _errorMessage = 'Connection failed: ${e.toString()}';
      _deepLinkWallet = null;
      await _clearDeepLinkState();
      return null;
    } finally {
      _deepLinkCompleter = null;
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Handle incoming deep link from wallet callback
  void handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');

    if (uri.scheme.toLowerCase() != _appScheme) return;

    final host = uri.host.toLowerCase();
    if (host == 'onconnect' || uri.path.toLowerCase() == '/onconnect') {
      _handleWalletConnectCallback(uri);
    } else if (host == 'onsignmessage' || uri.path.toLowerCase() == '/onsignmessage') {
      _handleWalletSignMessageCallback(uri);
    }
  }

  void _handleWalletSignMessageCallback(Uri uri) {
    final walletName = _deepLinkWallet?.name ?? 'Wallet';
    final isColdStart = _deepLinkCompleter == null;

    debugPrint('=== $walletName Sign Callback ===');
    debugPrint('Is cold start: $isColdStart');
    debugPrint('_dappKeyPair exists: ${_dappKeyPair != null}');
    debugPrint('_walletEncryptionPublicKey exists: ${_walletEncryptionPublicKey != null}');

    // Check for error first
    if (uri.queryParameters.containsKey('errorCode')) {
      final errorCode = uri.queryParameters['errorCode'];
      final errorMessage = Uri.decodeComponent(
        uri.queryParameters['errorMessage'] ?? 'Signing rejected',
      );
      debugPrint('$walletName sign error: $errorCode - $errorMessage');
      _errorMessage = errorMessage;
      if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
        _deepLinkCompleter!.complete(null);
      }
      _clearSignState();
      notifyListeners();
      return;
    }

    try {
      // Get the encrypted data and nonce
      final dataBase58 = uri.queryParameters['data'];
      final nonceBase58 = uri.queryParameters['nonce'];

      if (dataBase58 != null && nonceBase58 != null && _dappKeyPair != null && _walletEncryptionPublicKey != null) {
        // Decrypt the data
        final encryptedData = _fromBase58(dataBase58);
        final nonce = _fromBase58(nonceBase58);

        debugPrint('Decrypting $walletName sign response...');

        // Create shared secret and decrypt
        final box = Box(
          myPrivateKey: _dappKeyPair!,
          theirPublicKey: PublicKey(_walletEncryptionPublicKey!),
        );

        final decrypted = box.decrypt(
          ByteList(encryptedData),
          nonce: Uint8List.fromList(nonce),
        );

        final jsonStr = utf8.decode(decrypted);
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        debugPrint('Decrypted sign response: $json');

        // Extract the signature
        final signatureBase58 = json['signature'] as String?;
        if (signatureBase58 != null) {
          // Clear the saved sign state
          _clearSignState();

          if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
            // Normal flow - complete the completer
            debugPrint('Got signature (normal flow): $signatureBase58');
            _deepLinkCompleter!.complete(signatureBase58);
          } else if (isColdStart) {
            // Cold start - save result for later retrieval
            debugPrint('Saving signature for cold start recovery: $signatureBase58');
            _pendingSignResult = signatureBase58;
            notifyListeners();
          }
          return;
        }
      } else {
        debugPrint('Missing data for sign decryption:');
        debugPrint('  dataBase58: ${dataBase58 != null}');
        debugPrint('  nonceBase58: ${nonceBase58 != null}');
        debugPrint('  _dappKeyPair: ${_dappKeyPair != null}');
        debugPrint('  _walletEncryptionPublicKey: ${_walletEncryptionPublicKey != null}');
      }

      debugPrint('Could not extract signature from $walletName response');
      _errorMessage = 'Failed to get signature';
      _clearSignState();
      if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
        _deepLinkCompleter!.complete(null);
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing sign callback: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'Failed to process signature: ${e.toString()}';
      _clearSignState();
      if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
        _deepLinkCompleter!.complete(null);
      }
    }
  }

  /// Sign a message using Phantom's deep link protocol (convenience method)
  Future<String?> signMessageWithPhantomDeepLink(String message) async {
    return _signMessageWithDeepLink(message, SolanaWallet.phantom);
  }

  /// Sign a message using wallet's deep link protocol
  Future<String?> _signMessageWithDeepLink(String message, SolanaWallet wallet) async {
    if (_publicKey == null || _walletSession == null || _dappKeyPair == null || _walletEncryptionPublicKey == null) {
      _errorMessage = 'Wallet not connected via deep link';
      notifyListeners();
      return null;
    }

    try {
      debugPrint('Signing message with ${wallet.name} deep link...');
      debugPrint('Session: $_walletSession');

      // Create the payload - message must be base58 encoded
      final messageBytes = Uint8List.fromList(utf8.encode(message));
      final messageBase58 = _toBase58(messageBytes);
      debugPrint('Message (base58): $messageBase58');

      final payload = {
        'message': messageBase58,
        'session': _walletSession,
        'display': 'utf8',  // Display format for the message
      };

      // Encrypt the payload
      final box = Box(
        myPrivateKey: _dappKeyPair!,
        theirPublicKey: PublicKey(_walletEncryptionPublicKey!),
      );

      final nonce = PineNaClUtils.randombytes(24);
      final payloadJson = jsonEncode(payload);
      debugPrint('Payload JSON: $payloadJson');

      final encrypted = box.encrypt(
        Uint8List.fromList(utf8.encode(payloadJson)),
        nonce: nonce,
      ).cipherText;

      final payloadBase58 = _toBase58(Uint8List.fromList(encrypted.toList()));
      final nonceBase58 = _toBase58(Uint8List.fromList(nonce.toList()));
      final dappPublicKeyBase58 = _toBase58(Uint8List.fromList(_dappKeyPair!.publicKey.toList()));

      // Get the sign message URL based on wallet
      final signBaseUrl = wallet == SolanaWallet.phantom
          ? _phantomSignMessageUrl
          : _solflareSignMessageUrl;

      // Build the sign message URL
      final redirectUri = '$_appScheme://onSignMessage';
      final params = {
        'dapp_encryption_public_key': dappPublicKeyBase58,
        'nonce': nonceBase58,
        'redirect_link': redirectUri,
        'payload': payloadBase58,
      };

      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final signUri = Uri.parse('$signBaseUrl?$queryString');

      debugPrint('Opening ${wallet.name} for signing...');

      // Save state for cold start recovery BEFORE launching wallet
      await _saveSignState();

      // Create a completer to wait for the callback BEFORE launching
      // This prevents race condition where callback arrives before completer exists
      _deepLinkCompleter = Completer<String?>();

      // Launch wallet
      final launched = await launchUrl(
        signUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _errorMessage = 'Could not open ${wallet.name}';
        _deepLinkCompleter = null;
        await _clearSignState();
        notifyListeners();
        return null;
      }

      // Wait for the callback (with timeout)
      final result = await _deepLinkCompleter!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          debugPrint('Sign message timeout');
          return null;
        },
      );

      // Clear saved state after successful handling
      await _clearSignState();

      return result;
    } catch (e) {
      debugPrint('Sign message error: $e');
      _errorMessage = 'Failed to sign message: ${e.toString()}';
      notifyListeners();
      return null;
    } finally {
      _deepLinkCompleter = null;
    }
  }

  void _handleWalletConnectCallback(Uri uri) {
    final walletName = _deepLinkWallet?.name ?? 'Wallet';
    final isColdStart = _deepLinkCompleter == null;

    debugPrint('=== $walletName Connect Callback ===');
    debugPrint('Full URI: $uri');
    debugPrint('Query params: ${uri.queryParameters}');
    debugPrint('_dappKeyPair exists: ${_dappKeyPair != null}');
    debugPrint('_deepLinkCompleter exists: ${_deepLinkCompleter != null}');
    debugPrint('_deepLinkCompleter completed: ${_deepLinkCompleter?.isCompleted}');
    debugPrint('Is cold start: $isColdStart');

    // Check for error first
    if (uri.queryParameters.containsKey('errorCode')) {
      final errorCode = uri.queryParameters['errorCode'];
      final errorMessage = Uri.decodeComponent(
        uri.queryParameters['errorMessage'] ?? 'Connection rejected',
      );
      debugPrint('$walletName error: $errorCode - $errorMessage');
      _errorMessage = errorMessage;
      if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
        _deepLinkCompleter!.complete(null);
      }
      _clearDeepLinkState();
      notifyListeners();
      return;
    }

    try {
      // Get wallet's public key for future encrypted communication
      // Phantom uses 'phantom_encryption_public_key', Solflare uses 'solflare_encryption_public_key'
      String? walletPublicKeyBase58 = uri.queryParameters['phantom_encryption_public_key']
          ?? uri.queryParameters['solflare_encryption_public_key'];

      debugPrint('Wallet encryption public key: $walletPublicKeyBase58');

      if (walletPublicKeyBase58 != null) {
        _walletEncryptionPublicKey = _fromBase58(walletPublicKeyBase58);
        debugPrint('$walletName public key decoded, length: ${_walletEncryptionPublicKey!.length}');
      } else {
        debugPrint('WARNING: No encryption public key found in response!');
      }

      // Get the encrypted data and nonce
      final dataBase58 = uri.queryParameters['data'];
      final nonceBase58 = uri.queryParameters['nonce'];

      debugPrint('Data (base58): ${dataBase58 != null ? dataBase58.substring(0, min(50, dataBase58.length)) : "null"}...');
      debugPrint('Nonce (base58): $nonceBase58');

      if (dataBase58 != null && nonceBase58 != null && _dappKeyPair != null && _walletEncryptionPublicKey != null) {
        // Decrypt the data
        final encryptedData = _fromBase58(dataBase58);
        final nonce = _fromBase58(nonceBase58);

        debugPrint('Encrypted data length: ${encryptedData.length}');
        debugPrint('Nonce length: ${nonce.length}');
        debugPrint('Decrypting $walletName response...');

        // Create shared secret and decrypt
        final box = Box(
          myPrivateKey: _dappKeyPair!,
          theirPublicKey: PublicKey(_walletEncryptionPublicKey!),
        );

        final decrypted = box.decrypt(
          ByteList(encryptedData),
          nonce: Uint8List.fromList(nonce),
        );

        final jsonStr = utf8.decode(decrypted);
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        debugPrint('Decrypted $walletName data: $json');

        // Save the session for future requests
        _walletSession = json['session'] as String?;
        _useDeepLink = true;
        debugPrint('Session saved: ${_walletSession != null}');

        // Extract the wallet public key
        final walletPublicKey = json['public_key'] as String?;
        debugPrint('Wallet public key from response: $walletPublicKey');

        if (walletPublicKey != null) {
          // Clear the saved deep link state
          _clearDeepLinkState();

          if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
            // Normal flow - complete the completer
            debugPrint('Completing with wallet public key (normal flow)');
            _deepLinkCompleter!.complete(walletPublicKey);
          } else if (isColdStart) {
            // Cold start - save result for later retrieval
            debugPrint('Saving wallet public key for cold start recovery');
            _pendingConnectResult = walletPublicKey;
            _publicKey = walletPublicKey;
            notifyListeners();
          }
          return;
        } else {
          debugPrint('Cannot complete: walletPublicKey is null');
        }
      } else {
        debugPrint('Missing required data for decryption:');
        debugPrint('  dataBase58: ${dataBase58 != null}');
        debugPrint('  nonceBase58: ${nonceBase58 != null}');
        debugPrint('  _dappKeyPair: ${_dappKeyPair != null}');
        debugPrint('  _walletEncryptionPublicKey: ${_walletEncryptionPublicKey != null}');
      }

      // If we couldn't decrypt, try to get public key directly (shouldn't happen in normal flow)
      final directPublicKey = uri.queryParameters['public_key'];
      if (directPublicKey != null) {
        _clearDeepLinkState();
        if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
          debugPrint('Using direct public key: $directPublicKey');
          _deepLinkCompleter!.complete(directPublicKey);
        } else if (isColdStart) {
          debugPrint('Saving direct public key for cold start recovery');
          _pendingConnectResult = directPublicKey;
          _publicKey = directPublicKey;
          notifyListeners();
        }
        return;
      }

      debugPrint('Could not extract public key from $walletName response');
      _errorMessage = 'Failed to process wallet response';
      _clearDeepLinkState();
      if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
        _deepLinkCompleter!.complete(null);
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing $walletName callback: $e');
      debugPrint('Stack trace: $stackTrace');
      _errorMessage = 'Failed to process wallet response';
      _clearDeepLinkState();
      if (_deepLinkCompleter != null && !_deepLinkCompleter!.isCompleted) {
        _deepLinkCompleter!.complete(null);
      }
    }
  }

  // Base58 decoding helper
  Uint8List _fromBase58(String input) {
    if (input.isEmpty) return Uint8List(0);

    // Count leading '1's (zeros in base58)
    var zeros = 0;
    while (zeros < input.length && input[zeros] == '1') {
      zeros++;
    }

    // Allocate enough space
    final size = ((input.length - zeros) * 733 ~/ 1000) + 1;
    final b256 = List<int>.filled(size, 0);

    var length = 0;
    for (var i = zeros; i < input.length; i++) {
      var carry = _base58Alphabet.indexOf(input[i]);
      if (carry < 0) {
        throw FormatException('Invalid base58 character: ${input[i]}');
      }

      var j = 0;
      for (var it = size - 1; (carry != 0 || j < length) && it >= 0; it--, j++) {
        carry += 58 * b256[it];
        b256[it] = carry % 256;
        carry ~/= 256;
      }
      length = j;
    }

    // Skip leading zeros in byte array result
    var it = size - length;
    while (it < size && b256[it] == 0) {
      it++;
    }

    // Build result with leading zeros
    final result = Uint8List(zeros + (size - it));
    var index = zeros;
    while (it < size) {
      result[index++] = b256[it++];
    }

    return result;
  }

  // Base58 encoding helper
  static const _base58Alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  String _toBase58(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // Count leading zeros
    var zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }

    // Allocate enough space
    final size = ((bytes.length - zeros) * 138 ~/ 100) + 1;
    final b58 = List<int>.filled(size, 0);

    var length = 0;
    for (var i = zeros; i < bytes.length; i++) {
      var carry = bytes[i];
      var j = 0;
      for (var it = size - 1; (carry != 0 || j < length) && it >= 0; it--, j++) {
        carry += 256 * b58[it];
        b58[it] = carry % 58;
        carry ~/= 58;
      }
      length = j;
    }

    // Skip leading zeros in base58 result
    var it = size - length;
    while (it < size && b58[it] == 0) {
      it++;
    }

    // Build result
    final result = StringBuffer();
    for (var i = 0; i < zeros; i++) {
      result.write('1');
    }
    while (it < size) {
      result.write(_base58Alphabet[b58[it++]]);
    }

    return result.toString();
  }
}
