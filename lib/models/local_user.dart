import 'dart:convert';

class LocalUser {
  final String name;
  final String username;
  final String email;
  final String password;
  final String? pin;
  final String preferredLanguage;

  const LocalUser({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    this.pin,
    required this.preferredLanguage,
  });

  LocalUser copyWith({
    String? name,
    String? username,
    String? email,
    String? password,
    String? pin,
    String? preferredLanguage,
  }) {
    return LocalUser(
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      pin: pin ?? this.pin,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'pin': pin,
      'preferredLanguage': preferredLanguage,
    };
  }

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    return LocalUser(
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      pin: map['pin'],
      preferredLanguage: map['preferredLanguage'] ?? 'English',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LocalUser.fromJson(String source) =>
      LocalUser.fromMap(jsonDecode(source));
}