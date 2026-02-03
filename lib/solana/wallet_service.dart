import 'package:flutter/foundation.dart';

/// Solana wallet connection service (stub implementation)
/// TODO: Enable real Solana integration when solana_wallet_adapter is compatible with AGP 8.0+
class WalletService extends ChangeNotifier {
  static final WalletService instance = WalletService._();
  WalletService._();

  String? _publicKey;
  bool _isConnecting = false;

  /// Whether a wallet is connected
  bool get isConnected => _publicKey != null;

  /// Whether currently attempting to connect
  bool get isConnecting => _isConnecting;

  /// The connected wallet's public key
  String? get publicKey => _publicKey;

  /// Shortened address for display (e.g., "ABC1...XYZ9")
  String get shortAddress {
    if (_publicKey == null) return '';
    if (_publicKey!.length < 10) return _publicKey!;
    return '${_publicKey!.substring(0, 4)}...${_publicKey!.substring(_publicKey!.length - 4)}';
  }

  /// Connect to a Solana wallet
  /// Currently shows a placeholder message - real implementation pending
  Future<void> connect() async {
    if (_isConnecting || isConnected) return;

    _isConnecting = true;
    notifyListeners();

    try {
      // Stub: Simulate wallet connection
      // In production, this would use solana_wallet_adapter
      await Future.delayed(const Duration(milliseconds: 500));

      // For now, throw an error to indicate feature is coming soon
      throw Exception('Solana wallet integration coming soon! Stay tuned.');
    } catch (e) {
      debugPrint('Wallet connection: $e');
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnect the wallet
  Future<void> disconnect() async {
    _publicKey = null;
    notifyListeners();
  }

  /// Set wallet address (for testing)
  void setTestAddress(String address) {
    _publicKey = address;
    notifyListeners();
  }
}
