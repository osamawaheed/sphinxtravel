import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final int splashIndex;
  const SplashScreen({super.key, required this.splashIndex});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  int _currentPage = 0;

  static const String _mountainImage =
      'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?auto=format&fit=crop&w=1200&q=80';

  List<_OnboardingData> _buildSlides(AppLocalizations l10n) => [
    _OnboardingData(
      image: _mountainImage,
      headline: l10n.splashHeadline1,
      subtitle: l10n.splashBody1,
      buttonLabel: l10n.splashButton1,
    ),
    _OnboardingData(
      image: _mountainImage,
      headline: l10n.splashHeadline2,
      subtitle: l10n.splashBody2,
      buttonLabel: l10n.splashButton2,
    ),
    _OnboardingData(
      image: _mountainImage,
      headline: l10n.splashHeadline3,
      subtitle: l10n.splashBody3,
      buttonLabel: l10n.splashButton3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentPage = (widget.splashIndex - 1).clamp(0, 2);
    _pageController = PageController(initialPage: _currentPage);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _animController.reset();
    _animController.forward();
    context.go('/splash/${index + 1}');
  }

  void _onButtonTap() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go(AppRoutes.userTypeSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            children: [
              // Rounded full-height image card
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        data: _buildSlides(l10n)[index],
                        isActive: index == _currentPage,
                        fadeIn: _fadeIn,
                        slideUp: _slideUp,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Page indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 34 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.brandNavy
                          : const Color(0xFFBDBDBD),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              // CTA Button
              GestureDetector(
                onTap: _onButtonTap,
                child: Container(
                  width: double.infinity,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2D45),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    _buildSlides(l10n)[_currentPage].buttonLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingData {
  final String image;
  final String headline;
  final String subtitle;
  final String buttonLabel;

  const _OnboardingData({
    required this.image,
    required this.headline,
    required this.subtitle,
    required this.buttonLabel,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final bool isActive;
  final Animation<double> fadeIn;
  final Animation<double> slideUp;

  const _OnboardingPage({
    required this.data,
    required this.isActive,
    required this.fadeIn,
    required this.slideUp,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          data.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(color: const Color(0xFF0B0F14)),
        ),
        // Dark gradient overlay fading to black at the bottom
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Colors.transparent,
                Color(0x66000000),
                Color(0xE6000000),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.25, 0.60, 0.80, 1.0],
            ),
          ),
        ),
        // Right-aligned headline + subtitle at the bottom of the card
        Positioned(
          left: 28,
          right: 28,
          bottom: 28,
          child: FadeTransition(
            opacity: fadeIn,
            child: AnimatedBuilder(
              animation: slideUp,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, slideUp.value),
                child: child,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white.withAlpha(190),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
