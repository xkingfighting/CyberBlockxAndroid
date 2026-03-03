import 'dart:convert';
import 'dart:typed_data';
import 'package:pinenacl/api.dart';
import 'package:pinenacl/x25519.dart';

/// Cryptographic utilities for Solana wallet integration.
/// Provides Base58 encoding/decoding and NaCl box encryption/decryption.
class CryptoHelper {
  CryptoHelper._();

  static const _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  /// Decode a Base58 encoded string to bytes.
  static Uint8List fromBase58(String input) {
    if (input.isEmpty) return Uint8List(0);

    var zeros = 0;
    while (zeros < input.length && input[zeros] == '1') {
      zeros++;
    }

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

    var it = size - length;
    while (it < size && b256[it] == 0) {
      it++;
    }

    final result = Uint8List(zeros + (size - it));
    var index = zeros;
    while (it < size) {
      result[index++] = b256[it++];
    }

    return result;
  }

  /// Encode bytes to Base58 string.
  static String toBase58(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    var zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }

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

    var it = size - length;
    while (it < size && b58[it] == 0) {
      it++;
    }

    final result = StringBuffer();
    for (var i = 0; i < zeros; i++) {
      result.write('1');
    }
    while (it < size) {
      result.write(_base58Alphabet[b58[it++]]);
    }

    return result.toString();
  }

  /// Generate a new X25519 keypair for dApp encryption.
  static PrivateKey generateKeyPair() => PrivateKey.generate();

  /// Get the Base58-encoded public key from a private key.
  static String publicKeyBase58(PrivateKey privateKey) {
    return toBase58(Uint8List.fromList(privateKey.publicKey.toList()));
  }

  /// Get raw private key bytes.
  static Uint8List privateKeyBytes(PrivateKey privateKey) {
    return Uint8List.fromList(privateKey.toList());
  }

  /// Reconstruct a PrivateKey from raw bytes.
  static PrivateKey privateKeyFromBytes(Uint8List bytes) {
    return PrivateKey(bytes);
  }

  /// Encrypt a JSON payload using NaCl box.
  /// Returns the cipher text and the random nonce used.
  static ({Uint8List cipherText, Uint8List nonce}) encryptPayload(
    PrivateKey myKey,
    Uint8List theirPublicKey,
    Map<String, dynamic> payload,
  ) {
    final box = Box(
      myPrivateKey: myKey,
      theirPublicKey: PublicKey(theirPublicKey),
    );
    final nonce = PineNaClUtils.randombytes(24);
    final payloadJson = jsonEncode(payload);
    final encrypted = box.encrypt(
      Uint8List.fromList(utf8.encode(payloadJson)),
      nonce: nonce,
    ).cipherText;

    return (
      cipherText: Uint8List.fromList(encrypted.toList()),
      nonce: Uint8List.fromList(nonce.toList()),
    );
  }

  /// Decrypt data using NaCl box and parse as JSON.
  static Map<String, dynamic> decryptPayload(
    PrivateKey myKey,
    Uint8List theirPublicKey,
    Uint8List encryptedData,
    Uint8List nonce,
  ) {
    final box = Box(
      myPrivateKey: myKey,
      theirPublicKey: PublicKey(theirPublicKey),
    );
    final decrypted = box.decrypt(
      ByteList(encryptedData),
      nonce: Uint8List.fromList(nonce),
    );
    final jsonStr = utf8.decode(decrypted);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
