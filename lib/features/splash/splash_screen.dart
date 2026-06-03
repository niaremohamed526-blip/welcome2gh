import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../core/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _bgCtrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slideTitle;
  late final Animation<Offset> _slideTag;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);

    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.easeIn));
    _scale = Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.65, curve: Curves.easeOutBack)));
    _slideTitle = Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic)));
    _slideTag = Tween(begin: const Offset(0, 1.2), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)));

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      if (SupabaseService.instance.isSignedIn) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Deep base gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1622), Color(0xFF0D1B2A), Color(0xFF08111B)],
              ),
            ),
          ),

          // Adinkra symbol motifs floating subtly in the background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _AdinkraPainter(_bgCtrl.value),
              size: Size.infinite,
            ),
          ),

          // Floating particles
          CustomPaint(painter: _StarPainter(_bgCtrl), size: Size.infinite),

          // Black-star + gold radial glow behind logo
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: SizedBox(
                width: 280, height: 280,
                child: AnimatedBuilder(
                  animation: _bgCtrl,
                  builder: (_, __) => Transform.rotate(
                    angle: _bgCtrl.value * 0.4,
                    child: CustomPaint(painter: _StarBurstPainter()),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x66FFCC00), Colors.transparent], stops: [0, 0.7]),
                ),
              ),
            ),
          ),

          // Logo + title
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: _LogoMark(),
                  ),
                ),
                const SizedBox(height: 28),
                ClipRect(
                  child: SlideTransition(
                    position: _slideTitle,
                    child: FadeTransition(
                      opacity: _ctrl.drive(CurveTween(curve: const Interval(0.3, 0.8))),
                      child: Text(
                        'WELCOME2GH',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 38,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRect(
                  child: SlideTransition(
                    position: _slideTag,
                    child: FadeTransition(
                      opacity: _ctrl.drive(CurveTween(curve: const Interval(0.5, 1.0))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.yellow.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          '✦  EXPLORE ACCRA  ✦',
                          style: TextStyle(
                            color: AppColors.yellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom loading indicator + tagline
          Positioned(
            bottom: 64, left: 0, right: 0,
            child: FadeTransition(
              opacity: _ctrl.drive(CurveTween(curve: const Interval(0.7, 1.0))),
              child: Column(
                children: [
                  SizedBox(
                    width: 36, height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(AppColors.yellow.withValues(alpha: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AKWAABA  ·  WELCOME TO GHANA',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.85),
                      fontSize: 10,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.yellow.withValues(alpha: 0.45), blurRadius: 44, spreadRadius: 4),
        ],
      ),
      child: const AppLogoMark(size: 130),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Animation<double> animation;
  _StarPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0x55FFFFFF);
    for (int i = 0; i < 50; i++) {
      final x = (i * 137.5) % size.width;
      final y = (i * 97.3) % size.height;
      final twinkle = 0.4 + 0.6 * ((animation.value + i * 0.07) % 1.0);
      final r = 0.8 + (i % 3) * 0.6;
      canvas.drawCircle(Offset(x, y), r, base..color = Color.fromRGBO(255, 255, 255, twinkle * 0.45));
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ── Ghana flag palette ───────────────────────────────────────────────────────
const _ghGold = Color(0xFFFCD116);

/// Subtle repeating Adinkra "Gye Nyame" / star motifs drifting in the background.
class _AdinkraPainter extends CustomPainter {
  final double t;
  _AdinkraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ghGold.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Grid of small Adinkra-style star tokens, gently drifting.
    const cols = 4;
    const rows = 7;
    final dx = size.width / cols;
    final dy = size.height / rows;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = dx * (c + 0.5) + 12 * (t - 0.5);
        final cy = dy * (r + 0.5) + 8 * ((r.isEven ? t : 1 - t) - 0.5);
        _drawStar(canvas, Offset(cx, cy), 11, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double rad, Paint p) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = i * 2 * math.pi / 5 - math.pi / 2;
      final inner = outer + math.pi / 5;
      final ox = c.dx + rad * math.cos(outer), oy = c.dy + rad * math.sin(outer);
      final ix = c.dx + rad * 0.45 * math.cos(inner), iy = c.dy + rad * 0.45 * math.sin(inner);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_) => true;
}

/// Radiating gold rays behind the logo — evokes the Black Star halo.
class _StarBurstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = _ghGold.withValues(alpha: 0.10)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const rays = 16;
    for (int i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      const inner = 70.0, outer = 135.0;
      canvas.drawLine(
        center + Offset(inner * math.cos(a), inner * math.sin(a)),
        center + Offset(outer * math.cos(a), outer * math.sin(a)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

