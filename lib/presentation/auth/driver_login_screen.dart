import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_api_data_source.dart';
import '../../l10n/app_localizations.dart';
import '../../models/driver_profile_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/driver_auth_service.dart';
import '../../services/driver_passkey_service.dart';
import '../../services/token_manager.dart';
import '../../theme/app_theme.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  bool _showPasskeyButton = false;

  @override
  void initState() {
    super.initState();
    _loadPasskeyAvailability();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPasskeyAvailability() async {
    final can = await DriverPasskeyService.instance.canSignInWithPasskey();
    if (mounted && can != _showPasskeyButton) {
      setState(() => _showPasskeyButton = can);
    }
  }

  /// Passkey sign-in. Succeeds ONLY when the trusted backend verified the
  /// assertion and returned tokens; otherwise the password form stays usable.
  Future<void> _signInWithPasskey() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await DriverPasskeyService.instance.signIn();
      if (result == null) {
        if (mounted) setState(() => _error = l10n.passkeyFailed);
        return;
      }
      await TokenManager.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        role: 'driver',
      );
      if (mounted) context.go(AppRoutes.driverLocationPermission);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.passkeyFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Offers "Enable Biometric Login" once after a successful password login.
  /// Declining or dismissing never affects the login flow.
  Future<void> _offerPasskeyEnrollment() async {
    final service = DriverPasskeyService.instance;
    if (!await service.shouldOfferEnrollment() || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.enableBiometricLogin),
        content: Text(
          service.isBackendAvailable
              ? l10n.enableBiometricLoginMessage
              : '${l10n.enableBiometricLoginMessage}\n\n${l10n.passkeyUnavailableYet}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.notNow),
          ),
          TextButton(
            // Registration stays disabled until backend verification exists.
            onPressed: service.isBackendAvailable
                ? () => Navigator.of(ctx).pop(true)
                : null,
            child: Text(l10n.enableBiometricLogin),
          ),
        ],
      ),
    );
    if (accept == true) {
      await service.enable();
    } else if (service.isBackendAvailable) {
      await service.dismissOffer();
    }
  }

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.enterUsernameAndPassword);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final DriverProfile user;
      if (MockApiDataSource.useMock) {
        final result = await MockApiDataSource.driverLogin(username, password);
        await TokenManager.saveTokens(
          accessToken: result['access_token'] as String,
          refreshToken: result['refresh_token'] as String? ?? '',
          role: 'driver',
        );
        user = DriverAuthService.parseLoginUser(result);
      } else {
        // DriverAuthService saves the tokens itself.
        user = await DriverAuthService(
          ApiClient(),
        ).login(username: username, password: password);
      }
      if (mounted) {
        // profile_completed == false → Complete Profile → Enable Location → home
        // profile_completed == true  → Enable Location → home
        await _offerPasskeyEnrollment();
        if (!mounted) return;
        if (!user.profileCompleted) {
          debugPrint(
            '[DRIVER ROUTE] DriverLoginScreen: profile_completed=false → driverProfileCompletion',
          );
          context.go(AppRoutes.driverProfileCompletion, extra: user);
        } else {
          debugPrint(
            '[DRIVER ROUTE] DriverLoginScreen: profile_completed=true → driverLocationPermission',
          );
          context.go(AppRoutes.driverLocationPermission);
        }
      }
    } catch (e) {
      final l = AppLocalizations.of(context);
      setState(
        () => _error = ApiException.messageOf(e) ?? l.invalidCredentials,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.driverLanguage),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 40),
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          AppTheme.brandNavy.withAlpha(217),
                          AppTheme.brandNavy.withAlpha(77),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.driverPortal,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.signInOdoo,
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(204),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  l10n.signIn,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.driverAccountSubtitle,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                _buildLabel(l10n.username),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.text,
                  // Native keyboard hint only; the entered text is never
                  // rewritten, so the exact username is sent to Odoo.
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.enterUsername,
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppTheme.secondaryText,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppTheme.cardWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.navyText,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel(l10n.password),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textCapitalization: TextCapitalization.none,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.enterPassword,
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.secondaryText,
                      size: 20,
                    ),
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.secondaryText,
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.borderColor,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.navyText,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                      color: AppTheme.errorRed,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.signIn,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                if (_showPasskeyButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInWithPasskey,
                      icon: const Icon(Icons.fingerprint_rounded, size: 20),
                      label: Text(
                        l10n.signInWithPasskey,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.brandNavy,
                        side: BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: AppTheme.primaryText,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
