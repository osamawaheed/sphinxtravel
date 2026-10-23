import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../data/mock_api_data_source.dart';
import '../../services/api_client.dart';
import '../../services/customer_auth_service.dart';
import '../../services/token_manager.dart';
import '../../l10n/app_localizations.dart';

enum OtpState { idle, loading, invalid, expired, tooManyAttempts }

class CustomerOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String requestId;
  final int expiresIn;
  final String? debugOtp;
  const CustomerOtpScreen({
    super.key,
    required this.phoneNumber,
    this.requestId = '',
    this.expiresIn = 120,
    this.debugOtp,
  });

  @override
  State<CustomerOtpScreen> createState() => _CustomerOtpScreenState();
}

class _CustomerOtpScreenState extends State<CustomerOtpScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  static const int _length = 6;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  OtpState _state = OtpState.idle;
  String? _apiErrorMessage;
  int _countdown = 120;
  Timer? _timer;
  int _attempts = 0;
  late String _requestId;
  String? _debugOtp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    _requestId = widget.requestId;
    _debugOtp = widget.debugOtp;
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());

    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    // Handle paste: if value length > 1, distribute across boxes
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < _length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      setState(() {});
      final nextIndex = (digits.length < _length ? digits.length : _length - 1);
      _focusNodes[nextIndex].requestFocus();
      if (digits.length == _length) {
        _verify();
      }
      return;
    }

    if (value.isEmpty) {
      setState(() {});
      return;
    }

    // Single digit entered — keep only the last character, without touching
    // the controller when it already holds exactly one digit.
    final digit = value[value.length - 1];
    if (value != digit) {
      _controllers[index].value = TextEditingValue(
        text: digit,
        selection: const TextSelection.collapsed(offset: 1),
      );
    }
    setState(() {});

    if (index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      _verify();
    }
  }

  /// Only intercept Backspace when the current box is already empty (to jump
  /// back to the previous box). Otherwise let the TextField delete natively.
  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _startCountdown([int? seconds]) {
    _countdown = seconds ?? widget.expiresIn;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
        if (mounted) setState(() {});
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  Future<void> _verify() async {
    final otp = _otpValue;
    if (otp.length < 6) return;

    if (_attempts >= 5) {
      setState(() {
        _apiErrorMessage = null;
        _state = OtpState.tooManyAttempts;
      });
      return;
    }

    setState(() {
      _apiErrorMessage = null;
      _state = OtpState.loading;
    });
    _attempts++;

    try {
      if (MockApiDataSource.useMock) {
        final result = await MockApiDataSource.verifyOtp(
          widget.phoneNumber,
          otp,
        );
        await TokenManager.saveTokens(
          accessToken: result['access_token'] as String,
          refreshToken: result['refresh_token'] as String? ?? '',
          role: 'customer',
        );
      } else {
        // CustomerAuthService saves the tokens itself.
        await CustomerAuthService(ApiClient()).verifyOtp(
          phoneNumber: widget.phoneNumber,
          requestId: _requestId,
          otp: otp,
        );
      }
      if (mounted) {
        context.go(AppRoutes.customerHome);
      }
    } catch (e) {
      final msg = e.toString();
      final code = e is ApiException ? e.code : '';
      if (mounted) {
        setState(() {
          _apiErrorMessage = ApiException.messageOf(e);
          if (code == ApiException.otpTooManyAttempts) {
            _state = OtpState.tooManyAttempts;
          } else if (code == ApiException.otpExpired ||
              (code.isEmpty && msg.contains('expired'))) {
            _state = OtpState.expired;
          } else {
            _state = OtpState.invalid;
          }
        });
        _clearAll();
        _focusNodes[0].requestFocus();
      }
    }
  }

  void _clearAll() {
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {});
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    setState(() {
      _state = OtpState.idle;
      _apiErrorMessage = null;
      _attempts = 0;
    });
    _clearAll();
    _focusNodes[0].requestFocus();
    int? newExpiresIn;
    try {
      Map<String, dynamic> res;
      if (MockApiDataSource.useMock) {
        res = await MockApiDataSource.requestOtp(widget.phoneNumber);
      } else {
        res = await CustomerAuthService(
          ApiClient(),
        ).requestOtp(phoneNumber: widget.phoneNumber);
      }
      final newId = res['request_id']?.toString();
      if (newId != null && newId.isNotEmpty) _requestId = newId;
      newExpiresIn = (res['expires_in'] as num?)?.toInt();
      if (mounted && !MockApiDataSource.useMock) {
        setState(() => _debugOtp = ApiClient.debugOtpFrom(res));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _apiErrorMessage = ApiException.messageOf(e));
      }
    }
    _startCountdown(newExpiresIn);
  }

  String _errorMessage(AppLocalizations l10n) {
    if (_apiErrorMessage != null && _apiErrorMessage!.isNotEmpty) {
      return _apiErrorMessage!;
    }
    switch (_state) {
      case OtpState.invalid:
        return l10n.invalidCode;
      case OtpState.expired:
        return l10n.expiredCode;
      case OtpState.tooManyAttempts:
        return l10n.tooManyAttempts;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasError =
        _state == OtpState.invalid ||
        _state == OtpState.expired ||
        _state == OtpState.tooManyAttempts;

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
                  onTap: () => context.go(AppRoutes.customerLogin),
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
                const SizedBox(height: 40),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Color(0xFF25D366),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.verifyPhoneNumber,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.primaryText,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: AppTheme.appFont(
                      context,
                      color: AppTheme.secondaryText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: '${l10n.otpSentTo}\n'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            widget.phoneNumber,
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: ' ${l10n.viaWhatsapp}'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // TEST MODE only: shows the OTP actually returned by the
                // Odoo testing API. Hidden when the backend sends none.
                if (_debugOtp != null && _debugOtp!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0B84C)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).testMode,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8A6D00),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            'Your verification code: $_debugOtp',
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // OTP boxes — always LTR regardless of locale
                Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_length, (i) {
                    return SizedBox(
                      width: 46,
                      height: 56,
                      child: Focus(
                        onKeyEvent: (node, event) => _handleKeyEvent(i, event),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          keyboardType: TextInputType.number,
                          textCapitalization: TextCapitalization.none,
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          maxLength: 2,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) => _onChanged(i, v),
                          cursorColor: colorScheme.primary,
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryText,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: hasError
                                ? AppTheme.errorRed.withAlpha(13)
                                : AppTheme.cardWhite,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: hasError
                                    ? AppTheme.errorRed
                                    : colorScheme.outline,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: hasError
                                    ? AppTheme.errorRed
                                    : colorScheme.outline,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: hasError
                                    ? AppTheme.errorRed
                                    : colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(l10n),
                    style: AppTheme.appFont(
                      context,
                      color: AppTheme.errorRed,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _state == OtpState.loading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _state == OtpState.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.verify,
                            style: AppTheme.appFont(
                              context,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: _countdown > 0
                      ? Text(
                          '${l10n.resendIn} $_countdown${l10n.seconds}',
                          style: AppTheme.appFont(
                            context,
                            color: AppTheme.secondaryText,
                            fontSize: 14,
                          ),
                        )
                      : GestureDetector(
                          onTap: _resend,
                          child: Text(
                            l10n.resendCode,
                            style: AppTheme.appFont(
                              context,
                              color: AppTheme.navyText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
