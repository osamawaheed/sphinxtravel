import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  static const List<_OnboardingData> _slides = [
    _OnboardingData(
      image:
          'https://images.pexels.com/photos/1624438/pexels-photo-1624438.jpeg?auto=compress&cs=tinysrgb&w=1200',
      headline: 'Your Journey\nStarts Here',
      subtitle:
          'Everything you need for a seamless travel experience, all in one place.',
      buttonLabel: 'Explore Your Journey',
    ),
    _OnboardingData(
      image:
          'https://images.pexels.com/photos/2662116/pexels-photo-2662116.jpeg?auto=compress&cs=tinysrgb&w=1200',
      headline: 'Every Trip.\nPerfectly Managed.',
      subtitle:
          'Stay connected, follow your schedule, and deliver every journey with confidence.',
      buttonLabel: 'Start Driving',
    ),
    _OnboardingData(
      image:
          'https://images.pexels.com/photos/3225517/pexels-photo-3225517.jpeg?auto=compress&cs=tinysrgb&w=1200',
      headline: 'Run Travel\nSmarter',
      subtitle:
          'Customers, drivers, trips and operations — connected in one powerful platform.',
      buttonLabel: 'Get Started',
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen PageView — no padding, no rounding
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: 3,
            itemBuilder: (context, index) {
              return _OnboardingPage(
                data: _slides[index],
                isActive: index == _currentPage,
                fadeIn: _fadeIn,
                slideUp: _slideUp,
              );
            },
          ),
          // Bottom overlay: page indicator + CTA button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withAlpha(100),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    // CTA Button
                    FadeTransition(
                      opacity: _fadeIn,
                      child: GestureDetector(
                        onTap: _onButtonTap,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: AppTheme.brandNavy,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            _slides[_currentPage].buttonLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        // Full-screen background image — edge to edge, no rounding
        Image.network(
          data.image,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: AppTheme.brandNavy),
        ),
        // Dark gradient overlay at bottom for text readability
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0x44000000),
                Color(0xBB000000),
                Color(0xEE000000),
              ],
              stops: [0.0, 0.40, 0.58, 0.75, 1.0],
            ),
          ),
        ),
        // Headline + subtitle overlaid on lower portion
        Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: FadeTransition(
            opacity: fadeIn,
            child: AnimatedBuilder(
              animation: slideUp,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, slideUp.value),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.headline,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white.withAlpha(200),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
