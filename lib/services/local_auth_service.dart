import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_user.dart';

class LocalAuthService {
  static const String _usersKey = 'captrio_users';
  static const String _currentUserKey = 'captrio_current_user';

  Future<SharedPreferences> get _prefs async =>
      SharedPreferences.getInstance();

  LocalUser? _safeParseUser(String raw) {
    try {
      if (raw.trim().isEmpty) return null;
      return LocalUser.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<List<LocalUser>> getAllUsers() async {
    try {
      final prefs = await _prefs;
      final list = prefs.getStringList(_usersKey) ?? [];
      return list.map(_safeParseUser).whereType<LocalUser>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveAllUsers(List<LocalUser> users) async {
    try {
      final prefs = await _prefs;
      return await prefs.setStringList(
        _usersKey,
        users.map((e) => e.toJson()).toList(),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> registerUser(LocalUser user) async {
    try {
      final users = await getAllUsers();

      final alreadyExists = users.any(
            (u) =>
        u.username.toLowerCase() == user.username.toLowerCase() ||
            u.email.toLowerCase() == user.email.toLowerCase(),
      );

      if (alreadyExists) return false;

      users.add(user);
      return await saveAllUsers(users);
    } catch (_) {
      return false;
    }
  }

  Future<LocalUser?> login({
    required String loginId,
    required String passwordOrPin,
  }) async {
    try {
      final users = await getAllUsers();

      final user = users.cast<LocalUser?>().firstWhere(
            (u) =>
        u != null &&
            (u.username.toLowerCase() == loginId.toLowerCase() ||
                u.email.toLowerCase() == loginId.toLowerCase()) &&
            (u.password == passwordOrPin ||
                ((u.pin ?? '').isNotEmpty && u.pin == passwordOrPin)),
        orElse: () => null,
      );

      if (user == null) return null;

      final saved = await setCurrentUser(user);
      if (!saved) return null;

      return user;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setCurrentUser(LocalUser user) async {
    try {
      final prefs = await _prefs;
      return await prefs.setString(_currentUserKey, user.toJson());
    } catch (_) {
      return false;
    }
  }

  Future<LocalUser?> getCurrentUser() async {
    try {
      final prefs = await _prefs;
      final raw = prefs.getString(_currentUserKey);

      if (raw == null || raw.trim().isEmpty) return null;

      return _safeParseUser(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateCurrentUser(LocalUser updatedUser) async {
    try {
      final users = await getAllUsers();

      final updatedUsers = users.map((u) {
        final sameUser =
            u.username.toLowerCase() == updatedUser.username.toLowerCase() ||
                u.email.toLowerCase() == updatedUser.email.toLowerCase();
        return sameUser ? updatedUser : u;
      }).toList();

      final usersSaved = await saveAllUsers(updatedUsers);
      if (!usersSaved) return false;

      return await setCurrentUser(updatedUser);
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_currentUserKey);
    } catch (_) {}
  }

  Future<bool> clearAllAppAuthData() async {
    try {
      final prefs = await _prefs;
      await prefs.remove(_currentUserKey);
      await prefs.remove(_usersKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }
}