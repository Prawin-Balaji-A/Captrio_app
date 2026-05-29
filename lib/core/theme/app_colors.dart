import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand Gradient ──────────────────────────────────────────
  static const Color gradientStart     = Color(0xFF0A1628); // deep navy
  static const Color gradientMid       = Color(0xFF0D2B45); // ocean blue
  static const Color gradientEnd       = Color(0xFF0A3D2E); // deep teal-green

  // ── Primary Accent ──────────────────────────────────────────
  static const Color primary           = Color(0xFF00D4AA); // vibrant teal
  static const Color primaryLight      = Color(0xFF33DDBB); // hover teal
  static const Color primaryDark       = Color(0xFF00A882); // pressed teal
  static const Color primaryGlow       = Color(0x4000D4AA); // glow / shadow tint

  // ── Secondary Accent ────────────────────────────────────────
  static const Color secondary         = Color(0xFF4F8EF7); // soft blue
  static const Color secondaryLight    = Color(0xFF7AABFF);
  static const Color secondaryGlow     = Color(0x404F8EF7);

  // ── SOS / Danger ────────────────────────────────────────────
  static const Color danger            = Color(0xFFFF4560); // SOS red
  static const Color dangerGlow        = Color(0x40FF4560);

  // ── Success / Active ────────────────────────────────────────
  static const Color success           = Color(0xFF00D4AA); // same as primary
  static const Color successLight      = Color(0xFF33FFCC);

  // ── Surfaces (glassmorphic layers) ──────────────────────────
  static const Color surface1          = Color(0x1AFFFFFF); // 10% white
  static const Color surface2          = Color(0x26FFFFFF); // 15% white
  static const Color surface3          = Color(0x33FFFFFF); // 20% white
  static const Color surfaceDark       = Color(0x0DFFFFFF); //  5% white

  // ── Borders ─────────────────────────────────────────────────
  static const Color border            = Color(0x33FFFFFF); // 20% white border
  static const Color borderAccent      = Color(0x6600D4AA); // teal border glow
  static const Color divider           = Color(0x1AFFFFFF);

  // ── Text ────────────────────────────────────────────────────
  static const Color textPrimary       = Color(0xFFFFFFFF);
  static const Color textSecondary     = Color(0xB3FFFFFF); // 70% white
  static const Color textMuted         = Color(0x66FFFFFF); // 40% white
  static const Color textAccent        = Color(0xFF00D4AA);
  static const Color textDark          = Color(0xFF0A1628); // on-light text

  // ── Nav Bar ─────────────────────────────────────────────────
  static const Color navBackground     = Color(0xE6071220); // 90% dark navy
  static const Color navActive         = Color(0xFF00D4AA);
  static const Color navInactive       = Color(0x66FFFFFF);

  // ── Input Fields ────────────────────────────────────────────
  static const Color inputFill         = Color(0x1AFFFFFF);
  static const Color inputBorder       = Color(0x33FFFFFF);
  static const Color inputFocusBorder  = Color(0xFF00D4AA);
  static const Color inputHint         = Color(0x66FFFFFF);

  // ── Card / Tile ─────────────────────────────────────────────
  static const Color cardFill          = Color(0x1AFFFFFF);
  static const Color cardBorder        = Color(0x26FFFFFF);
  static const Color cardShadow        = Color(0x33000000);

  // ── Mic Button ──────────────────────────────────────────────
  static const Color micIdle           = Color(0xFF00D4AA);
  static const Color micActive         = Color(0xFFFF4560);
  static const Color micGlowIdle       = Color(0x4000D4AA);
  static const Color micGlowActive     = Color(0x40FF4560);

  // ── Gradients ───────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMid, gradientEnd],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF00A8CC)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, Color(0xFF7B5EA7)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [danger, Color(0xFFFF6B35)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface2, surface1],
  );
}