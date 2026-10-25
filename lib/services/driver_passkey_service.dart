import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a Passkey ceremony performed against a trusted backend.
class DriverPasskeyLoginResult {
  /// Access token issued by the backend AFTER it verified the WebAuthn
  /// assertion. Never produced by a local biometric check.
  final String accessToken;
  final String refreshToken;

  const DriverPasskeyLoginResult({
    required this.accessToken,
    required this.refreshToken,
  });
}

/// Integration-ready contract for server-verified WebAuthn / FIDO2 Passkeys.
///
/// A real implementation MUST:
///  1. Ask the backend for registration / authentication options (challenge).
///  2. Run the platform WebAuthn ceremony (Android Credential Manager,
///     iOS AuthenticationServices, browser WebAuthn).
///  3. Send the attestation / assertion to the backend for verification.
///  4. Only treat the user as signed in when the backend returns tokens.
///
/// A local biometric prompt alone is NEVER server authentication.
abstract class DriverPasskeyBackend {
  /// True only when the backend verification endpoints are live.
  bool get isAvailable;

  /// Registers a new Passkey for the signed-in driver.
  /// Returns true only when the backend confirmed the registration.
  Future<bool> register();

  /// Signs in with a previously registered Passkey.
  /// Returns null when cancelled / failed.
  Future<DriverPasskeyLoginResult?> authenticate();

  /// Removes the driver's Passkey on the backend. Returns true when removed.
  Future<bool> unregister();
}

/// Default backend used until the Odoo Passkey endpoints are ready.
/// Every operation is a no-op that reports failure; nothing is simulated.
class UnavailableDriverPasskeyBackend implements DriverPasskeyBackend {
  const UnavailableDriverPasskeyBackend();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> register() async => false;

  @override
  Future<DriverPasskeyLoginResult?> authenticate() async => null;

  @override
  Future<bool> unregister() async => false;
}

/// Driver-only Passkey state + orchestration.
///
/// Stores a single non-secret boolean preference ("driver chose to use
/// Passkey on this device"). No passwords, tokens or biometric data are
/// persisted by this class.
class DriverPasskeyService {
  DriverPasskeyService._();
  static final DriverPasskeyService instance = DriverPasskeyService._();

  static const String _enabledKey = 'driver_passkey_enabled';
  static const String _offerDismissedKey = 'driver_passkey_offer_dismissed';

  /// Swap this with a real implementation once backend verification exists.
  DriverPasskeyBackend backend = const UnavailableDriverPasskeyBackend();

  /// Live flag so Settings / Login can react to changes.
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  bool _loaded = false;

  /// Real Passkey registration / login is possible only with a live backend.
  bool get isBackendAvailable => backend.isAvailable;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      enabledNotifier.value = false;
    }
    _loaded = true;
  }

  /// True when the driver enabled Passkey on this device AND the backend can
  /// actually verify it.
  Future<bool> canSignInWithPasskey() async {
    await _ensureLoaded();
    return enabledNotifier.value && backend.isAvailable;
  }

  Future<bool> isEnabled() async {
    await _ensureLoaded();
    return enabledNotifier.value;
  }

  /// Whether to show the post-login "Enable Biometric Login" offer.
  Future<bool> shouldOfferEnrollment() async {
    await _ensureLoaded();
    if (enabledNotifier.value) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_offerDismissedKey) ?? false);
    } catch (_) {
      return true;
    }
  }

  Future<void> dismissOffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_offerDismissedKey, true);
    } catch (_) {}
  }

  /// Registers a Passkey through the backend. Returns false (and changes
  /// nothing) while the backend is unavailable.
  Future<bool> enable() async {
    await _ensureLoaded();
    if (!backend.isAvailable) return false;
    final ok = await backend.register();
    if (!ok) return false;
    await _setEnabled(true);
    return true;
  }

  /// Signs in with Passkey. Returns null unless the backend verified it.
  Future<DriverPasskeyLoginResult?> signIn() async {
    await _ensureLoaded();
    if (!enabledNotifier.value || !backend.isAvailable) return null;
    return backend.authenticate();
  }

  /// Disables Passkey login for this device. Always clears the local flag;
  /// also asks the backend to remove the credential when it is available.
  Future<void> disable() async {
    await _ensureLoaded();
    if (backend.isAvailable) {
      try {
        await backend.unregister();
      } catch (_) {}
    }
    await _setEnabled(false);
  }

  Future<void> _setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
    enabledNotifier.value = value;
  }
}
