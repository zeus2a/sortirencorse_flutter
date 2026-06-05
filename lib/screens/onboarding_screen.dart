import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'home_screen.dart';

/// Onboarding affiché une seule fois au premier lancement.
/// Stocke le flag "onboarding_done" dans SharedPreferences.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Animation controllers per slide
  late List<AnimationController> _slideControllers;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  // ── Données des slides ────────────────────────────────────────
  static const _slides = [
    _SlideData(
      icon: Icons.explore_rounded,
      iconColor: Color(0xFFFF9E00),
      gradientColors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E)],
      badge: '🎉',
      title: 'Tout ce qui se passe\nen Corse',
      subtitle:
          'Concerts, festivals, polyphonies, soirées…\nTous les événements de l\'île au même endroit.',
    ),
    _SlideData(
      icon: Icons.near_me_rounded,
      iconColor: Colors.blueAccent,
      gradientColors: [Color(0xFF0A0A1A), Color(0xFF0D1B3E)],
      badge: '📍',
      title: 'Près de vous\naujourd\'hui',
      subtitle:
          'Activez la géolocalisation pour voir les événements autour de vous en temps réel. Votre vie privée est protégée.',
    ),
    _SlideData(
      icon: Icons.bookmark_rounded,
      iconColor: Color(0xFF9D4EDD),
      gradientColors: [Color(0xFF0A0A14), Color(0xFF1A0A2E)],
      badge: '❤️',
      title: 'Explorez.\nSauvegardez.',
      subtitle:
          'Ajoutez vos événements en favoris, explorez la carte interactive et filtrez par date ou type de soirée.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _slideControllers = List.generate(
      _slides.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      ),
    );

    _fadeAnims = _slideControllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
      );
    }).toList();

    _slideAnims = _slideControllers.map((c) {
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: c, curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic)),
      );
    }).toList();

    // Jouer la première slide
    _slideControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _slideControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markDoneAndNavigate() async {
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _requestGpsAndContinue() async {
    HapticFeedback.mediumImpact();
    // Demander la permission GPS sur la slide 2
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied || status == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    _goToNextPage();
  }

  void _goToNextPage() {
    if (_currentPage < _slides.length - 1) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _markDoneAndNavigate();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _slideControllers[page].forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // ── Slides ────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _buildSlide(slide, index, size, topPad);
            },
          ),

          // ── Bottom UI (dots + buttons) ─────────────────────────
          Positioned(
            bottom: botPad + 24,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final isActive = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? _slides[_currentPage].iconColor
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 28),

                // CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          _slides[_currentPage].iconColor,
                          _slides[_currentPage].iconColor.withValues(alpha: 0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _slides[_currentPage].iconColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _currentPage == 1
                            ? _requestGpsAndContinue
                            : _goToNextPage,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _slides.length - 1
                                    ? 'C\'est parti !'
                                    : _currentPage == 1
                                        ? 'Activer la localisation'
                                        : 'Continuer',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _slides.length - 1
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Skip link (sauf dernière page)
                if (_currentPage < _slides.length - 1)
                  GestureDetector(
                    onTap: _markDoneAndNavigate,
                    child: Text(
                      'Passer',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(
    _SlideData slide,
    int index,
    Size size,
    double topPad,
  ) {
    return AnimatedBuilder(
      animation: _slideControllers[index],
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: slide.gradientColors,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: topPad + 40),

              // Emoji badge
              SlideTransition(
                position: _slideAnims[index],
                child: FadeTransition(
                  opacity: _fadeAnims[index],
                  child: Text(
                    slide.badge,
                    style: const TextStyle(fontSize: 56),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Icon illustration circle
              SlideTransition(
                position: _slideAnims[index],
                child: FadeTransition(
                  opacity: _fadeAnims[index],
                  child: Container(
                    width: size.width * 0.52,
                    height: size.width * 0.52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          slide.iconColor.withValues(alpha: 0.18),
                          slide.iconColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                      border: Border.all(
                        color: slide.iconColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      slide.icon,
                      size: size.width * 0.23,
                      color: slide.iconColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Title
              SlideTransition(
                position: _slideAnims[index],
                child: FadeTransition(
                  opacity: _fadeAnims[index],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Subtitle
              SlideTransition(
                position: _slideAnims[index],
                child: FadeTransition(
                  opacity: _fadeAnims[index],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      slide.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),
              // Espace pour les boutons en bas
              const SizedBox(height: 180),
            ],
          ),
        );
      },
    );
  }
}

/// Data model pour chaque slide
class _SlideData {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final String badge;
  final String title;
  final String subtitle;

  const _SlideData({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.badge,
    required this.title,
    required this.subtitle,
  });
}
