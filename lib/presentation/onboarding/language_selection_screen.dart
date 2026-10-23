import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/localization_service.dart';
import '../../l10n/app_localizations.dart';

// ─── Customer Language Screen ──────────────────────────────────────────────

class CustomerLanguageScreen extends StatefulWidget {
  const CustomerLanguageScreen({super.key});

  @override
  State<CustomerLanguageScreen> createState() => _CustomerLanguageScreenState();
}

class _CustomerLanguageScreenState extends State<CustomerLanguageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String? _selecting;

  static const List<Map<String, String>> _languages = [
    {'code': 'ar', 'label': 'العربية', 'sublabel': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'en', 'label': 'English', 'sublabel': 'English', 'flag': '🇬🇧'},
  ];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _selectLanguage(String code) async {
    if (_selecting != null) return;
    setState(() => _selecting = code);
    // Apply language immediately — triggers rebuild via LocalizationService notifier
    await LocalizationService.instance.setLanguage(code, role: 'customer');
    if (mounted) {
      context.go(AppRoutes.customerLogin);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.userTypeSelection),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.brandNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: AppTheme.luxuryAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.selectLanguage,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.primaryText,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectLanguageSubtitle,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),
                ..._languages.map(
                  (lang) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _LanguageCard(
                      code: lang['code']!,
                      label: lang['label']!,
                      sublabel: lang['sublabel']!,
                      flag: lang['flag']!,
                      isLoading: _selecting == lang['code'],
                      onTap: () => _selectLanguage(lang['code']!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Driver Language Screen ────────────────────────────────────────────────

class DriverLanguageScreen extends StatefulWidget {
  const DriverLanguageScreen({super.key});

  @override
  State<DriverLanguageScreen> createState() => _DriverLanguageScreenState();
}

class _DriverLanguageScreenState extends State<DriverLanguageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  String? _selecting;

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English', 'sublabel': 'English', 'flag': '🇬🇧'},
    {'code': 'ru', 'label': 'Русский', 'sublabel': 'Russian', 'flag': '🇷🇺'},
    {'code': 'ka', 'label': 'ქართული', 'sublabel': 'Georgian', 'flag': '🇬🇪'},
  ];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _selectLanguage(String code) async {
    if (_selecting != null) return;
    setState(() => _selecting = code);
    await LocalizationService.instance.setLanguage(code, role: 'driver');
    if (mounted) {
      context.go(AppRoutes.driverLogin);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.userTypeSelection),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.brandNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car_outlined,
                    color: AppTheme.luxuryAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.selectLanguage,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.primaryText,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.selectLanguageSubtitle,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),
                ..._languages.map(
                  (lang) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _LanguageCard(
                      code: lang['code']!,
                      label: lang['label']!,
                      sublabel: lang['sublabel']!,
                      flag: lang['flag']!,
                      isLoading: _selecting == lang['code'],
                      onTap: () => _selectLanguage(lang['code']!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared Language Card ──────────────────────────────────────────────────

class _LanguageCard extends StatefulWidget {
  final String code;
  final String label;
  final String sublabel;
  final String flag;
  final bool isLoading;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.code,
    required this.label,
    required this.sublabel,
    required this.flag,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(widget.flag, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: AppTheme.appFont(
                        context,
                        color: AppTheme.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.sublabel,
                      style: AppTheme.appFont(
                        context,
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.brandNavy,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.secondaryText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
