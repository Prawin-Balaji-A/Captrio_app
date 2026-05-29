import 'package:flutter/material.dart';

import '../../models/local_user.dart';
import '../../services/local_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final LocalAuthService _authService = LocalAuthService();

  LocalUser? _currentUser;
  bool _isLoading = false;
  bool _initialized = false;

  LocalUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get initialized => _initialized;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 2));
      _currentUser = await _authService.getCurrentUser();
    } catch (_) {
      _currentUser = null;
    } finally {
      _initialized = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? pin,
    required String preferredLanguage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = LocalUser(
        name: name.trim(),
        username: username.trim(),
        email: email.trim(),
        password: password.trim(),
        pin: pin?.trim().isEmpty ?? true ? null : pin!.trim(),
        preferredLanguage: preferredLanguage,
      );

      final success = await _authService.registerUser(user);
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String loginId,
    required String passwordOrPin,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.login(
        loginId: loginId.trim(),
        passwordOrPin: passwordOrPin.trim(),
      );

      _currentUser = user;
      return user != null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCurrentUser() async {
    try {
      _currentUser = await _authService.getCurrentUser();
    } catch (_) {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> updateProfile(LocalUser updatedUser) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _authService.updateCurrentUser(updatedUser);
      if (success) {
        _currentUser = await _authService.getCurrentUser();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetAllAuthData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.clearAllAppAuthData();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}