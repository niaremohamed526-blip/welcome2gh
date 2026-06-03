import 'package:flutter/material.dart';

/// Welcome2GH brand logo.
///
/// Drop your logo files into `assets/images/`:
///   • logo.png       — the icon mark only (the Adinkra map-pin with the star)
///   • logo_full.png  — the icon mark + "Welcome2GH" wordmark (optional)
///
/// Both must be transparent PNGs (no background). If a file is missing, the
/// widget falls back to the Ghana-flag circle so the app never breaks.

/// Icon-only mark — use in headers, splash glow, avatars, small spots.
class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _FlagFallback(size: size),
    );
  }
}

/// Full logo with wordmark — use on splash, login, about, empty states.
class AppLogoFull extends StatelessWidget {
  final double width;
  const AppLogoFull({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_full.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // If the full wordmark version isn't provided, fall back to the icon mark.
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/logo.png',
        width: width * 0.5,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _FlagFallback(size: width * 0.45),
      ),
    );
  }
}

/// Logo mark in natural colours — sits directly on the dark navy surface with
/// no background shape. Optionally adds a soft gold glow.
class AppLogoChip extends StatelessWidget {
  final double size;
  final bool glow;
  const AppLogoChip({super.key, this.size = 40, this.glow = false});

  @override
  Widget build(BuildContext context) {
    final mark = AppLogoMark(size: size);
    if (!glow) return mark;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: const Color(0xFFFFCC00).withValues(alpha: 0.4), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: mark,
    );
  }
}

/// Fallback shown only while the logo asset is missing.
class _FlagFallback extends StatelessWidget {
  final double size;
  const _FlagFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFCC0001))),
            Expanded(child: Container(color: const Color(0xFFFFD700))),
            Expanded(child: Container(color: const Color(0xFF006B3F))),
          ],
        ),
      ),
    );
  }
}
