/// Token Response from OAuth endpoint
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final String? scope;
  final int? userId;
  final String? walletAddress;
  final bool? isNewUser;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.tokenType = 'Bearer',
    this.scope,
    this.userId,
    this.walletAddress,
    this.isNewUser,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    // Handle expires_in as int or String
    int expiresIn;
    final expiresInValue = json['expires_in'];
    if (expiresInValue is int) {
      expiresIn = expiresInValue;
    } else if (expiresInValue is String) {
      expiresIn = int.tryParse(expiresInValue) ?? 3600;
    } else {
      expiresIn = 3600; // Default 1 hour
    }

    // Handle user_id as int or String
    int? userId;
    final userIdValue = json['user_id'];
    if (userIdValue is int) {
      userId = userIdValue;
    } else if (userIdValue is String) {
      userId = int.tryParse(userIdValue);
    }

    return TokenResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: expiresIn,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      scope: json['scope'] as String?,
      userId: userId,
      walletAddress: json['wallet_address'] as String?,
      isNewUser: json['is_new_user'] as bool?,
    );
  }
}

/// Nonce Response from GetBindNonce endpoint
class NonceResponse {
  final String nonce;
  final String? message;
  final String? messageTemplate;
  final String? issuedAt;
  final String? expireAt;
  final String? domain;

  NonceResponse({
    required this.nonce,
    this.message,
    this.messageTemplate,
    this.issuedAt,
    this.expireAt,
    this.domain,
  });

  factory NonceResponse.fromJson(Map<String, dynamic> json, {String? walletAddress}) {
    final nonce = json['nonce'] as String;
    final messageTemplate = json['messageTemplate'] as String?;
    final issuedAt = json['issuedAt'] as String?;
    final expireAt = json['expireAt'] as String?;
    final domain = json['domain'] as String?;

    // Generate message from template if message is null
    String? message = json['message'] as String?;
    if (message == null && messageTemplate != null) {
      message = messageTemplate
          .replaceAll('{walletAddress}', walletAddress ?? '')
          .replaceAll('{nonce}', nonce)
          .replaceAll('{issuedAt}', issuedAt ?? '')
          .replaceAll('{expireAt}', expireAt ?? '')
          .replaceAll('{domain}', domain ?? '');
    }

    return NonceResponse(
      nonce: nonce,
      message: message,
      messageTemplate: messageTemplate,
      issuedAt: issuedAt,
      expireAt: expireAt,
      domain: domain,
    );
  }
}
