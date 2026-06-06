import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';

class _Slide {
  final String tag;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String image;
  // If set, renders a local asset illustration instead of the gradient background
  final String? assetImage;

  const _Slide({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.image,
    this.assetImage,
  });
}

const _slides = [
  _Slide(
    tag: 'DISCOVER',
    title: 'EXPLORE\nACCRA.',
    subtitle: 'Curated spots, hidden gems and local favourites, all on one smart, live map.',
    icon: Icons.explore_rounded,
    accent: AppColors.yellow,
    image: 'https://images.unsplash.com/photo-1535320485706-44d43b919500?w=1200&q=80',
    assetImage: 'assets/images/onboarding/explore_accra.jpg',
  ),
  _Slide(
    tag: 'NAVIGATE',
    title: 'SMART\nNAVIGATION.',
    subtitle: 'Real-time directions, trotro routes and live crowd levels to get you there safely.',
    icon: Icons.map_rounded,
    accent: Color(0xFF00BCD4),
    image: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=1200&q=80',
    assetImage: 'assets/images/onboarding/smart_navigation.jpg',
  ),
  _Slide(
    tag: 'FAIR PRICE',
    title: 'NO MORE\nOVERPRICING.',
    subtitle: 'Community-verified taxi, market and food prices protect you from scams.',
    icon: Icons.price_check_rounded,
    accent: Color(0xFF66BB6A),
    image: 'https://images.unsplash.com/photo-1567533379826-a0bdd5eef2e8?w=1200&q=80',
    assetImage: 'assets/images/onboarding/no_more_overpricing.jpg',
  ),
  _Slide(
    tag: 'AI GUIDE',
    title: 'YOUR LOCAL\nGHANAIAN GUIDE.',
    subtitle: 'Ask anything. The AI knows Accra like a friend who grew up there.',
    icon: Icons.auto_awesome_rounded,
    accent: AppColors.yellow,
    image: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200&q=80',
    assetImage: 'assets/images/onboarding/you_local_ghanaian_gide.jpg',
  ),
  _Slide(
    tag: 'COMMUNITY',
    title: 'SAFE\nTOGETHER.',
    subtitle: 'Real-time safety alerts and scam warnings from travelers just like you.',
    icon: Icons.shield_rounded,
    accent: Color(0xFFEF5350),
    image: 'https://images.unsplash.com/photo-1604608672516-f1b9b1a3f7ed?w=1200&q=80',
    assetImage: 'assets/images/onboarding/safe_together.jpg',
  ),
  _Slide(
    tag: 'IOT LIVE',
    title: 'ENVIRONMENTAL\nINTELLIGENCE.',
    subtitle: 'Live noise, air quality and crowd sensors guide you to the perfect spot.',
    icon: Icons.sensors_rounded,
    accent: Color(0xFF26C6DA),
    image: 'https://images.unsplash.com/photo-1611348586804-61bf6c080437?w=1200&q=80',
    assetImage: 'assets/images/onboarding/environmental_intelligence.jpg',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        children: [
          // Background image — transitions between slides
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) => _SlideBackground(slide: _slides[i]),
          ),

          // Gradient overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x550D1B2A),
                    Color(0xCC0D1B2A),
                    Color(0xFF0D1B2A),
                  ],
                  stops: [0, 0.4, 0.95],
                ),
              ),
            ),
          ),

          // Top: skip + progress
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  _MiniLogo(),
                  const SizedBox(width: 10),
                  Text('WELCOME2GH',
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.greyLight),
                      child: Row(children: const [Text('Skip'), SizedBox(width: 4), Icon(Icons.arrow_forward, size: 14)]),
                    ),
                ],
              ),
            ),
          ),

          // Content card overlapping bottom of image
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(context).padding.bottom + 200),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  // FittedBox scales content down on short screens so it never overflows.
                  child: FittedBox(
                    key: ValueKey(_page),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 56,
                      child: _SlideContent(slide: slide),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Progress dots
          Positioned(
            bottom: 150, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 28 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? slide.accent : AppColors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: _page == i ? [BoxShadow(color: slide.accent.withValues(alpha: 0.5), blurRadius: 10)] : null,
                  ),
                );
              }),
            ),
          ),

          // Buttons
          Positioned(
            bottom: 48, left: 24, right: 24,
            child: Row(
              children: [
                if (_page > 0) ...[
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _controller.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: slide.accent,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: slide.accent.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 6))],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLast ? 'GET STARTED' : 'CONTINUE',
                              style: TextStyle(color: AppColors.navy, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, color: AppColors.navy, size: 18),
                          ],
                        ),
                      ),
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
}

