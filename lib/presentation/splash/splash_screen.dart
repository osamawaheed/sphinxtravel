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

  static const List<String> _slideImages = [
    'assets/images/12242415833_b81c4d2337_k-1793894428459.jpg',
    'assets/images/knyon_martvli-1793894503709.jpg',
    'assets/images/kazbegi_mountain_7-1793894594930.jpg',
  ];

  List<_OnboardingData> _buildSlides(AppLocalizations l10n) => [
    _OnboardingData(
      image: _slideImages[0],
      headline: l10n.splashHeadline1,
      subtitle: l10n.splashBody1,
      buttonLabel: l10n.splashButton1,
    ),
    _OnboardingData(
      image: _slideImages[1],
      headline: l10n.splashHeadline2,
      subtitle: l10n.splashBody2,
      buttonLabel: l10n.splashButton2,
    ),
    _OnboardingData(
      image: _slideImages[2],
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
    final slides = _buildSlides(l10n);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: 3,
                itemBuilder: (context, index) {
                  return _OnboardingPage(
                    data: slides[index],
                    fadeIn: _fadeIn,
                    slideUp: _slideUp,
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
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
                        : const Color(0xFFD0D0D8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: GestureDetector(
                onTap: _onButtonTap,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.brandNavy,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    slides[_currentPage].buttonLabel,
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
            ),
          ],
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
  final Animation<double> fadeIn;
  final Animation<double> slideUp;

  const _OnboardingPage({
    required this.data,
    required this.fadeIn,
    required this.slideUp,
  });

  static String _stripTrailingDash(String text) {
    return text.replaceAll(RegExp(r'\s*[—–\-]+\s*$'), '').trimRight();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalHeight = constraints.maxHeight;
        final double width = constraints.maxWidth;
        final double imageHeight = totalHeight * 0.66;
        final double gradientHeight = (imageHeight * 0.45).clamp(120.0, 260.0);
        final double headlineSize = (width * 0.082).clamp(24.0, 36.0);
        final double bodySize = (width * 0.04).clamp(14.0, 16.0);

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      data.image,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -1,
                      height: gradientHeight + 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withAlpha(0),
                              Colors.white.withAlpha(60),
                              Colors.white.withAlpha(140),
                              Colors.white.withAlpha(215),
                              Colors.white,
                            ],
                            stops: const [0.0, 0.3, 0.55, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  child: FadeTransition(
                    opacity: fadeIn,
                    child: AnimatedBuilder(
                      animation: slideUp,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, slideUp.value),
                        child: child,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: width - 48,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data.headline,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppTheme.brandNavy,
                                  fontSize: headlineSize,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _stripTrailingDash(data.subtitle),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: const Color(0xFF4A5568),
                                  fontSize: bodySize,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
