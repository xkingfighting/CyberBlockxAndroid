import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_state.dart';
import 'api_service.dart';

/// Authentication status
enum AuthStatus {
  unknown,   // Initial state, checking stored tokens
  unbound,   // Not bound (local player)
  bound,     // Bound to wallet (cloud player)
  binding,   // Binding in progress
  error,     // Error state
}

/// Auth Service - manages wallet binding state and OAuth tokens
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;
  AuthService._internal();

  // Secure storage for tokens
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Storage keys
  static const String _keyAccessToken = 'cyberblockx_access_token';
  static const String _keyRefreshToken = 'cyberblockx_refresh_token';
  static const String _keyTokenExpiry = 'cyberblockx_token_expiry';
  static const String _keyWalletAddress = 'cyberblockx_wallet_address';
  static const String _keyUserId = 'cyberblockx_user_id';
  // Keys for pending binding state (cold start recovery)
  static const String _keyPendingNonce = 'cyberblockx_pending_nonce';
  static const String _keyPendingMessage = 'cyberblockx_pending_message';
  static const String _keyPendingWalletAddress = 'cyberblockx_pending_wallet_address';

  // State
  AuthStatus _status = AuthStatus.unknown;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  String? _walletAddress;
  int? _userId;
  String? _errorMessage;
  bool _isNewUser = false;

  // Pending nonce data for binding
  String? _pendingNonce;
  String? _pendingMessage;

  // Getters
  AuthStatus get status => _status;
  bool get isBound => _status == AuthStatus.bound;
  bool get isBinding => _status == AuthStatus.binding;
  String? get walletAddress => _walletAddress;
  String? get accessToken => _accessToken;
  String? get errorMessage => _errorMessage;
  int? get userId => _userId;
  bool get isNewUser => _isNewUser;

  String get shortWalletAddress {
    if (_walletAddress == null || _walletAddress!.length < 10) {
      return _walletAddress ?? '';
    }
    return '${_walletAddress!.substring(0, 4)}...${_walletAddress!.substring(_walletAddress!.length - 4)}';
  }

  /// Initialize - load tokens from secure storage
  Future<void> init() async {
    try {
      _accessToken = await _storage.read(key: _keyAccessToken);
      _refreshToken = await _storage.read(key: _keyRefreshToken);
      _walletAddress = await _storage.read(key: _keyWalletAddress);

      final expiryStr = await _storage.read(key: _keyTokenExpiry);
      if (expiryStr != null) {
        _tokenExpiry = DateTime.tryParse(expiryStr);
      }

      final userIdStr = await _storage.read(key: _keyUserId);
      if (userIdStr != null) {
        _userId = int.tryParse(userIdStr);
      }

      // Determine status based on stored data
      if (_accessToken != null && _walletAddress != null) {
        _status = AuthStatus.bound;
      } else {
        _status = AuthStatus.unbound;
        // Try to restore pending binding state (cold start recovery)
        await _restorePendingBindingState();
      }
    } catch (e) {
      debugPrint('AuthService init error: $e');
      _status = AuthStatus.unbound;
    }
    notifyListeners();
  }

  /// Step 1 of binding: Get nonce from server
  Future<bool> startBinding(String walletAddress) async {
    _status = AuthStatus.binding;
    _errorMessage = null;
    _walletAddress = walletAddress;
    notifyListeners();

    final result = await ApiService.instance.getBindNonce(walletAddress);

    if (result.isSuccess && result.data != null) {
      _pendingNonce = result.data!.nonce;
      _pendingMessage = result.data!.message;
      // Save pending state for cold start recovery
      await _savePendingBindingState();
      return true;
    }

    _errorMessage = result.errorMessage ?? 'Failed to get nonce';
    _status = AuthStatus.error;
    notifyListeners();
    return false;
  }

  /// Get the message to be signed
  String? get messageToSign => _pendingMessage;

  /// Get the pending wallet address (for cold start recovery)
  String? get pendingWalletAddress => _status == AuthStatus.binding ? _walletAddress : null;

  /// Step 2 of binding: Complete with signature
  /// [walletProvider] - Name of wallet provider (e.g., "Phantom", "Solflare")
  Future<bool> completeBinding(String signature, {String walletProvider = 'Phantom'}) async {
    if (_pendingNonce == null || _pendingMessage == null || _walletAddress == null) {
      _errorMessage = 'Binding not started';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    final result = await ApiService.instance.getTokenByWalletSignature(
      walletAddress: _walletAddress!,
      message: _pendingMessage!,
      signature: signature,
      nonce: _pendingNonce!,
      walletProvider: walletProvider,
    );

    if (result.isSuccess && result.data != null) {
      final tokenData = result.data!;

      _accessToken = tokenData.accessToken;
      _refreshToken = tokenData.refreshToken;
      _tokenExpiry = DateTime.now().add(Duration(seconds: tokenData.expiresIn));
      _userId = tokenData.userId;
      _isNewUser = tokenData.isNewUser ?? false;

      // Save to secure storage
      await _saveTokens();

      // Clear pending data
      _pendingNonce = null;
      _pendingMessage = null;
      await _clearPendingBindingState();

      _status = AuthStatus.bound;
      _errorMessage = null;
      notifyListeners();
      return true;
    }

    _errorMessage = result.errorMessage ?? 'Binding failed';
    _status = AuthStatus.error;
    notifyListeners();
    return false;
  }

  /// Cancel binding process
  void cancelBinding() {
    _pendingNonce = null;
    _pendingMessage = null;
    _walletAddress = null;
    _status = AuthStatus.unbound;
    _errorMessage = null;
    _clearPendingBindingState();
    notifyListeners();
  }

  /// Unbind wallet
  Future<void> unbind() async {
    await _clearTokens();
    await _clearPendingBindingState();
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _walletAddress = null;
    _userId = null;
    _pendingNonce = null;
    _pendingMessage = null;
    _status = AuthStatus.unbound;
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh access token
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    final result = await ApiService.instance.refreshToken(_refreshToken!);

    if (result.isSuccess && result.data != null) {
      final tokenData = result.data!;

      _accessToken = tokenData.accessToken;
      _refreshToken = tokenData.refreshToken;
      _tokenExpiry = DateTime.now().add(Duration(seconds: tokenData.expiresIn));

      await _saveTokens();
      notifyListeners();
      return true;
    }

    // Refresh failed - token might be revoked
    if (result.statusCode == 401 || result.errorCode == 'invalid_grant') {
      await unbind();
    }

    return false;
  }

  /// Check if token is valid (not expired)
  bool get isTokenValid {
    if (_accessToken == null) return false;
    if (_tokenExpiry == null) return true; // No expiry info, assume valid
    return DateTime.now().isBefore(_tokenExpiry!);
  }

  /// Get valid access token (auto refresh if needed)
  Future<String?> getValidAccessToken() async {
    if (!isBound || _accessToken == null) return null;

    // Check if token is about to expire (within 5 minutes)
    if (_tokenExpiry != null) {
      final expiresIn = _tokenExpiry!.difference(DateTime.now());
      if (expiresIn.inMinutes < 5) {
        final refreshed = await refreshAccessToken();
        if (!refreshed) {
          return null;
        }
      }
    }

    return _accessToken;
  }

  /// Clear error state
  void clearError() {
    if (_status == AuthStatus.error) {
      _status = isBound ? AuthStatus.bound : AuthStatus.unbound;
    }
    _errorMessage = null;
    notifyListeners();
  }

  // Private methods for token persistence
  Future<void> _saveTokens() async {
    try {
      if (_accessToken != null) {
        await _storage.write(key: _keyAccessToken, value: _accessToken);
      }
      if (_refreshToken != null) {
        await _storage.write(key: _keyRefreshToken, value: _refreshToken);
      }
      if (_tokenExpiry != null) {
        await _storage.write(key: _keyTokenExpiry, value: _tokenExpiry!.toIso8601String());
      }
      if (_walletAddress != null) {
        await _storage.write(key: _keyWalletAddress, value: _walletAddress);
      }
      if (_userId != null) {
        await _storage.write(key: _keyUserId, value: _userId.toString());
      }
    } catch (e) {
      debugPrint('Save tokens error: $e');
    }
  }

  Future<void> _clearTokens() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyTokenExpiry);
      await _storage.delete(key: _keyWalletAddress);
      await _storage.delete(key: _keyUserId);
    } catch (e) {
      debugPrint('Clear tokens error: $e');
    }
  }

  /// Save pending binding state for cold start recovery
  Future<void> _savePendingBindingState() async {
    try {
      if (_pendingNonce != null) {
        await _storage.write(key: _keyPendingNonce, value: _pendingNonce);
      }
      if (_pendingMessage != null) {
        await _storage.write(key: _keyPendingMessage, value: _pendingMessage);
      }
      if (_walletAddress != null) {
        await _storage.write(key: _keyPendingWalletAddress, value: _walletAddress);
      }
      debugPrint('AuthService: Pending binding state saved');
    } catch (e) {
      debugPrint('Save pending binding state error: $e');
    }
  }

  /// Restore pending binding state after cold start
  Future<void> _restorePendingBindingState() async {
    try {
      final nonce = await _storage.read(key: _keyPendingNonce);
      final message = await _storage.read(key: _keyPendingMessage);
      final walletAddr = await _storage.read(key: _keyPendingWalletAddress);

      if (nonce != null && message != null && walletAddr != null) {
        _pendingNonce = nonce;
        _pendingMessage = message;
        _walletAddress = walletAddr;
        _status = AuthStatus.binding;
        debugPrint('AuthService: Pending binding state restored for wallet: $walletAddr');
      }
    } catch (e) {
      debugPrint('Restore pending binding state error: $e');
    }
  }

  /// Clear pending binding state
  Future<void> _clearPendingBindingState() async {
    try {
      await _storage.delete(key: _keyPendingNonce);
      await _storage.delete(key: _keyPendingMessage);
      await _storage.delete(key: _keyPendingWalletAddress);
      debugPrint('AuthService: Pending binding state cleared');
    } catch (e) {
      debugPrint('Clear pending binding state error: $e');
    }
  }
}
