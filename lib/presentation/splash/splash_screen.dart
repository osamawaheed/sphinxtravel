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
    'assets/images/1-1793459154937.png',
    'assets/images/2-1793459154925.png',
    'assets/images/3-1793459154800.png',
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            children: [
              // Rounded elevated card
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: 3,
                  clipBehavior: Clip.none,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F000000),
                              blurRadius: 24,
                              spreadRadius: 1,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          clipBehavior: Clip.antiAlias,
                          child: _OnboardingPage(
                            data: _buildSlides(l10n)[index],
                            isActive: index == _currentPage,
                            fadeIn: _fadeIn,
                            slideUp: _slideUp,
                          ),
                        ),
                      ),
                    );
                  },
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
    return Column(
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: ClipRect(
              child: Transform.scale(
                scale: 1.12,
                alignment: Alignment.topCenter,
                child: Image.asset(
                  data.image,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
                      color: Color(0xFF1B2D45),
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF1B2D45),
                      fontSize: 15,
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
