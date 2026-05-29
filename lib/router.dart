import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/auth_provider.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/community/community_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/gesture/gesture_screen.dart';
import 'features/live_captions/live_captions_screen.dart';
import 'features/profile/profile_settings_screen.dart';
import 'features/sos/sos_configure_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/upload/upload_screen.dart';

class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter getRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppConstants.routeSplash,
      debugLogDiagnostics: true,
      refreshListenable: authProvider,
      redirect: (BuildContext context, GoRouterState state) {
        final isInitialized = authProvider.initialized;
        final isLoggedIn = authProvider.isLoggedIn;
        final location = state.matchedLocation;

        final isSplash = location == AppConstants.routeSplash;
        final isAuthRoute =
            location == AppConstants.routeLogin ||
                location == AppConstants.routeRegister;

        // Stay on splash only while auth is initializing
        if (!isInitialized) {
          return isSplash ? null : AppConstants.routeSplash;
        }

        // After init completes, move away from splash immediately
        if (isSplash) {
          return isLoggedIn
              ? AppConstants.routeDashboard
              : AppConstants.routeLogin;
        }

        // If user is not logged in, block protected routes
        if (!isLoggedIn && !isAuthRoute) {
          return AppConstants.routeLogin;
        }

        // If user is logged in, don't allow auth pages
        if (isLoggedIn && isAuthRoute) {
          return AppConstants.routeDashboard;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppConstants.routeSplash,
          name: 'splash',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const SplashScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeLogin,
          name: 'login',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const LoginScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeRegister,
          name: 'register',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const RegisterScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeDashboard,
          name: 'dashboard',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const DashboardScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeLiveCaptions,
          name: 'live-captions',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const LiveCaptionsScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeUpload,
          name: 'upload',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const UploadScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeGesture,
          name: 'gesture',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const GestureScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeCommunity,
          name: 'community',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const CommunityScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeSosConfigure,
          name: 'sos-configure',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const SosConfigureScreen(),
          ),
        ),
        GoRoute(
          path: AppConstants.routeProfile,
          name: 'profile',
          pageBuilder: (context, state) => _buildPage(
            state: state,
            child: const ProfileSettingsScreen(),
          ),
        ),
      ],
      errorPageBuilder: (context, state) => _buildPage(
        state: state,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Text(
              'Page not found: ${state.matchedLocation}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  static CustomTransitionPage<void> _buildPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
    );
  }
}