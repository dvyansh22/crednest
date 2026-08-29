import 'dart:convert' show base64Url, jsonDecode;
class TokenManager {
  /// Decodes a JWT's payload and checks its `exp` claim against now.
  bool isExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = _decodeBase64(parts[1]);
      final exp = payload['exp'] as int?;
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (_) {
      return true; // treat any parse failure as expired/invalid
    }
  }

  Map<String, dynamic> _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string');
    }
    final decoded = Uri.decodeFull(
      String.fromCharCodes(base64Url.decode(output)),
    );
    return jsonDecode(decoded) as Map<String, dynamic>;
  }
}