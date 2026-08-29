import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/onboarding_storage.dart';

// Brand colors — kept consistent with splash_screen.dart
const _navy = Color(0xFF102A43);
const _subGrey = Color(0xFF5A6B7B);
const _background = Color(0xFFFAFAF7);
const _green = Color(0xFF3F7D4F);
const _blue = Color(0xFF2E5FA3);
const _gold = Color(0xFFC79A3D);

class _OnboardingPageData {
  final String headline;
  final String description;
  final CustomPainter Function(Animation<double> progress) illustrationBuilder;

  _OnboardingPageData({
    required this.headline,
    required this.description,
    required this.illustrationBuilder,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final OnboardingStorage _storage = OnboardingStorage();

  int _currentPage = 0;

  late final AnimationController _pageAnimController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  late final List<_OnboardingPageData> _pages;

  @override
  void initState() {
    super.initState();

    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageAnimController, curve: Curves.easeOut));

    _pages = [
      _OnboardingPageData(
        headline: 'Your finances tell a bigger story.',
        description:
        'CredNest looks beyond traditional credit scores to understand your complete financial journey.',
        illustrationBuilder: (anim) => _NodesIllustrationPainter(progress: anim),
      ),
      _OnboardingPageData(
        headline: 'Your data stays in your control.',
        description:
        'Connect your financial information securely and share only what you consent to.',
        illustrationBuilder: (anim) => _ShieldIllustrationPainter(progress: anim),
      ),
      _OnboardingPageData(
        headline: 'Discover opportunities built for you.',
        description:
        'Build your financial profile, understand your credit potential, and explore suitable opportunities.',
        illustrationBuilder: (anim) => _GrowthIllustrationPainter(progress: anim),
      ),
    ];

    _pageAnimController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageAnimController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _pageAnimController
      ..reset()
      ..forward();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await _storage.setOnboardingCompleted();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isLastPage)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: _subGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FadeTransition(
                                  opacity: _fadeAnim,
                                  child: SlideTransition(
                                    position: _slideAnim,
                                    child: SizedBox(
                                      height: 220,
                                      width: 220,
                                      child: CustomPaint(
                                        painter: page.illustrationBuilder(_fadeAnim),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                FadeTransition(
                                  opacity: _fadeAnim,
                                  child: Text(
                                    page.headline,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: _navy,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                FadeTransition(
                                  opacity: _fadeAnim,
                                  child: Text(
                                    page.description,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: _subGrey,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: isActive ? 24 : 8,
                    decoration: BoxDecoration(
                      color: isActive ? _blue : _blue.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            // Bottom navigation button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLastPage
                      ? _completeOnboarding
                      : () => _goToPage(_currentPage + 1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
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

// ---------- Abstract illustrations (CustomPainter, no image assets needed) ----------

class _NodesIllustrationPainter extends CustomPainter {
  final Animation<double> progress;
  _NodesIllustrationPainter({required this.progress}) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final center = Offset(size.width / 2, size.height / 2);

    final nodePositions = [
      center + const Offset(-60, -40),
      center + const Offset(50, -60),
      center + const Offset(-30, 50),
      center + const Offset(60, 40),
      center,
    ];
    final nodeColors = [_green, _blue, _gold, _blue, _navy];

    final linePaint = Paint()
      ..color = _blue.withValues(alpha: 0.25 * t)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < nodePositions.length; i++) {
      canvas.drawLine(center, nodePositions[i], linePaint);
    }

    for (var i = 0; i < nodePositions.length; i++) {
      final radius = (i == nodePositions.length - 1 ? 10.0 : 7.0) * t;
      final paint = Paint()..color = nodeColors[i].withValues(alpha: t);
      canvas.drawCircle(nodePositions[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NodesIllustrationPainter oldDelegate) => true;
}

class _ShieldIllustrationPainter extends CustomPainter {
  final Animation<double> progress;
  _ShieldIllustrationPainter({required this.progress}) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final center = Offset(size.width / 2, size.height / 2);

    final shieldPath = Path()
      ..moveTo(center.dx, center.dy - 70)
      ..quadraticBezierTo(center.dx + 55, center.dy - 50, center.dx + 55, center.dy - 10)
      ..quadraticBezierTo(center.dx + 55, center.dy + 55, center.dx, center.dy + 80)
      ..quadraticBezierTo(center.dx - 55, center.dy + 55, center.dx - 55, center.dy - 10)
      ..quadraticBezierTo(center.dx - 55, center.dy - 50, center.dx, center.dy - 70)
      ..close();

    final shieldPaint = Paint()
      ..color = _blue.withValues(alpha: 0.12 * t)
      ..style = PaintingStyle.fill;
    final shieldStroke = Paint()
      ..color = _blue.withValues(alpha: 0.8 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawPath(shieldPath, shieldPaint);
    canvas.drawPath(shieldPath, shieldStroke);

    // checkmark
    if (t > 0.4) {
      final checkT = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
      final checkPaint = Paint()
        ..color = _green.withValues(alpha: checkT)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(center.dx - 20, center.dy);
      final p2 = Offset(center.dx - 5, center.dy + 15);
      final p3 = Offset(center.dx + 22, center.dy - 18);

      final path = Path()..moveTo(p1.dx, p1.dy);
      if (checkT < 0.5) {
        final mid = Offset.lerp(p1, p2, checkT / 0.5)!;
        path.lineTo(mid.dx, mid.dy);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final mid = Offset.lerp(p2, p3, (checkT - 0.5) / 0.5)!;
        path.lineTo(mid.dx, mid.dy);
      }
      canvas.drawPath(path, checkPaint);
    }

    // small orbiting data nodes around the shield
    for (var i = 0; i < 3; i++) {
      final angle = (i * 2.1) + (t * 0.3);
      final orbitRadius = 85.0;
      final pos = center + Offset(orbitRadius * (i.isEven ? 1 : -1) * 0.5, -orbitRadius + (i * 30));
      final nodePaint = Paint()..color = _gold.withValues(alpha: 0.6 * t);
      canvas.drawCircle(pos, 4, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShieldIllustrationPainter oldDelegate) => true;
}

class _GrowthIllustrationPainter extends CustomPainter {
  final Animation<double> progress;
  _GrowthIllustrationPainter({required this.progress}) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;

    final start = Offset(size.width * 0.15, size.height * 0.85);
    final milestone1 = Offset(size.width * 0.4, size.height * 0.6);
    final milestone2 = Offset(size.width * 0.55, size.height * 0.35);
    final end = Offset(size.width * 0.82, size.height * 0.18);

    final pathPaint = Paint()
      ..color = _blue.withValues(alpha: 0.5 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(milestone1.dx - 10, milestone1.dy + 20, milestone1.dx, milestone1.dy)
      ..quadraticBezierTo(milestone2.dx - 10, milestone2.dy + 15, milestone2.dx, milestone2.dy)
      ..quadraticBezierTo(end.dx - 15, end.dy + 10, end.dx, end.dy);

    // animate path draw using a dash-like reveal via PathMetric
    final metrics = path.computeMetrics().toList();
    final drawPath = Path();
    for (final metric in metrics) {
      drawPath.addPath(
        metric.extractPath(0, metric.length * t),
        Offset.zero,
      );
    }
    canvas.drawPath(drawPath, pathPaint);

    final milestones = [start, milestone1, milestone2, end];
    final colors = [_navy, _green, _blue, _gold];
    for (var i = 0; i < milestones.length; i++) {
      final reveal = (t - (i * 0.2)).clamp(0.0, 1.0);
      if (reveal <= 0) continue;
      final paint = Paint()..color = colors[i].withValues(alpha: reveal);
      final radius = (i == milestones.length - 1 ? 9.0 : 6.0) * reveal;
      canvas.drawCircle(milestones[i], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthIllustrationPainter oldDelegate) => true;
}