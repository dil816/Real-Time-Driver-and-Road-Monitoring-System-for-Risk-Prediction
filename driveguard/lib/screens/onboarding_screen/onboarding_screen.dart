import 'package:driveguard/provider/splash_provider/splash_provider.dart';
import 'package:driveguard/screens/main_navigation_screen/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

class ProfessionalOnboarding extends StatefulWidget {
  const ProfessionalOnboarding({super.key});

  @override
  State<ProfessionalOnboarding> createState() => _ProfessionalOnboardingState();
}

class _ProfessionalOnboardingState extends State<ProfessionalOnboarding> {
  final PageController _controller = PageController();
  int currentIndex = 0;
  bool _checkingEntry = true;

  final List<_OnboardData> pages = const [
    _OnboardData(
      title: 'Real-Time Driver Monitoring',
      description:
      'Continuously observes driver behavior to detect fatigue and drowsiness before risk becomes critical.',
      icon: Icons.health_and_safety_rounded,
      color: Color(0xFF35D07F),
      points: [
        'Live driver condition tracking',
        'Fatigue and drowsiness awareness',
        'Fast visual warning support',
      ],
    ),
    _OnboardData(
      title: 'Smart Road Prediction',
      description:
      'Analyzes road conditions and environment signals in real time to improve awareness and decision making.',
      icon: Icons.route_rounded,
      color: Color(0xFFFFA726),
      points: [
        'Weather-aware road protection',
        'Speed sign-based limit handling',
        'Safer recommended speed guidance',
      ],
    ),
    _OnboardData(
      title: 'Instant Safety Alerts',
      description:
      'Delivers quick sound, voice, vibration, and visual alerts when dangerous situations are detected.',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFFF5A5F),
      points: [
        'Overspeed alerts',
        'Rain and heavy-rain warnings',
        'Immediate driver assistance',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkEntry();
  }

  Future<void> _checkEntry() async {
    final isFirstTime =
    await context.read<SplashProvider>().checkFirstTimeUser();

    if (!mounted) return;

    if (isFirstTime ?? false) {
      Navigator.pushReplacement(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: const MainNavigationScreen(),
        ),
      );
      return;
    }

    setState(() {
      _checkingEntry = false;
    });
  }

  Future<void> _finishOnboarding() async {
    context.read<SplashProvider>().setFirstTimeUser(true);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        child: const MainNavigationScreen(),
      ),
    );
  }

  Future<void> _nextPage() async {
    if (currentIndex == pages.length - 1) {
      await _finishOnboarding();
      return;
    }

    await _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _skip() async {
    await _finishOnboarding();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingEntry) {
      return const Scaffold(
        backgroundColor: Color(0xFF071224),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final page = pages[currentIndex];
    final isLastPage = currentIndex == pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF071224),
              Color(0xFF0B1A31),
              Color(0xFF10233E),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        Icons.shield_moon_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DriveGuard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Smart driver safety assistant',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _skip,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _OnboardPage(data: pages[index]);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                            (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 10,
                          width: currentIndex == index ? 28 : 10,
                          decoration: BoxDecoration(
                            color: currentIndex == index
                                ? page.color
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: currentIndex == 0
                                ? null
                                : () {
                              _controller.previousPage(
                                duration:
                                const Duration(milliseconds: 320),
                                curve: Curves.easeInOut,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              disabledForegroundColor: Colors.white24,
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: page.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> points;

  const _OnboardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.points,
  });
}
class _OnboardPage extends StatelessWidget {
  final _OnboardData data;

  const _OnboardPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 700;
        final double iconBoxSize = compact ? 108 : 132;
        final double iconSize = compact ? 56 : 68;
        final double titleSize = compact ? 24 : 28;
        final double descSize = compact ? 13.5 : 14.5;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: compact ? 24 : 32,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      colors: [
                        data.color.withOpacity(0.20),
                        Colors.white.withOpacity(0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -30,
                        right: -20,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: data.color.withOpacity(0.12),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -25,
                        left: -10,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            width: iconBoxSize,
                            height: iconBoxSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(
                                color: data.color.withOpacity(0.35),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: data.color.withOpacity(0.18),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              data.icon,
                              size: iconSize,
                              color: data.color,
                            ),
                          ),
                          SizedBox(height: compact ? 20 : 28),
                          Text(
                            data.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            data.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: descSize,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ...data.points.map(
                      (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeatureTile(
                      color: data.color,
                      text: point,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
class _FeatureTile extends StatelessWidget {
  final Color color;
  final String text;

  const _FeatureTile({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}