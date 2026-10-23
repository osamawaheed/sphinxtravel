import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/localization_service.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  final LocalizationService _locService = LocalizationService.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _locService.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    _locService.removeListener(_onLangChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isArabic = _locService.currentLanguage == 'ar';
    final textDir = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final l10n = AppLocalizations(_locService.currentLanguage);

    return Directionality(
      textDirection: textDir,
      child: Scaffold(
        backgroundColor: AppTheme.mainBackground,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 44),
                  // Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                      const SizedBox(width: 12),
                      Text(
                        l10n.travelOperations,
                        style: AppTheme.appFont(
                          context,
                          color: AppTheme.navyText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  // Heading
                  Text(
                    l10n.howToContinue,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.appFont(
                      context,
                      color: AppTheme.primaryText,
                      fontSize: isArabic ? 22 : 26,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectRoleSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTheme.appFont(
                      context,
                      color: AppTheme.secondaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Customer Card
                  _RoleCard(
                    icon: Icons.person_outline_rounded,
                    title: l10n.customer,
                    subtitle: l10n.manageJourney,
                    onTap: () => context.go(AppRoutes.customerLanguage),
                    isPrimary: true,
                    isRTL: isArabic,
                  ),
                  const SizedBox(height: 16),
                  // Driver Card
                  _RoleCard(
                    icon: Icons.directions_car_outlined,
                    title: l10n.driver,
                    subtitle: l10n.manageTrips,
                    onTap: () => context.go(AppRoutes.driverLanguage),
                    isPrimary: false,
                    isRTL: isArabic,
                  ),
                  const Spacer(),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      l10n.copyright,
                      style: AppTheme.appFont(
                        context,
                        color: AppTheme.secondaryText.withAlpha(153),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role Card ─────────────────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isRTL;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.isPrimary,
    required this.isRTL,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.isPrimary ? AppTheme.brandNavy : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isPrimary
                  ? AppTheme.brandNavy
                  : AppTheme.borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isPrimary
                    ? AppTheme.brandNavy.withAlpha(51)
                    : AppTheme.shadowColor,
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.isRTL) ...[
                Icon(
                  Icons.arrow_back_ios_rounded,
                  color: widget.isPrimary
                      ? Colors.white.withAlpha(153)
                      : AppTheme.secondaryText,
                  size: 16,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.right,
                        style: AppTheme.appFont(
                          context,
                          color: widget.isPrimary
                              ? Colors.white
                              : AppTheme.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.right,
                        style: AppTheme.appFont(
                          context,
                          color: widget.isPrimary
                              ? Colors.white.withAlpha(179)
                              : AppTheme.secondaryText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.isPrimary
                        ? AppTheme.luxuryAccent.withAlpha(38)
                        : AppTheme.softGoldBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isPrimary
                        ? AppTheme.luxuryAccent
                        : AppTheme.navyText,
                    size: 28,
                  ),
                ),
              ] else ...[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.isPrimary
                        ? AppTheme.luxuryAccent.withAlpha(38)
                        : AppTheme.softGoldBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isPrimary
                        ? AppTheme.luxuryAccent
                        : AppTheme.navyText,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTheme.appFont(
                          context,
                          color: widget.isPrimary
                              ? Colors.white
                              : AppTheme.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: AppTheme.appFont(
                          context,
                          color: widget.isPrimary
                              ? Colors.white.withAlpha(179)
                              : AppTheme.secondaryText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: widget.isPrimary
                      ? Colors.white.withAlpha(153)
                      : AppTheme.secondaryText,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
