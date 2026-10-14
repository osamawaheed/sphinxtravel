import './token_manager.dart';

class CommonAuthService {
  static Future<String?> getSessionRole() async {
    return TokenManager.getUserRole();
  }

  static Future<bool> hasActiveSession() async {
    return TokenManager.hasValidSession();
  }

  static Future<void> clearSession() async {
    await TokenManager.clearTokens();
  }
}
