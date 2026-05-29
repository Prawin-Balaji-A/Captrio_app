class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────────
  static const String appName        = 'Captrio';
  static const String appTagline     = 'Every word. Every moment. For everyone.';
  static const String appVersion     = '1.0.0';

  // ── Font ─────────────────────────────────────────────────────
  static const String fontFamily     = 'Poppins';

  // ── Border Radius ────────────────────────────────────────────
  static const double radiusXs       = 6.0;
  static const double radiusSm       = 10.0;
  static const double radiusMd       = 14.0;
  static const double radiusLg       = 18.0;
  static const double radiusXl       = 24.0;
  static const double radiusXxl      = 32.0;
  static const double radiusFull     = 999.0;

  // ── Spacing ──────────────────────────────────────────────────
  static const double spaceXs        = 4.0;
  static const double spaceSm        = 8.0;
  static const double spaceMd        = 16.0;
  static const double spaceLg        = 24.0;
  static const double spaceXl        = 32.0;
  static const double spaceXxl       = 48.0;

  // ── Icon Sizes ───────────────────────────────────────────────
  static const double iconSm         = 18.0;
  static const double iconMd         = 24.0;
  static const double iconLg         = 32.0;
  static const double iconXl         = 48.0;

  // ── Nav Bar ──────────────────────────────────────────────────
  static const double navBarHeight   = 70.0;
  static const double micButtonSize  = 64.0;
  static const double sosButtonSize  = 52.0;

  // ── Splash ───────────────────────────────────────────────────
  static const int splashDuration    = 3; // seconds

  // ── Languages ────────────────────────────────────────────────
  static const List<String> supportedLanguages = [
    'English',
    'Hindi',
    'Tamil',
    'Malayalam',
    'Telugu',
  ];

  static const Map<String, String> languageCodes = {
    'English':   'en',
    'Hindi':     'hi',
    'Tamil':     'ta',
    'Malayalam': 'ml',
    'Telugu':    'te',
  };

  // ── Difficulty Levels ────────────────────────────────────────
  static const List<String> difficultyLevels = ['Easy', 'Hard'];

  // ── Routes ───────────────────────────────────────────────────
  static const String routeSplash      = '/';
  static const String routeLogin       = '/login';
  static const String routeRegister    = '/register';
  static const String routeDashboard   = '/dashboard';
  static const String routeLiveCaptions= '/live-captions';
  static const String routeUpload      = '/upload';
  static const String routeGesture     = '/gesture';
  static const String routeCommunity   = '/community';
  static const String routeSosConfigure= '/sos-configure';
  static const String routeProfile     = '/profile';

  // ── SOS ──────────────────────────────────────────────────────
  static const int    sosLongPressDuration = 2000; // ms
  static const String sosDefaultMessage    = 'I need help! This is an emergency SOS from Captrio app.';

  // ── Animation Durations ──────────────────────────────────────
  static const int animFast          = 200;  // ms
  static const int animMedium        = 350;  // ms
  static const int animSlow          = 600;  // ms
  static const int animVerySlow      = 1000; // ms

  // ── Transcript Box ───────────────────────────────────────────
  static const double transcriptFontSize     = 18.0;
  static const double transcriptMinHeight    = 180.0;
  static const double transcriptMaxHeight    = 340.0;

  // ── Glassmorphism ────────────────────────────────────────────
  static const double glassBlur       = 12.0;
  static const double glassBorderWidth = 1.0;
}