class _SlideBackground extends StatelessWidget {
  final _Slide slide;
  const _SlideBackground({required this.slide});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // If this slide has a local illustration, show it in the top portion
    if (slide.assetImage != null) {
      return _IllustrationBackground(slide: slide, size: size);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Accent-tinted Ghana gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.alphaBlend(slide.accent.withValues(alpha: 0.28), const Color(0xFF0D1B2A)),
                const Color(0xFF0D1B2A),
                const Color(0xFF08111B),
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        // Adinkra star motifs in this slide's accent colour
        CustomPaint(painter: _OnboardAdinkra(slide.accent), size: Size.infinite),
        // Big faded feature icon as a watermark
        Positioned(
          top: 110,
          right: -30,
          child: Icon(slide.icon, size: 220, color: slide.accent.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}

class _IllustrationBackground extends StatelessWidget {
  final _Slide slide;
  final Size size;
  const _IllustrationBackground({required this.slide, required this.size});

  @override
  Widget build(BuildContext context) {
    // Image fills ~62% of screen height, dark navy below
    final illustrationH = size.height * 0.62;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full dark navy base
        Container(color: const Color(0xFF0D1B2A)),

        // Adinkra motifs behind illustration for depth
        CustomPaint(painter: _OnboardAdinkra(slide.accent), size: Size.infinite),

        // Illustration panel — rounded bottom corners, constrained width
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: illustrationH,
          child: Stack(
            children: [
              // The illustration itself with rounded bottom corners
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                child: Image.asset(
                  slide.assetImage!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),

              // Subtle yellow tint overlay to brand the illustration
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        slide.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                        const Color(0xFF0D1B2A).withValues(alpha: 0.18),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),

              // Yellow accent glow bar at the bottom edge of illustration
              Positioned(
                bottom: 0,
                left: 40,
                right: 40,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      slide.accent.withValues(alpha: 0.8),
                      Colors.transparent,
                    ]),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: slide.accent.withValues(alpha: 0.6), blurRadius: 12)],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Smooth dark gradient bridge from illustration bottom to navy
        Positioned(
          top: illustrationH * 0.82,
          left: 0,
          right: 0,
          height: illustrationH * 0.22,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0D1B2A).withValues(alpha: 0.75),
                  const Color(0xFF0D1B2A),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Accent corner decoration — top right
        Positioned(
          top: -20,
          right: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                slide.accent.withValues(alpha: 0.18),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Subtle drifting Adinkra-style stars tinted with the slide accent.
class _OnboardAdinkra extends CustomPainter {
  final Color accent;
  _OnboardAdinkra(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accent.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const cols = 4, rows = 8;
    final dx = size.width / cols, dy = size.height / rows;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _star(canvas, Offset(dx * (c + 0.5), dy * (r + 0.5)), 10, p);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double rad, Paint p) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final o = i * 2 * 3.14159265 / 5 - 1.5707963;
      final inn = o + 3.14159265 / 5;
      final ox = c.dx + rad * _cos(o), oy = c.dy + rad * _sin(o);
      final ix = c.dx + rad * 0.45 * _cos(inn), iy = c.dy + rad * 0.45 * _sin(inn);
      i == 0 ? path.moveTo(ox, oy) : path.lineTo(ox, oy);
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  // dart:ui exposes no cos/sin; use cheap Taylor-free wrappers via dart:math.
  double _cos(double x) => math.cos(x);
  double _sin(double x) => math.sin(x);

  @override
  bool shouldRepaint(covariant _OnboardAdinkra old) => old.accent != accent;
}

class _SlideContent extends StatelessWidget {
  final _Slide slide;
  const _SlideContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: slide.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: slide.accent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(slide.icon, size: 13, color: slide.accent),
              const SizedBox(width: 6),
              Text(slide.tag, style: TextStyle(color: slide.accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          slide.title,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -0.5,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 4))],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          slide.subtitle,
          style: TextStyle(color: AppColors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.6, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: AppColors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _MiniLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppLogoChip(size: 32, glow: true);
  }
}
